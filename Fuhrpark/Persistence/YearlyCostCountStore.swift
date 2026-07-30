import Foundation

/// Speichert, wie viele Jahre in der „Kosten pro Jahr“-Tabelle in
/// `StatisticsView` angezeigt werden, in den UserDefaults, damit die
/// Auswahl einen Neustart der App übersteht (analog zum bestehenden
/// `FuelTypeFilterStore`-Muster).
enum YearlyCostCountStore {
    private static let defaultsKey = "statisticsYearlyCostCount"

    /// `nil`, wenn noch nichts gespeichert wurde – dann sollen alle
    /// verfügbaren Jahre angezeigt werden (`UserDefaults.integer(forKey:)`
    /// liefert dafür 0, ein sonst nie gültiger Sentinel-Wert).
    static func get() -> Int? {
        let stored = UserDefaults.standard.integer(forKey: defaultsKey)
        return stored == 0 ? nil : stored
    }

    static func set(_ count: Int) {
        UserDefaults.standard.set(count, forKey: defaultsKey)
    }
}
