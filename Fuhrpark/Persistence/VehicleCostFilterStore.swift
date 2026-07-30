import Foundation

/// Sichtbarkeit einzelner Fahrzeuggruppen in der „Kosten je Fahrzeug“-Tabelle
/// (`StatisticsView`).
enum VehicleVisibility: String, CaseIterable, Identifiable {
    case active
    case decommissioned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: return "Aktive Fahrzeuge"
        case .decommissioned: return "Stillgelegte Fahrzeuge"
        }
    }
}

/// Speichert, welche Fahrzeuggruppen in der „Kosten je Fahrzeug“-Tabelle
/// sichtbar sein sollen, in den UserDefaults, damit die Auswahl einen
/// Neustart der App übersteht (analog zum bestehenden `FuelTypeFilterStore`-
/// Muster).
enum VehicleCostFilterStore {
    private static let defaultsKey = "statisticsVehicleCostVisibility"

    /// `nil`, wenn noch nichts gespeichert wurde – dann sollen alle Gruppen sichtbar sein.
    static func get() -> Set<VehicleVisibility>? {
        guard let rawValues = UserDefaults.standard.array(forKey: defaultsKey) as? [String] else {
            return nil
        }
        return Set(rawValues.compactMap(VehicleVisibility.init(rawValue:)))
    }

    static func set(_ visibility: Set<VehicleVisibility>) {
        UserDefaults.standard.set(visibility.map(\.rawValue), forKey: defaultsKey)
    }
}
