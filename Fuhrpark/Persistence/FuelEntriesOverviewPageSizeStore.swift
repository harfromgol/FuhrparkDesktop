import Foundation

/// Speichert die zuletzt gewählte Seitengröße der fahrzeugübergreifenden
/// Betankungsübersicht (`FuelEntriesView`) in den UserDefaults. Anders als
/// `FuelEntryPageSizeStore` (feste Spanne 5...15 für die Betankungsliste
/// eines einzelnen Fahrzeugs) ist die Obergrenze hier bewusst offen – die
/// Ansicht deckelt den Stepper selbst auf die Anzahl der aktuell gefilterten
/// Ergebnisse, ein gespeicherter Wert darüber bleibt aber gültig (zeigt dann
/// einfach alle Treffer auf einer Seite).
enum FuelEntriesOverviewPageSizeStore {
    private static let defaultsKey = "fuelEntriesOverviewPageSize"
    private static let showAllDefaultsKey = "fuelEntriesOverviewShowAllResults"
    private static let defaultValue = 10

    static func get() -> Int {
        let stored = UserDefaults.standard.integer(forKey: defaultsKey)
        return stored > 0 ? stored : defaultValue
    }

    static func set(_ pageSize: Int) {
        UserDefaults.standard.set(max(1, pageSize), forKey: defaultsKey)
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
