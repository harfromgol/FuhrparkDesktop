import Foundation

/// Speichert die vom Nutzer gewählte Spalten-Sortierung sortierbarer
/// Tabellen in der Fahrzeug-Detailansicht und der flottenweiten Statistik –
/// global, nicht je Fahrzeug (bewusst keine Fahrzeug-UUID-Ebene wie bei
/// `StatisticsCardVisibilityStore`, da die Sortierreihenfolge eine reine
/// Anzeigepräferenz ist), analog zum flachen `VehicleCostFilterStore`-Muster.
enum TableSortStore {
    enum Table: String {
        case expenseCategory
        case yearlyCost
        case yearlyDistance
        case costPerVehicle
        case fleetYearlyCost
    }

    private static let defaultsKey = "tableSort"

    /// `nil`, wenn für diese Tabelle noch keine eigene Wahl getroffen wurde –
    /// der Aufrufer verwendet dann den spaltenspezifischen Standard.
    static func sortState(for table: Table) -> (column: String, ascending: Bool)? {
        guard
            let all = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String: Any]],
            let entry = all[table.rawValue],
            let column = entry["column"] as? String,
            let ascending = entry["ascending"] as? Bool
        else {
            return nil
        }
        return (column, ascending)
    }

    static func setSortState(column: String, ascending: Bool, for table: Table) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String: Any]]) ?? [:]
        all[table.rawValue] = ["column": column, "ascending": ascending]
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }
}
