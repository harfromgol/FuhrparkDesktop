import SwiftUI
import CoreData
import UniformTypeIdentifiers

/// Fahrzeugübergreifende Liste aller referenzierten Dokumente (Rechnungen,
/// Belege etc.), mit Filter nach Fahrzeug und/oder Kategorie. Die Dateien
/// selbst werden nicht kopiert/gespeichert – nur Pfad + ein Security-Scoped
/// Bookmark für den dauerhaften Zugriff (die App läuft sandboxed).
struct DocumentsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Dokument.createdAt, ascending: false)],
        animation: .default
    )
    private var documents: FetchedResults<Dokument>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var isPresentingFilePicker = false
    @State private var isPresentingAssignment = false
    @State private var pendingPath: String?
    @State private var pendingBookmark: Data?
    @State private var filePickerError: String?
    @State private var pendingDeletion: Dokument?

    @State private var selectedVehicleFilter: Set<Vehicle> = []
    @State private var selectedCategoryFilter: Set<String> = []

    /// Alle Kategorienamen, die aktuell mindestens einem Dokument zugeordnet
    /// sind (über dessen Ausgabe), alphabetisch, ohne Duplikate.
    private var allCategoryNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for document in documents {
            for name in document.categoryNames where seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredDocuments: [Dokument] {
        documents.filter { document in
            let vehicleMatch = selectedVehicleFilter.isEmpty
                || document.vehicle.map(selectedVehicleFilter.contains) == true
            let categoryMatch = selectedCategoryFilter.isEmpty
                || !Set(document.categoryNames).isDisjoint(with: selectedCategoryFilter)
            return vehicleMatch && categoryMatch
        }
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                VStack(spacing: 20) {
                    addButtonRow
                    Spacer()
                    ContentUnavailableView(
                        "Keine Dokumente",
                        systemImage: "folder",
                        description: Text("Füge über „Neues Dokument“ eine Datei zu einer sonstigen Ausgabe hinzu.")
                    )
                    Spacer()
                }
                .padding(20)
            } else {
                ScrollView {
                    GlassEffectContainer {
                        VStack(alignment: .leading, spacing: 20) {
                            addButtonRow
                            if !vehicles.isEmpty {
                                vehicleFilterSection
                            }
                            if !allCategoryNames.isEmpty {
                                categoryFilterSection
                            }
                            documentListSection
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Dokumente")
        .fileImporter(isPresented: $isPresentingFilePicker, allowedContentTypes: [.item]) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $isPresentingAssignment) {
            if let pendingPath, let pendingBookmark {
                NewDocumentAssignmentView(path: pendingPath, bookmarkData: pendingBookmark) {
                    isPresentingAssignment = false
                    self.pendingPath = nil
                    self.pendingBookmark = nil
                }
            }
        }
        .alert(
            "Datei konnte nicht gespeichert werden",
            isPresented: Binding(
                get: { filePickerError != nil },
                set: { if !$0 { filePickerError = nil } }
            ),
            presenting: filePickerError
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .confirmationDialog(
            "Dokument wirklich entfernen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { document in
            Button("Entfernen", role: .destructive) {
                viewContext.delete(document)
                PersistenceController.shared.save(context: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { document in
            Text("„\(document.filename)“ wird nur aus der Liste entfernt, die Datei selbst bleibt unangetastet.")
        }
    }

    private var addButtonRow: some View {
        HStack {
            Spacer()
            Button {
                isPresentingFilePicker = true
            } label: {
                Label("Neues Dokument", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.glassProminent)
            .pointerStyle(.link)
        }
    }

    private var vehicleFilterSection: some View {
        GlassCard(title: "Nach Fahrzeug filtern") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                filterChip(title: "Alle", selected: selectedVehicleFilter.isEmpty) {
                    selectedVehicleFilter.removeAll()
                }
                ForEach(vehicles) { vehicle in
                    filterChip(
                        title: vehicle.licensePlate ?? "",
                        selected: selectedVehicleFilter.contains(vehicle)
                    ) {
                        if selectedVehicleFilter.contains(vehicle) {
                            selectedVehicleFilter.remove(vehicle)
                        } else {
                            selectedVehicleFilter.insert(vehicle)
                        }
                    }
                }
            }
        }
    }

    private var categoryFilterSection: some View {
        GlassCard(title: "Nach Kategorie filtern") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                filterChip(title: "Alle", selected: selectedCategoryFilter.isEmpty) {
                    selectedCategoryFilter.removeAll()
                }
                ForEach(allCategoryNames, id: \.self) { name in
                    filterChip(title: name, selected: selectedCategoryFilter.contains(name)) {
                        if selectedCategoryFilter.contains(name) {
                            selectedCategoryFilter.remove(name)
                        } else {
                            selectedCategoryFilter.insert(name)
                        }
                    }
                }
            }
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    selected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private var documentListSection: some View {
        GlassCard(title: "Alle Dokumente (\(filteredDocuments.count))") {
            if filteredDocuments.isEmpty {
                Text("Keine Dokumente für die gewählten Filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredDocuments) { document in
                        DocumentRow(document: document, onDelete: { pendingDeletion = document })
                    }
                }
            }
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else {
            filePickerError = "Zugriff auf die Datei wurde verweigert."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            filePickerError = "Für „\(url.lastPathComponent)“ konnte kein dauerhafter Zugriff gespeichert werden."
            return
        }
        pendingPath = url.path
        pendingBookmark = bookmark
        isPresentingAssignment = true
    }
}
