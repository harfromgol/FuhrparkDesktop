import SwiftUI
import AppKit

/// Anlegen und Bearbeiten einer Notiz in einer View (analog `ReminderFormView`).
/// Das Anhängen neuer Dokumente folgt demselben Zwischenspeicher-Muster wie
/// `ExpenseFormView`: erst beim Speichern wird die Datei kopiert und ein
/// `Dokument` angelegt. Bereits vorhandene Dokumente werden im
/// Bearbeiten-Modus nur lesend angezeigt – Entfernen/Umhängen läuft über
/// „Dokumente → Zuordnung bearbeiten…“.
struct NoteFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    /// Notiz, die bearbeitet wird; `nil` beim Anlegen einer neuen Notiz.
    let notizToEdit: Notiz?

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var selectedVehicle: Vehicle?
    @State private var dateText: String
    @State private var noteText: String
    @State private var pendingDocuments: [PendingDocument] = []
    @State private var errorMessage: String?
    @State private var hasSavedNote = false

    @State private var dateValid = false
    @State private var textValid = false

    /// Beim Bearbeiten ausgewählte, aber noch nicht gespeicherte Datei – wird
    /// erst beim Speichern der Notiz als `Dokument` angelegt.
    private struct PendingDocument: Identifiable {
        let id = UUID()
        let path: String
        let bookmarkData: Data

        var filename: String { (path as NSString).lastPathComponent }
    }

    init(notizToEdit: Notiz? = nil) {
        self.notizToEdit = notizToEdit
        _selectedVehicle = State(initialValue: notizToEdit?.vehicle)
        _dateText = State(initialValue: FieldValidator.string(from: notizToEdit?.date ?? Date()))
        _noteText = State(initialValue: notizToEdit?.text ?? "")
    }

    private var isFormValid: Bool {
        dateValid && textValid && selectedVehicle != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GlassEffectContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassCard(title: "Notiz") {
                            DateValidatedField(title: "Datum", text: $dateText, isValidBinding: $dateValid)
                            ValidatedTextEditor(
                                title: "Text",
                                text: $noteText,
                                kind: .text(min: 1, max: 250),
                                isValidBinding: $textValid
                            )
                        }

                        GlassCard(title: "Kennzeichen") {
                            VehiclePicker(vehicles: Array(vehicles), selection: $selectedVehicle)
                        }

                        documentsSection
                    }
                    .padding(20)
                }
            }

            Divider()

            HStack {
                Button("Abbrechen", role: .cancel) { dismiss() }
                    .pointerStyle(.link)
                Spacer()
                Button("Speichern") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(!isFormValid || hasSavedNote)
                    .pointerStyle(isFormValid && !hasSavedNote ? .link : nil)
            }
            .padding(16)
        }
        .frame(width: 440, height: 700)
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }

    private var documentsSection: some View {
        GlassCard(title: "Dokumente") {
            if let notizToEdit, !notizToEdit.sortedDokumente.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(notizToEdit.sortedDokumente) { document in
                        Button {
                            do {
                                try document.open()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        } label: {
                            Label(document.filename, systemImage: "paperclip")
                                .lineLimit(1)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                    }
                }
                Text("Entfernen oder Umhängen über „Dokumente → Zuordnung bearbeiten…“.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !pendingDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(pendingDocuments) { document in
                        HStack {
                            Label(document.filename, systemImage: "doc")
                                .lineLimit(1)
                                .font(.caption)
                            Spacer()
                            Button {
                                pendingDocuments.removeAll { $0.id == document.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Kein Arbeitsverzeichnis-Check mehr nötig: `NotesView.addNoteTapped()`
            // lässt dieses Formular über `NewItemPrerequisite` erst gar nicht
            // öffnen, solange keins konfiguriert ist.
            Button("Dokument auswählen", systemImage: "doc.badge.plus") {
                presentDocumentFilePicker()
            }
            .buttonStyle(.glass)
            .pointerStyle(.link)
        }
    }

    /// Direktes `NSOpenPanel` statt `.fileImporter`, aus demselben Grund wie
    /// bei `ExpenseFormView`/`DocumentsView`: frei verschiebbares Fenster
    /// statt eines am Hauptfenster verankerten Sheets.
    private func presentDocumentFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Öffnen"
        guard panel.runModal() == .OK else { return }
        handleFileSelection(panel.urls)
    }

    private func handleFileSelection(_ urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Zugriff auf „\(url.lastPathComponent)“ wurde verweigert."
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let bookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) else {
                errorMessage = "Für „\(url.lastPathComponent)“ konnte kein dauerhafter Zugriff gespeichert werden."
                continue
            }
            pendingDocuments.append(PendingDocument(path: url.path, bookmarkData: bookmark))
        }
    }

    private func save() {
        let notiz = notizToEdit ?? Notiz(context: viewContext)
        if notizToEdit == nil {
            notiz.id = UUID()
            notiz.createdAt = Date()
        }
        notiz.date = FieldValidator.dateValue(dateText) ?? Date()
        notiz.text = noteText
        notiz.vehicle = selectedVehicle

        var failedFilenames: [String] = []
        for pending in pendingDocuments {
            var isStale = false
            guard let sourceURL = try? URL(
                resolvingBookmarkData: pending.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), sourceURL.startAccessingSecurityScopedResource() else {
                failedFilenames.append(pending.filename)
                continue
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            guard let relativePath = try? DocumentStorage.copyIntoWorkingDirectory(from: sourceURL, documentID: pending.id) else {
                failedFilenames.append(pending.filename)
                continue
            }
            let document = Dokument(context: viewContext)
            document.id = pending.id
            document.path = relativePath
            document.createdAt = Date()
            document.link(to: notiz)
        }

        hasSavedNote = true
        PersistenceController.shared.save(context: viewContext)

        if failedFilenames.isEmpty {
            dismiss()
        } else {
            errorMessage = "Die Notiz wurde gespeichert, folgende Dokumente konnten aber nicht hinzugefügt werden: \(failedFilenames.joined(separator: ", "))."
        }
    }
}
