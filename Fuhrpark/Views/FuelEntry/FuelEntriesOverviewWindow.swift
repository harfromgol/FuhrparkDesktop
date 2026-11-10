import SwiftUI
import CoreData

/// Eigenständiges Fenster mit der fahrzeugübergreifenden Liste aller
/// Betankungen als Tabelle (`FuelEntriesTable`), geöffnet über das Menü
/// „Ansichten → Betankungen“ (siehe `AppMenuCommands`). Oben das Filter-Icon
/// (Fahrzeugstatus, Kennzeichen, Sortierung) und „Neue Betankung“, darunter
/// die gefilterte Tabelle, die den verfügbaren Platz im Fenster füllt und
/// erst darüber hinaus selbst scrollt.
///
/// Filter, Sortierung und Spaltenauswahl werden in
/// `FuelEntriesOverviewFilterStore` gespeichert und beim Öffnen wieder
/// eingelesen – das Fenster wird bei jedem Öffnen neu erzeugt (sein `@State`
/// ginge sonst beim Schließen verloren), soll aber wie auch nach einem
/// Neustart genau dort weitermachen, wo man aufgehört hat. Position und
/// Größe des Fensters merkt sich `persistWindowFrame` an der Szene.
struct FuelEntriesOverviewWindow: View {
    /// Feste ID der `Window`-Szene – zugleich der Schlüssel, unter dem
    /// Position und Größe des Fensters gespeichert werden.
    static let windowID = "fuel-entries-overview"

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
    @State private var sortOrder = FuelEntriesOverviewFilterStore.getSortOrder()
    @State private var isPresentingFilterPopover = false
    @State private var visibleColumns = FuelEntriesOverviewFilterStore.getVisibleColumns()
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

    var body: some View {
        // Kein umgebendes `ScrollView`: Eine SwiftUI-`Table` fällt darin auf
        // 0 pt Höhe zusammen. Stattdessen füllt die Tabelle den verfügbaren
        // Platz im Fenster (siehe `entryListSection`s `.frame(maxHeight:
        // .infinity)`) und scrollt erst darüber hinaus selbst.
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 20) {
                buttonRow

                if entries.isEmpty {
                    ContentUnavailableView(
                        "Keine Betankungen",
                        systemImage: "fuelpump",
                        description: Text("Lege über „Neue Betankung“ die erste Betankung an.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    entryListSection
                }
            }
            .padding(20)
        }
        .frame(minWidth: 620, minHeight: 360)
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
        }
        .onChange(of: selectedVehicleFilter) { _, newValue in
            FuelEntriesOverviewFilterStore.setSelectedVehicleID(newValue?.id)
        }
        .onChange(of: sortOrder) { _, newValue in
            FuelEntriesOverviewFilterStore.setSortOrder(newValue)
        }
        .onChange(of: visibleColumns) { _, newValue in
            FuelEntriesOverviewFilterStore.setVisibleColumns(newValue)
        }
    }

    private var buttonRow: some View {
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
                    showAllResults: .constant(true),
                    pageSize: .constant(1),
                    sortOrder: $sortOrder,
                    availableVehicles: vehiclesMatchingStatus,
                    maxPageSize: 1,
                    isShowAllLocked: true
                )
            }

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
                columnsMenuButton
            }

            if sortedEntries.isEmpty {
                Text("Keine Betankungen für die gewählten Filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FuelEntriesTable(entries: sortedEntries, visibleColumns: visibleColumns) { entry in
                    pendingDeletion = entry
                }
            }
        }
        // Die Karte darf über ihre Inhaltsgröße hinaus wachsen, damit
        // `FuelEntriesTable` zunächst den verfügbaren Fensterplatz füllt,
        // bevor sie selbst scrollt.
        .frame(maxHeight: .infinity, alignment: .top)
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
