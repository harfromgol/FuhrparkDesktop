import Foundation

/// Speichert das gewählte Update-Intervall der angepinnten Spritpreise –
/// einfacher Skalar wie bei `FuelTypeFilterStore`. Bewusst NICHT in
/// `DataTransfer` eingebunden, siehe `PinnedFuelSelectionStore`.
enum FuelPriceRefreshIntervalStore {
    private static let defaultsKey = "fuelPriceRefreshInterval"

    /// Automatische Aktualisierung ist der naheliegende Standard für dieses
    /// Feature, deshalb `.min60` statt „Manuell" als Vorbelegung.
    static func get() -> FuelPriceRefreshInterval {
        let raw = UserDefaults.standard.object(forKey: defaultsKey) as? Int
        return raw.flatMap(FuelPriceRefreshInterval.init(rawValue:)) ?? .min60
    }

    static func set(_ interval: FuelPriceRefreshInterval) {
        UserDefaults.standard.set(interval.rawValue, forKey: defaultsKey)
    }
}
