import SwiftUI
import CoreData
import UniformTypeIdentifiers

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

    @State private var pendingPath: String?
    @State private var pendingBookmark: Data?
    @State private var errorMessage: String?
    @State private var pendingDeletion: Dokument?

    @State private var isPresentingWorkingDirectoryPopover = false
    @State private var migrationFailures: [DocumentMigration.Failure] = []

    /// Welches Sheet gerade angezeigt wird. Bewusst ein einziges `.sheet`
    /// für beide Fälle (statt zwei separater Modifier) – aus demselben
    /// Grund wie bei `ImporterKind`: nur der zuletzt deklarierte
    /// Präsentations-Modifier funktioniert auf diesem SDK-Stand zuverlässig.
    private enum SheetKind: Identifiable {
        case assignment
        case migrationFailures
        var id: Self { self }
    }
    @State private var activeSheet: SheetKind?

    /// Welcher Dateiauswahl-Dialog gerade angefordert ist. Bewusst ein
    /// einziger `.fileImporter` für beide Fälle (statt zwei separater
    /// Modifier mit je eigenem `isPresented`) – auf diesem SDK-Stand
    /// funktioniert bei zwei `.fileImporter`-Modifiern auf derselben View
    /// zuverlässig nur der zuletzt deklarierte.
    private enum ImporterKind {
        case document
        case folder
    }
    @State private var activeImporter: ImporterKind?

    /// Stabile Kopie von `activeImporter`, ausschließlich zum Auswerten im
    /// `onCompletion`-Callback des `.fileImporter`. Der Binding-Setter von
    /// `isPresented` setzt `activeImporter` beim Schließen bereits auf `nil`,
    /// bevor `onCompletion` aufgerufen wird – ohne diese zweite, nur von uns
    /// selbst geleerte Variable würde der Callback dort immer `nil` lesen.
    @State private var completingImporter: ImporterKind?

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
                            WorkingDirectoryStore.isConfigured
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
            isPresented: Binding(
                get: { activeImporter != nil },
                set: { if !$0 { activeImporter = nil } }
            ),
            allowedContentTypes: activeImporter == .folder ? [.folder] : [.item]
        ) { result in
            switch completingImporter {
            case .document: handleFileSelection(result)
            case .folder: handleFolderSelection(result)
            case nil: break
            }
            completingImporter = nil
        }
        .sheet(item: $activeSheet) { kind in
            switch kind {
            case .assignment:
                if let pendingPath, let pendingBookmark {
                    NewDocumentAssignmentView(path: pendingPath, bookmarkData: pendingBookmark) {
                        activeSheet = nil
                        self.pendingPath = nil
                        self.pendingBookmark = nil
                    } onError: { message in
                        errorMessage = message
                    }
                }
            case .migrationFailures:
                migrationFailuresSheet
            }
        }
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
        .confirmationDialog(
            "Dokument wirklich entfernen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { document in
            Button("Entfernen", role: .destructive) {
                if let path = document.path {
                    DocumentStorage.delete(relativePath: path)
                }
                viewContext.delete(document)
                PersistenceController.shared.save(context: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { document in
            Text("„\(document.filename)“ und die zugehörige Kopie im Arbeitsverzeichnis werden entfernt. Ein eventuell noch vorhandenes Original bleibt unberührt.")
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
            Button(WorkingDirectoryStore.isConfigured ? "Ändern…" : "Ordner wählen…") {
                isPresentingWorkingDirectoryPopover = false
                activeImporter = .folder
                completingImporter = .folder
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
                            onDelete: { pendingDeletion = document },
                            onError: { message in errorMessage = message }
                        )
                    }
                }
            }
        }
    }

    private func addDocumentTapped() {
        guard WorkingDirectoryStore.isConfigured else {
            errorMessage = "Bevor du Dokumente hinzufügen kannst, lege über das Zahnrad-Symbol ein Arbeitsverzeichnis fest."
            return
        }
        activeImporter = .document
        completingImporter = .document
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Zugriff auf die Datei wurde verweigert."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            errorMessage = "Für „\(url.lastPathComponent)“ konnte kein dauerhafter Zugriff gespeichert werden."
            return
        }
        pendingPath = url.path
        pendingBookmark = bookmark
        activeSheet = .assignment
    }

    private func handleFolderSelection(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        do {
            try WorkingDirectoryStore.set(url: url)
            let failures = DocumentMigration.migrateLegacyDocuments(using: PersistenceController.shared)
            if !failures.isEmpty {
                migrationFailures = failures
                activeSheet = .migrationFailures
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
