import Foundation

/// Eine der optionalen Zeilen im „Allgemein"-Bereich der Seitenleiste, die
/// der Nutzer über das Konfigurations-Icon in der Werkzeugleiste ein-/
/// ausblenden kann. „Statistik" ist bewusst nicht Teil davon und bleibt
/// immer sichtbar.
enum SidebarSection: String, CaseIterable, Identifiable {
    case fuelEntries
    case documents
    case notes
    case reminders
    case fuelPrices
    case mcp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuelEntries: return "Betankungen"
        case .documents: return "Dokumente"
        case .notes: return "Notizen"
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
    private static let fuelEntriesMigrationKey = "sidebarSectionVisibilityMigratedFuelEntries"

    /// Alle Zeilen sichtbar, wenn noch nichts gespeichert wurde (Standard).
    static func enabledSections() -> Set<SidebarSection> {
        guard let rawValues = UserDefaults.standard.array(forKey: defaultsKey) as? [String] else {
            return Set(SidebarSection.allCases)
        }
        var sections = Set(rawValues.compactMap(SidebarSection.init(rawValue:)))
        migrateFuelEntriesIfNeeded(into: &sections)
        return sections
    }

    static func setEnabledSections(_ sections: Set<SidebarSection>) {
        UserDefaults.standard.set(sections.map(\.rawValue), forKey: defaultsKey)
        UserDefaults.standard.set(true, forKey: fuelEntriesMigrationKey)
    }

    /// „Betankungen" kam nach diesem Speicherformat dazu. Bei einer bereits
    /// gespeicherten Konfiguration (die den neuen Fall noch nicht kennen
    /// konnte) wird er einmalig automatisch aktiviert – sonst bliebe der neue
    /// Menüpunkt für alle, die die Sichtbarkeit schon einmal angepasst haben,
    /// für immer unsichtbar. Nur einmalig, damit ein bewusstes späteres
    /// Ausblenden bestehen bleibt (analog `SetupWizardStore.shouldShowWizard()`,
    /// das aus demselben Grund bei seinem Lesezugriff mitschreibt).
    private static func migrateFuelEntriesIfNeeded(into sections: inout Set<SidebarSection>) {
        guard !UserDefaults.standard.bool(forKey: fuelEntriesMigrationKey) else { return }
        sections.insert(.fuelEntries)
        UserDefaults.standard.set(true, forKey: fuelEntriesMigrationKey)
    }
}
