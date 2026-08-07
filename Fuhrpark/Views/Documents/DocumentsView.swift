import SwiftUI
import CoreData
import UniformTypeIdentifiers
import AppKit

/// Fahrzeugübergreifende Liste aller referenzierten Dokumente (Rechnungen,
/// Belege etc.), mit Filter nach Fahrzeug und/oder Kategorie. Dateien werden
/// beim Hinzufügen als Kopie in ein vom Nutzer gewähltes Arbeitsverzeichnis
/// abgelegt (siehe `WorkingDirectoryStore`/`DocumentStorage`), damit sie auch
/// dann auffindbar bleiben, wenn sich der Speicherort der Originaldatei
/// später ändert.
struct DocumentsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Dokument.createdAt, ascending: false)],
        animation: .default
    )
    private var documents: FetchedResults<Dokument>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    /// Einzeiler-Meldung mit eigenem Titel.
    ///
    /// Nicht bloß ein `String?` mit festem Titel „Fehler“, weil beim
    /// Festlegen des Arbeitsverzeichnisses auch ein reiner Hinweis erscheint,
    /// der kein Fehler ist. Bewusst **ein** Zustand für beides: Auf diesem
    /// SDK-Stand arbeitet von mehreren gleichzeitig deklarierten
    /// Präsentations-Modifiern zuverlässig nur der zuletzt deklarierte, ein
    /// zweiter `.alert` wäre also nicht verlässlich.
    private struct Hinweis {
        let titel: String
        let text: String

        static func fehler(_ text: String) -> Hinweis {
            Hinweis(titel: "Fehler", text: text)
        }
    }

    @State private var hinweis: Hinweis?
    @State private var pendingDeletion: Dokument?

    @State private var isPresentingWorkingDirectoryPopover = false
    @State private var migrationFailures: [DocumentMigration.Failure] = []

    /// Gespiegelter Zustand von `WorkingDirectoryStore.isConfigured`. Der
    /// Store ist reines UserDefaults ohne SwiftUI-Reaktivität – ohne diesen
    /// `@State`-Spiegel würde die Ansicht nach `WorkingDirectoryStore.set(url:)`
    /// nicht automatisch neu gerendert, da dieser Aufruf selbst keinen
    /// SwiftUI-State ändert.
    @State private var isWorkingDirectoryConfigured = WorkingDirectoryStore.isConfigured

    /// Wird bei jedem Wechsel des Arbeitsverzeichnisses hochgezählt und an die
    /// Zeilen durchgereicht, damit diese ihren Zustand neu bestimmen. Ohne das
    /// zeigten sie weiter das Ergebnis von vor dem Wechsel – aus demselben
    /// Grund wie beim Spiegel oben: UserDefaults ist für SwiftUI unsichtbar.
    @State private var workingDirectoryRevision = 0

    /// Welches Sheet gerade angezeigt wird. Bewusst ein einziges `.sheet`
    /// für beide Fälle (statt zwei separater Modifier) – auf diesem
    /// SDK-Stand funktioniert bei mehreren gleichzeitig deklarierten
    /// Präsentations-Modifiern zuverlässig nur der zuletzt deklarierte.
    ///
    /// Die Nutzdaten hängen bewusst am Fall selbst statt in eigenen
    /// `@State`-Feldern: Wird das Sheet aus einem Kontextmenü heraus
    /// geöffnet, präsentiert SwiftUI es noch mit der Inhalts-Closure aus
    /// dem Render *vor* der Zustandsänderung. Ein daneben gesetztes Feld
    /// wäre dort noch `nil`, das Sheet erschiene leer. Über den Parameter
    /// der Closure kommen die Daten dagegen immer vollständig an.
    private enum SheetKind: Identifiable {
        case assignment(path: String, bookmark: Data)
        case reassignment(Dokument)
        case migrationFailures

        var id: String {
            switch self {
            case .assignment(let path, _): "assignment:\(path)"
            case .reassignment(let document): "reassignment:\(document.objectID.uriRepresentation())"
            case .migrationFailures: "migrationFailures"
            }
        }
    }
    @State private var activeSheet: SheetKind?

    /// Auswahldialog für die Dokument-Datei selbst. Der Ordner-Dialog für
    /// das Arbeitsverzeichnis läuft bewusst NICHT über `.fileImporter`,
    /// sondern über ein direktes `NSOpenPanel` (siehe `presentFolderPicker`),
    /// da `.fileImporter` den Dialog als Sheet zeigt, das am Fenster
    /// verankert und nicht frei verschiebbar ist.
    @State private var isPresentingDocumentImporter = false

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
                        description: Text(
                            isWorkingDirectoryConfigured
                                ? "Füge über „Neues Dokument“ eine Datei zu einer sonstigen Ausgabe hinzu."
                                : "Lege zuerst über das Zahnrad-Symbol oben links ein Arbeitsverzeichnis fest, bevor du Dokumente hinzufügen kannst."
                        )
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
        .fileImporter(
            isPresented: $isPresentingDocumentImporter,
            allowedContentTypes: [.item]
        ) { result in
            handleFileSelection(result)
        }
        .sheet(item: $activeSheet) { kind in
            switch kind {
            case .assignment(let path, let bookmark):
                NewDocumentAssignmentView(
                    path: path,
                    bookmarkData: bookmark,
                    onSaved: closeAssignmentSheet,
                    onCancel: closeAssignmentSheet,
                    onError: { hinweis = .fehler($0) }
                )
            case .reassignment(let document):
                NewDocumentAssignmentView(
                    path: document.filename,
                    existingDocument: document,
                    onSaved: closeAssignmentSheet,
                    onCancel: closeAssignmentSheet,
                    onError: { hinweis = .fehler($0) }
                )
            case .migrationFailures:
                migrationFailuresSheet
            }
        }
        .alert(
            hinweis?.titel ?? "",
            isPresented: Binding(
                get: { hinweis != nil },
                set: { if !$0 { hinweis = nil } }
            ),
            presenting: hinweis
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { hinweis in
            Text(hinweis.text)
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
                DocumentCleanup.finishDeletion(in: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { document in
            let anzahl = document.sortedExpenses.count
            Text(anzahl > 1
                 ? "„\(document.filename)“ wird von allen \(anzahl) zugeordneten Ausgaben entfernt, zusammen mit der Kopie im Arbeitsverzeichnis. Ein eventuell noch vorhandenes Original bleibt unberührt."
                 : "„\(document.filename)“ und die zugehörige Kopie im Arbeitsverzeichnis werden entfernt. Ein eventuell noch vorhandenes Original bleibt unberührt.")
        }
    }

    private var addButtonRow: some View {
        HStack {
            Button {
                isPresentingWorkingDirectoryPopover = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .pointerStyle(.link)
            .help("Arbeitsverzeichnis konfigurieren")
            .popover(isPresented: $isPresentingWorkingDirectoryPopover) {
                workingDirectoryPopover
            }

            Spacer()

            Button {
                addDocumentTapped()
            } label: {
                Label("Neues Dokument", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.glassProminent)
            .pointerStyle(.link)
        }
    }

    private var workingDirectoryPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Arbeitsverzeichnis")
                .font(.headline)
            Text(WorkingDirectoryStore.displayPath ?? "Kein Arbeitsverzeichnis festgelegt")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
            Button(isWorkingDirectoryConfigured ? "Ändern…" : "Ordner wählen…") {
                isPresentingWorkingDirectoryPopover = false
                presentFolderPicker()
            }
            .buttonStyle(.bordered)
            .pointerStyle(.link)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }

    private var migrationFailuresSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Einige Dokumente konnten nicht automatisch übernommen werden")
                .font(.headline)
                .padding(20)
            List(migrationFailures, id: \.documentID) { failure in
                VStack(alignment: .leading, spacing: 2) {
                    Text(failure.filename)
                        .font(.subheadline.bold())
                    Text(failure.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("OK") { activeSheet = nil }
                    .pointerStyle(.link)
            }
            .padding(16)
        }
        .frame(width: 420, height: 360)
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
                        DocumentRow(
                            document: document,
                            workingDirectoryRevision: workingDirectoryRevision,
                            onDelete: { pendingDeletion = document },
                            onReassign: { activeSheet = .reassignment(document) },
                            onError: { message in hinweis = .fehler(message) }
                        )
                    }
                }
            }
        }
    }

    /// Schließt das Zuordnungs-Sheet – gleich, ob gespeichert oder
    /// abgebrochen wurde. Die Nutzdaten hängen am Fall und verschwinden
    /// mit ihm, es bleibt also nichts aufzuräumen.
    private func closeAssignmentSheet() {
        activeSheet = nil
    }

    private func addDocumentTapped() {
        guard isWorkingDirectoryConfigured else {
            hinweis = .fehler("Bevor du Dokumente hinzufügen kannst, lege über das Zahnrad-Symbol ein Arbeitsverzeichnis fest.")
            return
        }
        isPresentingDocumentImporter = true
    }

    /// Öffnet den Ordner-Auswahldialog direkt über AppKit statt über
    /// `.fileImporter`: Letzteres zeigt den Dialog als Sheet an, das am
    /// Fenster verankert und nicht frei verschiebbar ist. `NSOpenPanel`
    /// erzeugt stattdessen ein eigenständiges, verschiebbares Fenster.
    private func presentFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Wählen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        handleFolderSelection(.success(url))
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else {
            hinweis = .fehler("Zugriff auf die Datei wurde verweigert.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            hinweis = .fehler("Für „\(url.lastPathComponent)“ konnte kein dauerhafter Zugriff gespeichert werden.")
            return
        }
        activeSheet = .assignment(path: url.path, bookmark: bookmark)
    }

    private func handleFolderSelection(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        do {
            try WorkingDirectoryStore.set(url: url)
            isWorkingDirectoryConfigured = true
            workingDirectoryRevision += 1
            let failures = DocumentMigration.migrateLegacyDocuments(using: PersistenceController.shared)
            if !failures.isEmpty {
                migrationFailures = failures
                activeSheet = .migrationFailures
            } else {
                warnAboutForeignFolders()
            }
        } catch {
            hinweis = .fehler(error.localizedDescription)
        }
    }

    /// Warnt, wenn im frisch gewählten Verzeichnis Belegordner liegen, die
    /// dieser Datenbestand nicht kennt.
    ///
    /// Hintergrund: `DocumentCleanup` hält die Invariante „das
    /// Arbeitsverzeichnis enthält genau die Ordner, die die Datenbank kennt“
    /// aufrecht und räumt beim nächsten Löschvorgang alles Übrige weg. Zeigt
    /// man versehentlich auf das Belegverzeichnis eines anderen Bestands –
    /// etwa mit dem Testbau auf das der produktiven App, die seit der
    /// Container-Trennung nebeneinander laufen –, wäre das ein stiller
    /// Datenverlust. Der Hinweis löscht selbst nichts; er nennt nur, was
    /// betroffen wäre, solange noch umgestellt werden kann.
    private func warnAboutForeignFolders() {
        let fremde = DocumentCleanup.unknownFolderIDs(in: viewContext).count
        guard fremde > 0 else { return }
        hinweis = Hinweis(
            titel: "Fremde Belegordner im Verzeichnis",
            text: fremde == 1
                ? "In diesem Ordner liegt ein Belegordner, der nicht zu diesem Datenbestand gehört. Er wird beim nächsten Löschvorgang entfernt. Wähle ein anderes Verzeichnis, falls er zu einer anderen Installation gehört."
                : "In diesem Ordner liegen \(fremde) Belegordner, die nicht zu diesem Datenbestand gehören. Sie werden beim nächsten Löschvorgang entfernt. Wähle ein anderes Verzeichnis, falls sie zu einer anderen Installation gehören."
        )
    }
}
