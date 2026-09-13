import SwiftUI
import CoreData

/// Ob die Liste als Karten (bisheriges Layout) oder als Tabelle dargestellt
/// wird – umschaltbar über `FuelEntriesView.layoutModePicker`. Nur eine
/// Anzeige-Präferenz für die laufende Sitzung, keine Filterung.
private enum FuelEntriesLayoutMode {
    case cards
    case table
}

/// Fahrzeugübergreifende Liste aller Betankungen, mit Filter nach
/// Fahrzeugstatus und Kennzeichen sowie einstellbarer Seitengröße und
/// Sortierung – aufgebaut wie `NotesView`/`RemindersView` (Filter-Icon +
/// „Neue …“-Button oben, darunter die gefilterte Liste), ergänzt um die
/// Vor/Zurück-Blätterung aus `FuelEntryListWindow`, da die fahrzeug-
/// übergreifende Liste schnell sehr lang werden kann.
///
/// Alle Filter- und Anzeigeeinstellungen werden in
/// `FuelEntriesOverviewFilterStore` gespeichert und beim Erscheinen wieder
/// eingelesen: die Ansicht wird bei jedem Wechsel in der Seitenleiste neu
/// erzeugt (ihr `@State` ginge sonst beim Verlassen verloren), soll aber
/// beim Zurückkehren zu „Allgemein → Betankungen“ wie auch nach einem
/// Neustart genau dort weitermachen, wo man aufgehört hat.
struct FuelEntriesView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.date, ascending: false)])
    private var entries: FetchedResults<FuelEntry>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var isPresentingNewEntry = false
    @State private var pendingDeletion: FuelEntry?
    @State private var errorMessage: String?

    @State private var selectedVehicleFilter: Vehicle?
    @State private var statusFilter = FuelEntriesOverviewFilterStore.getStatusFilter()
    @State private var showAllResults = FuelEntriesOverviewFilterStore.getShowAll()
    @State private var pageSize = FuelEntriesOverviewFilterStore.getPageSize()
    @State private var sortOrder = FuelEntriesOverviewFilterStore.getSortOrder()
    @State private var currentPage = 0
    @State private var isPresentingFilterPopover = false
    @State private var layoutMode: FuelEntriesLayoutMode = .cards
    @State private var visibleColumns = Set(FuelEntryTableColumn.allCases)
    @State private var isPresentingColumnsPopover = false
    /// `selectedVehicleFilter` selbst kann erst nach dem ersten Erscheinen
    /// aus der gespeicherten Fahrzeug-ID aufgelöst werden, da `vehicles`
    /// (der `@FetchRequest`) zum Zeitpunkt der `@State`-Initialisierung noch
    /// nicht befüllt ist – siehe `.onAppear` unten, analog zu
    /// `FuelEntryListWindow.didSetDefaultYear`.
    @State private var didRestoreVehicleFilter = false

    /// Fahrzeuge, die zum gewählten Fahrzeugstatus passen – Grundlage der
    /// Fahrzeugauswahl im Filter-Popover.
    private var vehiclesMatchingStatus: [Vehicle] {
        switch statusFilter {
        case .alle: Array(vehicles)
        case .aktiv: vehicles.filter { !$0.decommissioned }
        case .stillgelegt: vehicles.filter { $0.decommissioned }
        }
    }

    private var isAnyFilterActive: Bool {
        statusFilter != .alle || selectedVehicleFilter != nil
    }

    private var filteredEntries: [FuelEntry] {
        entries.filter { entry in
            guard let vehicle = entry.vehicle else { return false }
            let statusMatch: Bool
            switch statusFilter {
            case .alle: statusMatch = true
            case .aktiv: statusMatch = !vehicle.decommissioned
            case .stillgelegt: statusMatch = vehicle.decommissioned
            }
            let vehicleMatch = selectedVehicleFilter == nil || entry.vehicle == selectedVehicleFilter
            return statusMatch && vehicleMatch
        }
    }

    /// Primär nach Datum, bei Gleichstand zusätzlich nach km-Stand – beide in
    /// derselben Richtung, siehe `FuelEntrySortOrder`.
    private var sortedEntries: [FuelEntry] {
        let ascending = sortOrder == .ascending
        return filteredEntries.sorted { lhs, rhs in
            let lhsDate = lhs.date ?? .distantPast
            let rhsDate = rhs.date ?? .distantPast
            if lhsDate != rhsDate {
                return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            }
            return ascending ? lhs.odometer < rhs.odometer : lhs.odometer > rhs.odometer
        }
    }

    /// Bei „Alle anzeigen“ zählt die Seitengröße effektiv als „alle
    /// gefilterten Treffer“ – so bleibt `totalPages` bei 1 und die
    /// Vor/Zurück-Blätterung entfällt automatisch, ohne die Logik unten
    /// doppelt pflegen zu müssen.
    private var effectivePageSize: Int {
        showAllResults ? max(1, sortedEntries.count) : pageSize
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(sortedEntries.count) / Double(effectivePageSize))))
    }

    private var pagedEntries: [FuelEntry] {
        let start = currentPage * effectivePageSize
        guard start < sortedEntries.count else { return [] }
        return Array(sortedEntries[start..<min(start + effectivePageSize, sortedEntries.count)])
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: 20) {
                    addButtonRow
                    Spacer()
                    ContentUnavailableView(
                        "Keine Betankungen",
                        systemImage: "fuelpump",
                        description: Text("Lege über „Neue Betankung“ die erste Betankung an.")
                    )
                    Spacer()
                }
                .padding(20)
            } else {
                switch layoutMode {
                case .cards:
                    ScrollView {
                        GlassEffectContainer {
                            VStack(alignment: .leading, spacing: 20) {
                                addButtonRow
                                entryListSection

                                if totalPages > 1 {
                                    PaginationControls(currentPage: $currentPage, totalPages: totalPages)
                                }
                            }
                            .padding(20)
                        }
                    }
                case .table:
                    // Kein umgebendes `ScrollView` wie im Karten-Layout: Die
                    // Tabelle soll zunächst den verfügbaren Platz im Fenster
                    // füllen (siehe `entryListSection`s `.frame(maxHeight:
                    // .infinity)` im Tabellen-Fall) und erst darüber hinaus
                    // selbst scrollen – „Alle anzeigen“ ist hier ohnehin fest
                    // erzwungen, eine Seiten-Blätterung entfällt also.
                    GlassEffectContainer {
                        VStack(alignment: .leading, spacing: 20) {
                            addButtonRow
                            entryListSection
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Betankungen")
        .sheet(isPresented: $isPresentingNewEntry) {
            FuelEntryFormView()
        }
        .confirmationDialog(
            "Betankung löschen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { entry in
            Button("Löschen", role: .destructive) {
                viewContext.delete(entry)
                PersistenceController.shared.save(context: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
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
        .onAppear {
            guard !didRestoreVehicleFilter else { return }
            didRestoreVehicleFilter = true
            if let id = FuelEntriesOverviewFilterStore.getSelectedVehicleID() {
                selectedVehicleFilter = vehicles.first { $0.id == id }
            }
        }
        .onChange(of: statusFilter) { _, newValue in
            FuelEntriesOverviewFilterStore.setStatusFilter(newValue)
            if let selectedVehicleFilter, !vehiclesMatchingStatus.contains(selectedVehicleFilter) {
                self.selectedVehicleFilter = nil
            }
            currentPage = 0
        }
        .onChange(of: selectedVehicleFilter) { _, newValue in
            FuelEntriesOverviewFilterStore.setSelectedVehicleID(newValue?.id)
            currentPage = 0
        }
        .onChange(of: sortOrder) { _, newValue in
            FuelEntriesOverviewFilterStore.setSortOrder(newValue)
            currentPage = 0
        }
        .onChange(of: showAllResults) { _, newValue in
            FuelEntriesOverviewFilterStore.setShowAll(newValue)
            currentPage = 0
        }
        .onChange(of: pageSize) { _, newValue in
            FuelEntriesOverviewFilterStore.setPageSize(newValue)
            currentPage = 0
        }
        .onChange(of: totalPages) { _, newValue in
            currentPage = min(currentPage, newValue - 1)
        }
        .onChange(of: layoutMode) { _, newValue in
            if newValue == .table {
                showAllResults = true
            }
        }
    }

    private var addButtonRow: some View {
        HStack {
            Button {
                isPresentingFilterPopover = true
            } label: {
                Image(systemName: isAnyFilterActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderless)
            .pointerStyle(.link)
            .help("Betankungen filtern")
            .popover(isPresented: $isPresentingFilterPopover) {
                FuelEntriesFilterPopover(
                    statusFilter: $statusFilter,
                    selectedVehicleFilter: $selectedVehicleFilter,
                    showAllResults: $showAllResults,
                    pageSize: $pageSize,
                    sortOrder: $sortOrder,
                    availableVehicles: vehiclesMatchingStatus,
                    maxPageSize: max(1, filteredEntries.count),
                    isShowAllLocked: layoutMode == .table
                )
            }

            layoutModePicker

            Spacer()

            Button {
                addEntryTapped()
            } label: {
                Label("Neue Betankung", systemImage: "fuelpump.fill")
            }
            .buttonStyle(.glassProminent)
            .pointerStyle(.link)
        }
    }

    private var layoutModePicker: some View {
        Picker("Layout", selection: $layoutMode) {
            Image(systemName: "rectangle.grid.1x2").tag(FuelEntriesLayoutMode.cards)
            Image(systemName: "tablecells").tag(FuelEntriesLayoutMode.table)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 90)
        .help("Layout umschalten")
    }

    private func addEntryTapped() {
        guard !vehicles.isEmpty else {
            errorMessage = "Bevor du fortfahren kannst, lege mindestens ein Fahrzeug an."
            return
        }
        isPresentingNewEntry = true
    }

    private var entryListSection: some View {
        GlassCard {
            HStack {
                Text("Betankungen (\(sortedEntries.count))")
                    .font(.headline)
                Spacer()
                if layoutMode == .table {
                    columnsMenuButton
                }
            }

            if sortedEntries.isEmpty {
                Text("Keine Betankungen für die gewählten Filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                switch layoutMode {
                case .cards:
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(pagedEntries) { entry in
                            FuelEntryRow(entry: entry, showsVehicle: true)
                                .contextMenu {
                                    Button("Löschen", role: .destructive) {
                                        pendingDeletion = entry
                                    }
                                }
                        }
                    }
                case .table:
                    FuelEntriesTable(entries: pagedEntries, visibleColumns: visibleColumns) { entry in
                        pendingDeletion = entry
                    }
                }
            }
        }
        // Nur im Tabellen-Fall darf die Karte über ihre Inhaltsgröße hinaus
        // wachsen, damit `FuelEntriesTable` zunächst den verfügbaren
        // Fensterplatz füllt, bevor sie selbst scrollt (siehe
        // `FuelEntriesView.body`); im Karten-Layout bleibt die Karte wie
        // gehabt so groß wie ihr Inhalt.
        .frame(maxHeight: layoutMode == .table ? .infinity : nil)
    }

    private var columnsMenuButton: some View {
        Button {
            isPresentingColumnsPopover = true
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .buttonStyle(.borderless)
        .pointerStyle(.link)
        .help("Spalten auswählen")
        .popover(isPresented: $isPresentingColumnsPopover) {
            FuelEntriesColumnsPopover(visibleColumns: $visibleColumns)
        }
    }
}
