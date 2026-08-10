import Foundation

/// Speichert das gewählte Update-Intervall der angepinnten Spritpreise –
/// einfacher Skalar wie bei `FuelTypeFilterStore`. Bewusst NICHT in
/// `DataTransfer` eingebunden, siehe `PinnedFuelSelectionStore`.
enum FuelPriceRefreshIntervalStore {
    private static let defaultsKey = "fuelPriceRefreshInterval"

    static func get() -> FuelPriceRefreshInterval {
        let raw = UserDefaults.standard.object(forKey: defaultsKey) as? Int
        return raw.flatMap(FuelPriceRefreshInterval.init(rawValue:)) ?? .manual
    }

    static func set(_ interval: FuelPriceRefreshInterval) {
        UserDefaults.standard.set(interval.rawValue, forKey: defaultsKey)
    }
}
