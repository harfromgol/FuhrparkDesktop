import Foundation

/// Einer der optionalen Abschnitte (Überschrift + Karte) in
/// `VehicleDetailView`, die der Nutzer über „Sichtbare Elemente" im
/// Kopfzeilen-Menü ein-/ausblenden kann.
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

/// Speichert, welche Abschnitte in `VehicleDetailView` sichtbar sein
/// sollen – global für alle Fahrzeuge, mit optionalem Override je
/// Fahrzeug. Ein Fahrzeug ohne eigenen Override folgt der globalen
/// Einstellung; `visibleSections(for:)` liefert für die Anzeige direkt den
/// bereits aufgelösten, effektiven Stand.
enum VehicleDetailSectionVisibilityStore {
    private static let globalDefaultsKey = "vehicleDetailSectionVisibilityGlobal"
    private static let perVehicleDefaultsKey = "vehicleDetailSectionVisibilityByVehicle"

    /// Globale Standardeinstellung – alle Abschnitte sichtbar, wenn noch
    /// nichts gespeichert wurde.
    static func globalVisibleSections() -> Set<VehicleDetailSection> {
        guard let rawValues = UserDefaults.standard.array(forKey: globalDefaultsKey) as? [String] else {
            return Set(VehicleDetailSection.allCases)
        }
        return Set(rawValues.compactMap(VehicleDetailSection.init(rawValue:)))
    }

    static func setGlobalVisibleSections(_ sections: Set<VehicleDetailSection>) {
        UserDefaults.standard.set(sections.map(\.rawValue), forKey: globalDefaultsKey)
    }

    /// Eigene Einstellung eines Fahrzeugs, oder `nil`, wenn es (noch) keinen
    /// Override hat und damit der globalen Einstellung folgt.
    static func vehicleOverride(for vehicleID: UUID) -> Set<VehicleDetailSection>? {
        guard
            let all = UserDefaults.standard.dictionary(forKey: perVehicleDefaultsKey) as? [String: [String]],
            let rawValues = all[vehicleID.uuidString]
        else {
            return nil
        }
        return Set(rawValues.compactMap(VehicleDetailSection.init(rawValue:)))
    }

    /// Setzt (oder entfernt mit `nil`) den Override eines Fahrzeugs.
    static func setVehicleOverride(_ sections: Set<VehicleDetailSection>?, for vehicleID: UUID) {
        var all = (UserDefaults.standard.dictionary(forKey: perVehicleDefaultsKey) as? [String: [String]]) ?? [:]
        if let sections {
            all[vehicleID.uuidString] = sections.map(\.rawValue)
        } else {
            all.removeValue(forKey: vehicleID.uuidString)
        }
        UserDefaults.standard.set(all, forKey: perVehicleDefaultsKey)
    }

    /// Effektiv sichtbare Abschnitte für ein Fahrzeug: eigener Override,
    /// sonst die globale Einstellung.
    static func visibleSections(for vehicleID: UUID) -> Set<VehicleDetailSection> {
        vehicleOverride(for: vehicleID) ?? globalVisibleSections()
    }
}
