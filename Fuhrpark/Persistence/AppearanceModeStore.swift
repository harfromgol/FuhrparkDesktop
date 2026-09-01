import Foundation

/// Speichert das gewählte Erscheinungsbild – einfacher Skalar wie bei
/// `FuelPriceRefreshIntervalStore`.
enum AppearanceModeStore {
    private static let defaultsKey = "appearanceMode"

    static func get() -> AppearanceMode {
        let raw = UserDefaults.standard.string(forKey: defaultsKey)
        return raw.flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    static func set(_ mode: AppearanceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
    }
}
