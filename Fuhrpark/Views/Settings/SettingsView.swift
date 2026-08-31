import SwiftUI
import AppKit

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
    @State private var selection: SettingsSection

    /// `initialSection` legt fest, welcher Abschnitt beim Öffnen bereits
    /// ausgewählt ist – z. B. „Dokumente“, wenn das Zahnrad-Symbol in
    /// `DocumentsView` dieses Fenster direkt öffnet (siehe
    /// `AppCommands.settingsInitialSection`).
    init(initialSection: SettingsSection = .documents) {
        _selection = State(initialValue: initialSection)
    }

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
            DocumentsSettingsSection()
        case .fuelPrices:
            FuelPricesSettingsSection()
        }
    }
}

/// Inhalt der Sektion „Dokumente“: zeigt und ändert das Arbeitsverzeichnis
/// für Belege/Dokumente – dieselbe Funktion wie im Zahnrad-Popover in
/// `DocumentsView`, hier aber direkt sichtbar statt hinter einem
/// zusätzlichen Klick versteckt. Die eigentliche Logik (Migration
/// vorhandener Dokumente, Warnung vor fremden Belegordnern) steckt in
/// `WorkingDirectoryChange`, damit beide Stellen exakt gleich verhalten.
/// Eigener, lokaler Sheet-/Alert-Zustand statt geteiltem: `SettingsView`
/// hat sonst keine weiteren Sheets/Alerts, ein Konflikt mit dem
/// „nur ein Präsentations-Modifier gleichzeitig“-Verhalten aus
/// `DocumentsView.activeSheet` besteht hier also nicht.
private struct DocumentsSettingsSection: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var isConfigured = WorkingDirectoryStore.isConfigured
    /// Erzwingt eine Neuberechnung des Pfad-Texts nach einem Wechsel –
    /// `WorkingDirectoryStore` ist reines UserDefaults ohne SwiftUI-
    /// Reaktivität (siehe gleichlautender Kommentar in `DocumentsView`).
    @State private var revision = 0
    @State private var migrationFailures: [DocumentMigration.Failure] = []
    @State private var isPresentingMigrationFailures = false
    @State private var hinweis: Hinweis?

    private struct Hinweis: Identifiable {
        let id = UUID()
        let titel: String
        let text: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Arbeitsverzeichnis")
                .font(.headline)
            Text(WorkingDirectoryStore.displayPath ?? "Kein Arbeitsverzeichnis festgelegt")
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .id(revision)
            HStack(spacing: 10) {
                Button(isConfigured ? "Ändern…" : "Ordner wählen…") {
                    presentFolderPicker()
                }
                .buttonStyle(.bordered)
                .pointerStyle(.link)

                if isConfigured {
                    Button {
                        revealInFinder()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                    .pointerStyle(.link)
                    .help("Im Finder anzeigen")
                }
            }
        }
        .alert(
            hinweis?.titel ?? "",
            isPresented: Binding(
                get: { hinweis != nil },
                set: { if !$0 { hinweis = nil } }
            ),
            presenting: hinweis
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { hinweis in
            Text(hinweis.text)
        }
        .sheet(isPresented: $isPresentingMigrationFailures) {
            MigrationFailuresSheet(failures: migrationFailures, onDismiss: { isPresentingMigrationFailures = false })
        }
    }

    private func presentFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Wählen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let outcome = try WorkingDirectoryChange.apply(url: url, in: viewContext)
            isConfigured = true
            revision += 1
            if !outcome.migrationFailures.isEmpty {
                migrationFailures = outcome.migrationFailures
                isPresentingMigrationFailures = true
            } else if let warning = outcome.foreignFolderWarning {
                hinweis = Hinweis(titel: "Fremde Belegordner im Verzeichnis", text: warning)
            }
        } catch {
            hinweis = Hinweis(titel: "Fehler", text: error.localizedDescription)
        }
    }

    /// Öffnet das Arbeitsverzeichnis selbst im Finder – der Zugriff muss
    /// innerhalb von `withAccess` passieren, da der Security-Scope sonst mit
    /// dessen Rückkehr endet (siehe gleichlautender Kommentar an
    /// `Dokument.withResolvedURL`).
    private func revealInFinder() {
        do {
            try WorkingDirectoryStore.withAccess { url in
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            hinweis = Hinweis(titel: "Fehler", text: error.localizedDescription)
        }
    }
}

/// Inhalt der Sektion „Spritpreise“: Eingabe des Tankerkönig-API-Schlüssels
/// und des Suchradius der Umkreissuche – vormals direkt in `FuelPricesView`,
/// jetzt zentral hier, damit die eigentliche Ansicht sich auf
/// Karte/Ergebnisse konzentrieren kann. Nutzt dasselbe, App-weit geteilte
/// `FuelPricesViewModel` wie `FuelPricesView` selbst (als Environment-Objekt
/// injiziert, siehe `FuhrparkDesktopApp`) – ein hier gespeicherter Schlüssel
/// startet deshalb auch sofort den Ladevorgang, dessen Ergebnis beim
/// nächsten Besuch von „Spritpreise“ im Hauptfenster bereits steht.
private struct FuelPricesSettingsSection: View {
    @Environment(FuelPricesViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm
        VStack(alignment: .leading, spacing: 10) {
            Text("Tankerkönig-API-Schlüssel")
                .font(.headline)
            Text("Wird für die Umkreissuche nach Spritpreisen in der Nähe benötigt.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ValidatedField(
                title: "API-Schlüssel",
                text: $vm.apiKey,
                kind: .apiKey,
                isValidBinding: $vm.isKeyFieldValid
            )

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let cooldownActive = vm.secondsRemaining(asOf: context.date) != nil
                Button("Speichern & Laden") {
                    vm.saveKeyAndStart()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.isKeyFieldValid || cooldownActive)
                .pointerStyle(vm.isKeyFieldValid && !cooldownActive ? .link : nil)
            }

            Divider()
                .padding(.vertical, 4)

            Text("Suchradius")
                .font(.headline)
            Text("Wie weit die Umkreissuche nach Tankstellen reicht.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                Slider(value: $vm.searchRadiusKm, in: 1...25, step: 0.5) {
                    Text("Suchradius")
                } minimumValueLabel: {
                    Text("1 km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Text("25 km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .labelsHidden()

                Text(DisplayFormatter.radiusKmString(vm.searchRadiusKm))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

/// Abschnitte im Einstellungsfenster: links als Liste, rechts der
/// zugehörige Inhalt. Weitere Abschnitte ergänzen hier einfach einen Fall.
enum SettingsSection: String, CaseIterable, Identifiable {
    case documents
    case fuelPrices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents: return "Dokumente"
        case .fuelPrices: return "Spritpreise"
        }
    }

    /// Dasselbe Symbol wie beim jeweiligen Eintrag in `SidebarView`.
    var systemImage: String {
        switch self {
        case .documents: return "folder.fill"
        case .fuelPrices: return "fuelpump.circle"
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(FuelPricesViewModel())
}
