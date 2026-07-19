import Foundation

/// Eine der optionalen Statistik-Karten in `VehicleDetailView`, die der
/// Nutzer über das Konfigurations-Icon in der „Statistik"-Zeile ein-/
/// ausblenden kann.
enum StatisticsCard: String, CaseIterable, Identifiable {
    case consumption
    case price
    case expenseCategory
    case yearlyCost
    case yearlyDistance

    var id: String { rawValue }
}

/// Speichert je Fahrzeug, welche Statistik-Karten sichtbar sein sollen, in
/// den UserDefaults (analog zum bestehenden `FuelTypeFilterStore`-Muster).
enum StatisticsCardVisibilityStore {
    private static let defaultsKey = "statisticsCardVisibilityByVehicle"

    /// Alle Karten sichtbar, wenn für dieses Fahrzeug noch nichts gespeichert
    /// wurde (Standard für neue wie bereits bestehende Fahrzeuge).
    static func enabledCards(for vehicleID: UUID) -> Set<StatisticsCard> {
        guard
            let all = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String]],
            let rawValues = all[vehicleID.uuidString]
        else {
            return Set(StatisticsCard.allCases)
        }
        return Set(rawValues.compactMap(StatisticsCard.init(rawValue:)))
    }

    static func setEnabledCards(_ cards: Set<StatisticsCard>, for vehicleID: UUID) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String]]) ?? [:]
        all[vehicleID.uuidString] = cards.map(\.rawValue)
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }

    /// Entfernt die gespeicherte Konfiguration eines gelöschten Fahrzeugs, damit
    /// keine Karteileiche in den UserDefaults zurückbleibt.
    static func removeEnabledCards(for vehicleID: UUID) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String]]) ?? [:]
        all.removeValue(forKey: vehicleID.uuidString)
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }
}
