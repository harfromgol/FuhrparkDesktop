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
    @Environment(AppCommands.self) private var appCommands

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

        var id: String {
            switch self {
            case .assignment(let path, _): "assignment:\(path)"
            case .reassignment(let document): "reassignment:\(document.objectID.uriRepresentation())"
            }
        }
    }
    @State private var activeSheet: SheetKind?

    @State private var selectedVehicleFilter: Vehicle?
    @State private var selectedCategoryFilter: String?
    @State private var statusFilter: FahrzeugStatusFilter = .alle
    @State private var isDateFilterActive = false
    @State private var dateFrom = Date()
    @State private var dateTo = Date()
    @State private var isPresentingFilterPopover = false

    /// Fahrzeuge, die zum gewählten Fahrzeugstatus passen – Grundlage der
    /// Fahrzeugauswahl im Filter-Popover (erste Stufe der Kaskade).
    private var vehiclesMatchingStatus: [Vehicle] {
        switch statusFilter {
        case .alle: Array(vehicles)
        case .aktiv: vehicles.filter { !$0.decommissioned }
        case .stillgelegt: vehicles.filter { $0.decommissioned }
        }
    }

    /// Dokumente nach Fahrzeugstatus und Fahrzeugauswahl (zweite Stufe der
    /// Kaskade) – Grundlage sowohl für die im Popover angebotenen
    /// Kategorien als auch für die endgültige Liste.
    private var documentsAfterStatusAndVehicle: [Dokument] {
        documents.filter { document in
            let statusMatch: Bool = {
                guard statusFilter != .alle else { return true }
                guard let vehicle = document.vehicle else { return false }
                return statusFilter == .aktiv ? !vehicle.decommissioned : vehicle.decommissioned
            }()
            let vehicleMatch = selectedVehicleFilter == nil || document.vehicle == selectedVehicleFilter
            return statusMatch && vehicleMatch
        }
    }

    /// Alle Kategorienamen, die unter dem aktuellen Fahrzeugstatus- und
    /// Fahrzeugfilter mindestens einem Dokument zugeordnet sind (über dessen
    /// Ausgabe), alphabetisch, ohne Duplikate.
    private var allCategoryNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for document in documentsAfterStatusAndVehicle {
            for name in document.categoryNames where seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Aktiver Zeitraum als geschlossener Bereich über volle Tage, oder
    /// `nil`, solange die Eingrenzung ausgeschaltet ist.
    private var dateRange: ClosedRange<Date>? {
        guard isDateFilterActive else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dateFrom)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: dateTo)) ?? dateTo
        return start...end
    }

    private var filteredDocuments: [Dokument] {
        documentsAfterStatusAndVehicle.filter { document in
            let categoryMatch = selectedCategoryFilter == nil
                || document.categoryNames.contains(selectedCategoryFilter!)
            let dateMatch = dateRange.map { $0.contains(document.createdAt ?? .distantPast) } ?? true
            return categoryMatch && dateMatch
        }
    }

    private var isAnyFilterActive: Bool {
        statusFilter != .alle || selectedVehicleFilter != nil
            || selectedCategoryFilter != nil || isDateFilterActive
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
                            documentListSection
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Dokumente")
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
        .onChange(of: statusFilter) { _, _ in
            if let selectedVehicleFilter, !vehiclesMatchingStatus.contains(selectedVehicleFilter) {
                self.selectedVehicleFilter = nil
            }
            if let selectedCategoryFilter, !allCategoryNames.contains(selectedCategoryFilter) {
                self.selectedCategoryFilter = nil
            }
        }
        .onChange(of: selectedVehicleFilter) { _, _ in
            if let selectedCategoryFilter, !allCategoryNames.contains(selectedCategoryFilter) {
                self.selectedCategoryFilter = nil
            }
        }
        // Das Zahnrad-Symbol öffnet das Arbeitsverzeichnis jetzt direkt im
        // Einstellungsfenster (siehe `addButtonRow`) statt im früheren
        // Popover dieser Ansicht – dort kann es sich ändern, während diese
        // Ansicht selbst weiter im Hintergrund besteht. Nach dem Schließen
        // die eigenen Spiegel auffrischen, aus demselben Grund wie bei
        // `isWorkingDirectoryConfigured` oben: UserDefaults ist für SwiftUI
        // unsichtbar.
        .onChange(of: appCommands.showSettings) { _, isShown in
            guard !isShown else { return }
            isWorkingDirectoryConfigured = WorkingDirectoryStore.isConfigured
            workingDirectoryRevision += 1
        }
    }

    private var addButtonRow: some View {
        HStack {
            Button {
                appCommands.settingsInitialSection = .documents
                appCommands.showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .pointerStyle(.link)
            .help("Arbeitsverzeichnis konfigurieren")

            Button {
                isPresentingFilterPopover = true
            } label: {
                Image(systemName: isAnyFilterActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderless)
            .pointerStyle(.link)
            .help("Dokumente filtern")
            .popover(isPresented: $isPresentingFilterPopover) {
                DocumentsFilterPopover(
                    statusFilter: $statusFilter,
                    selectedVehicleFilter: $selectedVehicleFilter,
                    selectedCategoryFilter: $selectedCategoryFilter,
                    isDateFilterActive: $isDateFilterActive,
                    dateFrom: $dateFrom,
                    dateTo: $dateTo,
                    availableVehicles: vehiclesMatchingStatus,
                    availableCategoryNames: allCategoryNames
                )
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
        presentDocumentFilePicker()
    }

    /// Öffnet den Datei-Auswahldialog direkt über AppKit statt über
    /// `.fileImporter`: Letzteres zeigt den Dialog als Sheet an, das am
    /// Fenster verankert und nicht frei verschiebbar ist. `NSOpenPanel`
    /// erzeugt stattdessen ein eigenständiges, verschiebbares Fenster.
    private func presentDocumentFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Öffnen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        handleFileSelection(.success(url))
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
}
