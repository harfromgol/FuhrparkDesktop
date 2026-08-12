import Foundation

/// Eine der optionalen Zeilen im „Allgemein"-Bereich der Seitenleiste, die
/// der Nutzer über das Konfigurations-Icon in der Werkzeugleiste ein-/
/// ausblenden kann. „Statistik" ist bewusst nicht Teil davon und bleibt
/// immer sichtbar.
enum SidebarSection: String, CaseIterable, Identifiable {
    case documents
    case reminders
    case fuelPrices
    case mcp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents: return "Dokumente"
        case .reminders: return "Erinnerungen"
        case .fuelPrices: return "Spritpreise"
        case .mcp: return "KI-Zugriff"
        }
    }
}

/// Speichert, welche der optionalen Seitenleisten-Zeilen sichtbar sein
/// sollen, in den UserDefaults (analog zum bestehenden
/// `StatisticsCardVisibilityStore`-Muster).
enum SidebarSectionVisibilityStore {
    private static let defaultsKey = "sidebarVisibleSections"

    /// Alle Zeilen sichtbar, wenn noch nichts gespeichert wurde (Standard).
    static func enabledSections() -> Set<SidebarSection> {
        guard let rawValues = UserDefaults.standard.array(forKey: defaultsKey) as? [String] else {
            return Set(SidebarSection.allCases)
        }
        return Set(rawValues.compactMap(SidebarSection.init(rawValue:)))
    }

    static func setEnabledSections(_ sections: Set<SidebarSection>) {
        UserDefaults.standard.set(sections.map(\.rawValue), forKey: defaultsKey)
    }
}
