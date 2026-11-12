import Foundation

/// Speichert die zuletzt gewählten Filter- und Anzeigeeinstellungen der
/// fahrzeugübergreifenden Übersicht der sonstigen Buchungen
/// (`ExpensesOverviewWindow`) in den UserDefaults, damit sie einen Neustart
/// überstehen und beim erneuten Öffnen des Fensters („Ansichten → Sonstige
/// Buchungen“) wiederhergestellt werden – das Fenster wird bei jedem Öffnen
/// neu erzeugt, sein `@State` allein würde also nicht reichen. Aufgebaut wie
/// `FuelEntriesOverviewFilterStore`.
enum ExpensesOverviewFilterStore {
    private static let statusFilterDefaultsKey = "expensesOverviewStatusFilter"
    private static let selectedVehicleIDDefaultsKey = "expensesOverviewSelectedVehicleID"
    private static let sortOrderDefaultsKey = "expensesOverviewSortOrder"
    private static let visibleColumnsDefaultsKey = "expensesOverviewVisibleColumns"

    static func getStatusFilter() -> FahrzeugStatusFilter {
        UserDefaults.standard.string(forKey: statusFilterDefaultsKey)
            .flatMap(FahrzeugStatusFilter.init(rawValue:)) ?? .alle
    }

    static func setStatusFilter(_ statusFilter: FahrzeugStatusFilter) {
        UserDefaults.standard.set(statusFilter.rawValue, forKey: statusFilterDefaultsKey)
    }

    static func getSelectedVehicleID() -> UUID? {
        (UserDefaults.standard.string(forKey: selectedVehicleIDDefaultsKey)).flatMap(UUID.init(uuidString:))
    }

    static func setSelectedVehicleID(_ vehicleID: UUID?) {
        UserDefaults.standard.set(vehicleID?.uuidString, forKey: selectedVehicleIDDefaultsKey)
    }

    /// Ohne gespeicherten Wert steht die neueste Buchung oben.
    static func getSortOrder() -> FuelEntrySortOrder {
        UserDefaults.standard.string(forKey: sortOrderDefaultsKey)
            .flatMap(FuelEntrySortOrder.init(rawValue:)) ?? .descending
    }

    static func setSortOrder(_ sortOrder: FuelEntrySortOrder) {
        UserDefaults.standard.set(sortOrder.rawValue, forKey: sortOrderDefaultsKey)
    }

    /// Unbekannte (z. B. inzwischen entfernte) Spalten werden beim Einlesen
    /// stillschweigend übersprungen. Ohne gespeicherten Wert – etwa beim
    /// allerersten Aufruf – sind alle Spalten sichtbar; ebenso, wenn von den
    /// gespeicherten keine mehr bekannt ist, denn eine Tabelle ohne Spalten
    /// ließe sich über das Spalten-Popover zwar reparieren, sähe aber erst
    /// einmal kaputt aus.
    static func getVisibleColumns() -> Set<ExpenseTableColumn> {
        guard let rawValues = UserDefaults.standard.array(forKey: visibleColumnsDefaultsKey) as? [String] else {
            return Set(ExpenseTableColumn.allCases)
        }
        let columns = Set(rawValues.compactMap(ExpenseTableColumn.init(rawValue:)))
        return columns.isEmpty ? Set(ExpenseTableColumn.allCases) : columns
    }

    static func setVisibleColumns(_ columns: Set<ExpenseTableColumn>) {
        UserDefaults.standard.set(columns.map(\.rawValue), forKey: visibleColumnsDefaultsKey)
    }
}
