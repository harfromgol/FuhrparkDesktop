import Foundation

/// Speichert die zuletzt gewählten Filter- und Anzeigeeinstellungen der
/// fahrzeugübergreifenden Betankungsübersicht (`FuelEntriesOverviewWindow`)
/// in den UserDefaults, damit sie einen Neustart überstehen und beim
/// erneuten Öffnen des Fensters („Ansichten → Betankungen“) wiederhergestellt
/// werden – das Fenster wird bei jedem Öffnen neu erzeugt, sein `@State`
/// allein würde also nicht reichen.
enum FuelEntriesOverviewFilterStore {
    private static let statusFilterDefaultsKey = "fuelEntriesOverviewStatusFilter"
    private static let selectedVehicleIDDefaultsKey = "fuelEntriesOverviewSelectedVehicleID"
    private static let sortOrderDefaultsKey = "fuelEntriesOverviewSortOrder"
    private static let visibleColumnsDefaultsKey = "fuelEntriesOverviewVisibleColumns"

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

    static func getSortOrder() -> FuelEntrySortOrder {
        UserDefaults.standard.string(forKey: sortOrderDefaultsKey)
            .flatMap(FuelEntrySortOrder.init(rawValue:)) ?? .descending
    }

    static func setSortOrder(_ sortOrder: FuelEntrySortOrder) {
        UserDefaults.standard.set(sortOrder.rawValue, forKey: sortOrderDefaultsKey)
    }

    /// Wie `SidebarSectionVisibilityStore.enabledSections()`: unbekannte
    /// (z. B. inzwischen entfernte) Spalten werden beim Einlesen stillschweigend
    /// übersprungen. Ohne gespeicherten Wert – etwa beim allerersten Aufruf –
    /// sind alle Spalten sichtbar.
    static func getVisibleColumns() -> Set<FuelEntryTableColumn> {
        guard let rawValues = UserDefaults.standard.array(forKey: visibleColumnsDefaultsKey) as? [String] else {
            return Set(FuelEntryTableColumn.allCases)
        }
        return Set(rawValues.compactMap(FuelEntryTableColumn.init(rawValue:)))
    }

    static func setVisibleColumns(_ columns: Set<FuelEntryTableColumn>) {
        UserDefaults.standard.set(columns.map(\.rawValue), forKey: visibleColumnsDefaultsKey)
    }
}
