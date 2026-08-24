import AppKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Rundes Fahrzeugbild in der Detailansicht (Kontakte-App-Stil). Zeigt das
/// gesetzte Foto oder ersatzweise ein Standard-Icon passend zum Antrieb.
/// Klick bietet die Auswahl eines neuen Fotos aus Datei oder Fotos-App an,
/// gefolgt vom Zuschnitt-Editor.
struct VehiclePhotoAvatar: View {
    @ObservedObject var vehicle: Vehicle
    @Binding var layout: VehiclePhotoLayout
    @Binding var topSize: Int
    @Environment(\.managedObjectContext) private var viewContext

    @State private var isPresentingSourceDialog = false
    @State private var isPresentingWorkingDirectoryPrompt = false
    @State private var isPresentingPhotosPicker = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var imageToCrop: CGImage?
    @State private var errorMessage: String?

    var body: some View {
        Button {
            if WorkingDirectoryStore.isConfigured {
                isPresentingSourceDialog = true
            } else {
                isPresentingWorkingDirectoryPrompt = true
            }
        } label: {
            content
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .contextMenu {
            Picker("Anordnung", selection: $layout) {
                Text("Oben").tag(VehiclePhotoLayout.top)
                Text("Seitlich").tag(VehiclePhotoLayout.side)
            }
            .pickerStyle(.inline)

            if layout == .top {
                Picker("Größe", selection: $topSize) {
                    ForEach(Array(VehiclePhotoLayoutStore.topSizeRange), id: \.self) { size in
                        Text("\(size)").tag(size)
                    }
                }
            }
        }
        .confirmationDialog(
            "Kein Arbeitsverzeichnis festgelegt",
            isPresented: $isPresentingWorkingDirectoryPrompt,
            titleVisibility: .visible
        ) {
            Button("Arbeitsverzeichnis auswählen…") { presentWorkingDirectoryPicker() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Fahrzeugbilder werden wie Belege im gewählten Arbeitsverzeichnis abgelegt. Ohne dieses Verzeichnis kann kein Bild gespeichert werden.")
        }
        .confirmationDialog("Fahrzeugbild auswählen", isPresented: $isPresentingSourceDialog) {
            Button("Aus Datei…") { presentFilePicker() }
            Button("Aus Fotos-App…") { isPresentingPhotosPicker = true }
            if vehicle.photoPath != nil {
                Button("Foto entfernen", role: .destructive) { removePhoto() }
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .photosPicker(isPresented: $isPresentingPhotosPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await loadFromPhotosPicker(newItem)
                photosPickerItem = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { imageToCrop != nil },
            set: { isPresented in if !isPresented { imageToCrop = nil } }
        )) {
            if let imageToCrop {
                VehiclePhotoCropView(cgImage: imageToCrop) { data in
                    savePhoto(data)
                    self.imageToCrop = nil
                }
            }
        }
        .alert(
            "Fehler",
            isPresented: Binding(get: { errorMessage != nil }, set: { isPresented in if !isPresented { errorMessage = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let photo = vehicle.photo {
            Image(nsImage: photo)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.12))
                .overlay {
                    GeometryReader { geometry in
                        Image(systemName: vehicle.engineType.iconName)
                            .font(.system(size: geometry.size.width * 0.45))
                            .foregroundStyle(.secondary)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
        }
    }

    /// Lässt ein Arbeitsverzeichnis wählen und macht bei Erfolg gleich mit der
    /// eigentlichen Foto-Auswahl weiter, statt den Nutzer den Klick aufs Icon
    /// wiederholen zu lassen.
    private func presentWorkingDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Wählen"
        panel.message = "Ordner wählen, in dem Belege und Fahrzeugbilder abgelegt werden sollen."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try WorkingDirectoryStore.set(url: url)
            isPresentingSourceDialog = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Öffnen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url), let cgImage = ImageLoading.normalizedCGImage(from: data) else {
            errorMessage = "Das Bild konnte nicht geladen werden."
            return
        }
        imageToCrop = cgImage
    }

    private func loadFromPhotosPicker(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let cgImage = ImageLoading.normalizedCGImage(from: data)
        else {
            errorMessage = "Das Bild konnte nicht geladen werden."
            return
        }
        imageToCrop = cgImage
    }

    private func savePhoto(_ data: Data) {
        guard let vehicleID = vehicle.id else { return }
        do {
            vehicle.photoPath = try VehiclePhotoStorage.save(data, vehicleID: vehicleID)
            PersistenceController.shared.save(context: viewContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removePhoto() {
        guard let vehicleID = vehicle.id else { return }
        VehiclePhotoStorage.delete(vehicleID: vehicleID)
        vehicle.photoPath = nil
        PersistenceController.shared.save(context: viewContext)
    }
}
