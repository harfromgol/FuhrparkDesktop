import Foundation

/// Speichert die zuletzt gewählten Filter- und Anzeigeeinstellungen der
/// fahrzeugübergreifenden Betankungsübersicht (`FuelEntriesView`) in den
/// UserDefaults, damit sie einen Neustart überstehen und beim Zurückkehren
/// zu „Allgemein → Betankungen“ wiederhergestellt werden – die Ansicht wird
/// bei jedem Sidebar-Wechsel neu erzeugt, ihr `@State` allein würde also
/// nicht reichen. Anders als `FuelEntryPageSizeStore` (feste Spanne 5...15
/// für die Betankungsliste eines einzelnen Fahrzeugs) ist die Obergrenze der
/// Seitengröße hier bewusst offen – die Ansicht deckelt den Stepper selbst
/// auf die Anzahl der aktuell gefilterten Ergebnisse, ein gespeicherter Wert
/// darüber bleibt aber gültig (zeigt dann einfach alle Treffer auf einer
/// Seite).
enum FuelEntriesOverviewFilterStore {
    private static let statusFilterDefaultsKey = "fuelEntriesOverviewStatusFilter"
    private static let selectedVehicleIDDefaultsKey = "fuelEntriesOverviewSelectedVehicleID"
    private static let sortOrderDefaultsKey = "fuelEntriesOverviewSortOrder"
    private static let pageSizeDefaultsKey = "fuelEntriesOverviewPageSize"
    private static let showAllDefaultsKey = "fuelEntriesOverviewShowAllResults"
    private static let defaultPageSize = 10

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

    static func getPageSize() -> Int {
        let stored = UserDefaults.standard.integer(forKey: pageSizeDefaultsKey)
        return stored > 0 ? stored : defaultPageSize
    }

    static func setPageSize(_ pageSize: Int) {
        UserDefaults.standard.set(max(1, pageSize), forKey: pageSizeDefaultsKey)
    }

    /// Ob standardmäßig alle Treffer ohne Begrenzung gezeigt werden – Standard
    /// „an“, solange noch nichts gespeichert wurde.
    static func getShowAll() -> Bool {
        guard UserDefaults.standard.object(forKey: showAllDefaultsKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: showAllDefaultsKey)
    }

    static func setShowAll(_ showAll: Bool) {
        UserDefaults.standard.set(showAll, forKey: showAllDefaultsKey)
    }
}
