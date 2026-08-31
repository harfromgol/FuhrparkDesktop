import Foundation

/// Speichert den vom Nutzer gewählten Suchradius (km) der Tankerkönig-
/// Umkreissuche – einfacher Skalar wie bei `FuelPriceRefreshIntervalStore`.
enum FuelSearchRadiusStore {
    private static let defaultsKey = "fuelPricesSearchRadiusKm"

    /// Entspricht dem bisherigen fest codierten Wert, bevor der Radius
    /// einstellbar wurde.
    static let defaultValue: Double = 5

    static func get() -> Double {
        let raw = UserDefaults.standard.object(forKey: defaultsKey) as? Double
        return raw ?? defaultValue
    }

    static func set(_ radiusKm: Double) {
        UserDefaults.standard.set(radiusKm, forKey: defaultsKey)
    }
}
