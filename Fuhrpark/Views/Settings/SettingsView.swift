import SwiftUI

/// Zeigt die App-Einstellungen als modales Fenster (Sheet) über dem
/// Hauptfenster: eine Liste der Abschnitte links, deren Inhalt rechts –
/// analog zu den Systemeinstellungen. Bewusst als `.sheet` statt als
/// eigene `Window`-Szene (siehe `FuhrparkDesktopApp.swift`), damit das
/// Fenster fest am Hauptfenster verankert bleibt. Die feste Größe unten
/// (640×420) liegt in jedem Fall unter der Mindestgröße des Hauptfensters
/// (800×500, siehe `.frame(minWidth:...)` dort) – so kann das
/// Einstellungsfenster nie größer werden als das Hauptfenster.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: SettingsSection = .documents

    /// `List(selection:)` erwartet eine optionale Bindung; ein `nil` von der
    /// Liste (z. B. bei Klick ins Leere) fällt auf den ersten Abschnitt
    /// zurück, analog zu `listSelectionBinding` in `SidebarView`.
    private var selectionBinding: Binding<SettingsSection?> {
        Binding(
            get: { selection },
            set: { selection = $0 ?? .documents }
        )
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                List(selection: selectionBinding) {
                    ForEach(SettingsSection.allCases) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 180)

                Divider()

                ScrollView {
                    content(for: selection)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .frame(width: 640, height: 420)
    }

    @ViewBuilder
    private func content(for section: SettingsSection) -> some View {
        switch section {
        case .documents:
            // Platzhalter – der Inhalt folgt in einem späteren Schritt.
            EmptyView()
        }
    }
}

/// Abschnitte im Einstellungsfenster: links als Liste, rechts der
/// zugehörige Inhalt. Weitere Abschnitte ergänzen hier einfach einen Fall.
enum SettingsSection: String, CaseIterable, Identifiable {
    case documents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents: return "Dokumente"
        }
    }

    /// Dasselbe Symbol wie beim „Dokumente"-Eintrag in `SidebarView`.
    var systemImage: String {
        switch self {
        case .documents: return "folder.fill"
        }
    }
}

#Preview {
    SettingsView()
}
