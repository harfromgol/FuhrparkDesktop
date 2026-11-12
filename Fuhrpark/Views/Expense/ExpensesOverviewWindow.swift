import SwiftUI
import CoreData

/// Eigenständiges Fenster mit der fahrzeugübergreifenden Liste aller
/// sonstigen Ausgaben und Einnahmen als Tabelle (`ExpensesTable`), geöffnet
/// über das Menü „Ansichten → Sonstige Buchungen“ (siehe `AppMenuCommands`).
/// Aufgebaut wie `FuelEntriesOverviewWindow`: oben das Filter-Icon
/// (Fahrzeugstatus, Kennzeichen, Sortierung) und „Neue Buchung“, darunter die
/// gefilterte Tabelle, die den verfügbaren Platz im Fenster füllt und erst
/// darüber hinaus selbst scrollt.
///
/// Filter, Sortierung und Spaltenauswahl werden in
/// `ExpensesOverviewFilterStore` gespeichert und beim Öffnen wieder
/// eingelesen – das Fenster wird bei jedem Öffnen neu erzeugt (sein `@State`
/// ginge sonst beim Schließen verloren), soll aber wie auch nach einem
/// Neustart genau dort weitermachen, wo man aufgehört hat. Position und
/// Größe des Fensters merkt sich `persistWindowFrame` an der Szene.
struct ExpensesOverviewWindow: View {
    /// Feste ID der `Window`-Szene – zugleich der Schlüssel, unter dem
    /// Position und Größe des Fensters gespeichert werden.
    static let windowID = "expenses-overview"

    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)])
    private var expenses: FetchedResults<Expense>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var isPresentingNewExpense = false
    @State private var pendingDeletion: Expense?
    @State private var errorMessage: String?

    @State private var selectedVehicleFilter: Vehicle?
    @State private var statusFilter = ExpensesOverviewFilterStore.getStatusFilter()
    @State private var sortOrder = ExpensesOverviewFilterStore.getSortOrder()
    @State private var isPresentingFilterPopover = false
    @State private var visibleColumns = ExpensesOverviewFilterStore.getVisibleColumns()
    @State private var isPresentingColumnsPopover = false
    /// `selectedVehicleFilter` selbst kann erst nach dem ersten Erscheinen
    /// aus der gespeicherten Fahrzeug-ID aufgelöst werden, da `vehicles`
    /// (der `@FetchRequest`) zum Zeitpunkt der `@State`-Initialisierung noch
    /// nicht befüllt ist – siehe `.onAppear` unten, analog zu
    /// `FuelEntriesOverviewWindow.didRestoreVehicleFilter`.
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

    private var filteredExpenses: [Expense] {
        expenses.filter { expense in
            guard let vehicle = expense.vehicle else { return false }
            let statusMatch: Bool
            switch statusFilter {
            case .alle: statusMatch = true
            case .aktiv: statusMatch = !vehicle.decommissioned
            case .stillgelegt: statusMatch = vehicle.decommissioned
            }
            let vehicleMatch = selectedVehicleFilter == nil || vehicle == selectedVehicleFilter
            return statusMatch && vehicleMatch
        }
    }

    /// Primär nach Datum; bei Gleichstand nach Empfänger, damit Buchungen
    /// desselben Tages nicht bei jedem Neuzeichnen die Plätze tauschen. Beide
    /// in derselben Richtung, siehe `FuelEntrySortOrder`.
    private var sortedExpenses: [Expense] {
        let ascending = sortOrder == .ascending
        return filteredExpenses.sorted { lhs, rhs in
            let lhsDate = lhs.date ?? .distantPast
            let rhsDate = rhs.date ?? .distantPast
            if lhsDate != rhsDate {
                return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            }
            let order = (lhs.recipient ?? "").localizedCaseInsensitiveCompare(rhs.recipient ?? "")
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }
    }

    var body: some View {
        // Kein umgebendes `ScrollView`: Eine SwiftUI-`Table` fällt darin auf
        // 0 pt Höhe zusammen. Stattdessen füllt die Tabelle den verfügbaren
        // Platz im Fenster (siehe `expenseListSection`s `.frame(maxHeight:
        // .infinity)`) und scrollt erst darüber hinaus selbst.
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 20) {
                buttonRow

                if expenses.isEmpty {
                    ContentUnavailableView(
                        "Keine sonstigen Buchungen",
                        systemImage: "eurosign.circle",
                        description: Text("Lege über „Neue Buchung“ die erste sonstige Ausgabe oder Einnahme an.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    expenseListSection
                }
            }
            .padding(20)
        }
        .frame(minWidth: 620, minHeight: 360)
        .navigationTitle("Sonstige Buchungen")
        .sheet(isPresented: $isPresentingNewExpense) {
            NewExpenseFlowView(vehicles: Array(vehicles), preselectedVehicle: selectedVehicleFilter)
        }
        .confirmationDialog(
            "Buchung löschen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { expense in
            Button("Löschen", role: .destructive) {
                viewContext.delete(expense)
                DocumentCleanup.finishDeletion(in: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { expense in
            // Wortlaut wie in `ExpenseListAlertsModifier` (`ExpenseListWindow`).
            let belege = expense.sortedDocuments.count
            Text(belege == 0
                 ? "„\(expense.recipient ?? "")“ wird unwiderruflich gelöscht."
                 : "„\(expense.recipient ?? "")“ wird unwiderruflich gelöscht. Zugeordnete Belege bleiben erhalten, solange sie noch zu einer anderen Ausgabe gehören – sonst werden sie mit entfernt.")
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
            if let id = ExpensesOverviewFilterStore.getSelectedVehicleID() {
                selectedVehicleFilter = vehicles.first { $0.id == id }
            }
        }
        .onChange(of: statusFilter) { _, newValue in
            ExpensesOverviewFilterStore.setStatusFilter(newValue)
            if let selectedVehicleFilter, !vehiclesMatchingStatus.contains(selectedVehicleFilter) {
                self.selectedVehicleFilter = nil
            }
        }
        .onChange(of: selectedVehicleFilter) { _, newValue in
            ExpensesOverviewFilterStore.setSelectedVehicleID(newValue?.id)
        }
        .onChange(of: sortOrder) { _, newValue in
            ExpensesOverviewFilterStore.setSortOrder(newValue)
        }
        .onChange(of: visibleColumns) { _, newValue in
            ExpensesOverviewFilterStore.setVisibleColumns(newValue)
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
            .help("Buchungen filtern")
            .popover(isPresented: $isPresentingFilterPopover) {
                FuelEntriesFilterPopover(
                    statusFilter: $statusFilter,
                    selectedVehicleFilter: $selectedVehicleFilter,
                    sortOrder: $sortOrder,
                    availableVehicles: vehiclesMatchingStatus
                )
            }

            Spacer()

            Button {
                addExpenseTapped()
            } label: {
                Label("Neue Buchung", systemImage: "eurosign.circle.fill")
            }
            .buttonStyle(.glassProminent)
            .pointerStyle(.link)
        }
    }

    private func addExpenseTapped() {
        guard !vehicles.isEmpty else {
            errorMessage = "Bevor du fortfahren kannst, lege mindestens ein Fahrzeug an."
            return
        }
        isPresentingNewExpense = true
    }

    private var expenseListSection: some View {
        GlassCard {
            HStack {
                Text("Sonstige Buchungen (\(sortedExpenses.count))")
                    .font(.headline)
                Spacer()
                columnsMenuButton
            }

            if sortedExpenses.isEmpty {
                Text("Keine Buchungen für die gewählten Filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ExpensesTable(
                    expenses: sortedExpenses,
                    visibleColumns: visibleColumns,
                    onDelete: { pendingDeletion = $0 },
                    onError: { errorMessage = $0 }
                )
            }
        }
        // Die Karte darf über ihre Inhaltsgröße hinaus wachsen, damit
        // `ExpensesTable` zunächst den verfügbaren Fensterplatz füllt, bevor
        // sie selbst scrollt.
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
            TableColumnsPopover(visibleColumns: $visibleColumns)
        }
    }
}
