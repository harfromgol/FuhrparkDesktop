import Foundation

/// Erscheinungsbild der App: folgt entweder dem System oder erzwingt Hell/
/// Dunkel unabhängig davon. Einstellbar in den Einstellungen (Sektion
/// „Erscheinungsbild“, siehe `SettingsView`), angewendet über
/// `AppearanceSettings`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }
}
