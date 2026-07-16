import Foundation

/// Speichert die zuletzt gewählten sichtbaren Kraftstoffsorten (Checkboxen
/// über der Spritpreise-Karte) in den UserDefaults, damit die Auswahl einen
/// Neustart der App übersteht.
enum FuelTypeFilterStore {
    private static let defaultsKey = "fuelPricesEnabledFuelKinds"

    /// `nil`, wenn noch nichts gespeichert wurde (z. B. beim allerersten
    /// Start) – dann sollen alle Sorten aktiv sein.
    static func get() -> Set<FuelKind>? {
        guard let rawValues = UserDefaults.standard.array(forKey: defaultsKey) as? [String] else {
            return nil
        }
        return Set(rawValues.compactMap(FuelKind.init(rawValue:)))
    }

    static func set(_ kinds: Set<FuelKind>) {
        UserDefaults.standard.set(kinds.map(\.rawValue), forKey: defaultsKey)
    }
}
