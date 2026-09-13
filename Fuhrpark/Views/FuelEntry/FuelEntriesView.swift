import SwiftUI
import CoreData

/// Fahrzeugübergreifende Liste aller Betankungen, mit Filter nach
/// Fahrzeugstatus und Kennzeichen sowie einstellbarer Seitengröße und
/// Sortierung – aufgebaut wie `NotesView`/`RemindersView` (Filter-Icon +
/// „Neue …“-Button oben, darunter die gefilterte Liste), ergänzt um die
/// Vor/Zurück-Blätterung aus `FuelEntryListWindow`, da die fahrzeug-
/// übergreifende Liste schnell sehr lang werden kann.
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
    @State private var statusFilter: FahrzeugStatusFilter = .alle
    @State private var pageSize = FuelEntriesOverviewPageSizeStore.get()
    @State private var sortOrder: FuelEntrySortOrder = .descending
    @State private var currentPage = 0
    @State private var isPresentingFilterPopover = false

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

    private var totalPages: Int {
        max(1, Int(ceil(Double(sortedEntries.count) / Double(pageSize))))
    }

    private var pagedEntries: [FuelEntry] {
        let start = currentPage * pageSize
        guard start < sortedEntries.count else { return [] }
        return Array(sortedEntries[start..<min(start + pageSize, sortedEntries.count)])
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
        .onChange(of: statusFilter) { _, _ in
            if let selectedVehicleFilter, !vehiclesMatchingStatus.contains(selectedVehicleFilter) {
                self.selectedVehicleFilter = nil
            }
            currentPage = 0
        }
        .onChange(of: selectedVehicleFilter) { _, _ in currentPage = 0 }
        .onChange(of: sortOrder) { _, _ in currentPage = 0 }
        .onChange(of: pageSize) { _, newValue in
            FuelEntriesOverviewPageSizeStore.set(newValue)
            currentPage = 0
        }
        .onChange(of: totalPages) { _, newValue in
            currentPage = min(currentPage, newValue - 1)
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
                    pageSize: $pageSize,
                    sortOrder: $sortOrder,
                    availableVehicles: vehiclesMatchingStatus,
                    maxPageSize: max(1, filteredEntries.count)
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
        GlassCard(title: "Betankungen (\(sortedEntries.count))") {
            if sortedEntries.isEmpty {
                Text("Keine Betankungen für die gewählten Filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
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
            }
        }
    }
}
