import Foundation

/// Einer der optionalen Abschnitte (Überschrift + Karte) in
/// `VehicleDetailView`, die der Nutzer über das „Sichtbare Elemente"-
/// Untermenü im Kopfzeilen-Menü ein-/ausblenden kann.
enum VehicleDetailSection: String, CaseIterable, Identifiable {
    case fuelEntries
    case expenses
    case notes
    case reminders
    case statistics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuelEntries: return "Betankungen"
        case .expenses: return "Sonstige Ausgaben"
        case .notes: return "Notizen"
        case .reminders: return "Erinnerungen"
        case .statistics: return "Statistik"
        }
    }
}

/// Speichert je Fahrzeug, welche Abschnitte in `VehicleDetailView` sichtbar
/// sein sollen, in den UserDefaults – analog zu
/// `StatisticsCardVisibilityStore`.
enum VehicleDetailSectionVisibilityStore {
    private static let defaultsKey = "vehicleDetailSectionVisibilityByVehicle"

    /// Alle Abschnitte sichtbar, wenn für dieses Fahrzeug noch nichts
    /// gespeichert wurde (Standard für neue wie bereits bestehende Fahrzeuge).
    static func visibleSections(for vehicleID: UUID) -> Set<VehicleDetailSection> {
        guard
            let all = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String]],
            let rawValues = all[vehicleID.uuidString]
        else {
            return Set(VehicleDetailSection.allCases)
        }
        return Set(rawValues.compactMap(VehicleDetailSection.init(rawValue:)))
    }

    static func setVisibleSections(_ sections: Set<VehicleDetailSection>, for vehicleID: UUID) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String]]) ?? [:]
        all[vehicleID.uuidString] = sections.map(\.rawValue)
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }

    /// Entfernt die gespeicherte Konfiguration eines gelöschten Fahrzeugs, damit
    /// keine Karteileiche in den UserDefaults zurückbleibt.
    static func removeVisibleSections(for vehicleID: UUID) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String]]) ?? [:]
        all.removeValue(forKey: vehicleID.uuidString)
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }
}
