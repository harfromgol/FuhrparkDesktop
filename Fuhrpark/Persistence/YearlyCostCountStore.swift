import Foundation

/// Speichert, wie viele Jahre in der „Kosten pro Jahr“-Tabelle in
/// `StatisticsView` angezeigt werden, in den UserDefaults, damit die
/// Auswahl einen Neustart der App übersteht (analog zum bestehenden
/// `FuelTypeFilterStore`-Muster).
enum YearlyCostCountStore {
    private static let defaultsKey = "statisticsYearlyCostCount"
    static let defaultCount = 5
    static let range = 1...20

    /// Anzahl anzuzeigender Jahre; `defaultCount`, wenn noch nichts gespeichert
    /// wurde (`UserDefaults.integer(forKey:)` liefert dafür 0, ein außerhalb
    /// von `range` liegender und daher eindeutiger Sentinel-Wert).
    static func get() -> Int {
        let stored = UserDefaults.standard.integer(forKey: defaultsKey)
        return stored == 0 ? defaultCount : stored
    }

    static func set(_ count: Int) {
        UserDefaults.standard.set(count, forKey: defaultsKey)
    }
}
