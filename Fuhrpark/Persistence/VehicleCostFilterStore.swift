import Foundation

/// Auswahl für die „Kosten je Fahrzeug“-Tabelle in `StatisticsView`: welche
/// Fahrzeuge (nach Stilllegungsstatus) angezeigt werden.
enum VehicleCostFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case decommissioned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "Alle"
        case .active: return "Aktive"
        case .decommissioned: return "Stillgelegte"
        }
    }
}

/// Speichert die zuletzt gewählte Filterauswahl der „Kosten je Fahrzeug“-
/// Tabelle in den UserDefaults, damit sie einen Neustart der App übersteht
/// (analog zum bestehenden `FuelTypeFilterStore`-Muster).
enum VehicleCostFilterStore {
    private static let defaultsKey = "statisticsVehicleCostFilter"

    /// `nil`, wenn noch nichts gespeichert wurde – dann sollen alle Fahrzeuge angezeigt werden.
    static func get() -> VehicleCostFilter? {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey) else { return nil }
        return VehicleCostFilter(rawValue: rawValue)
    }

    static func set(_ filter: VehicleCostFilter) {
        UserDefaults.standard.set(filter.rawValue, forKey: defaultsKey)
    }
}
