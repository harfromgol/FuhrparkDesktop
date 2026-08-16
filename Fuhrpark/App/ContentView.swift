import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Auswahl in der Seitenleiste: allgemeine Statistik oder ein Fahrzeug.
enum SidebarSelection: Hashable {
    case statistics
    case fuelPrices
    case documents
    case reminders
    case mcp
    case vehicle(Vehicle)
}

struct ContentView: View {
    @Environment(AppCommands.self) private var appCommands
    @Environment(FuelPricesViewModel.self) private var fuelPricesViewModel
    @Environment(PinnedFuelPricesViewModel.self) private var pinnedFuelPricesViewModel
    @Environment(UpdateChecker.self) private var updateChecker
    @State private var selection: SidebarSelection = .statistics

    /// Wird beim Start gesetzt, wenn sich der Datenspeicher nicht öffnen ließ
    /// (etwa weil eine Modellmigration fehlgeschlagen ist). Ohne diesen
    /// Hinweis stünde die App mit leeren Listen da und der Nutzer müsste
    /// glauben, seine Daten seien weg.
    @State private var showsStoreError = PersistenceController.shared.loadError != nil

    var body: some View {
        @Bindable var appCommands = appCommands

        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            switch selection {
            case .statistics:
                StatisticsView()
            case .fuelPrices:
                FuelPricesView()
            case .documents:
                DocumentsView()
            case .reminders:
                RemindersView()
            case .mcp:
                MCPSettingsView()
            case .vehicle(let vehicle):
                VehicleDetailView(vehicle: vehicle, onDelete: { selection = .statistics })
                    .id(vehicle.objectID)
            }
        }
        // Der Titel in der Fensterleiste kommt von der `.navigationTitle` der
        // gerade gewählten Ansicht und überschreibt den Titel der Szene; der
        // Zusatz aus `Window(AppVariant.windowTitle, …)` wirkt nur im
        // „Fenster“-Menü. Beim Testbau kommt deshalb hier ein Untertitel dazu,
        // damit auch am Fenster selbst erkennbar ist, welcher Datenbestand
        // offen ist. Die produktive App bleibt unverändert.
        .navigationSubtitle(AppVariant.isTestContainer ? "Testdaten" : "")
        .alert("Datenbank konnte nicht geöffnet werden", isPresented: $showsStoreError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("""
                \(PersistenceController.shared.loadError ?? "")

                Deine Daten sind dadurch nicht verloren – sie wurden nur nicht \
                geladen. Bitte nichts eingeben und nichts löschen, solange \
                dieser Hinweis erscheint, sonst überschreibst du den bisherigen \
                Stand. Am besten die App beenden und die vorige Version wieder \
                installieren oder ein Backup einspielen.
                """)
        }
        .confirmationDialog(
            "Wirklich alle Daten löschen?",
            isPresented: $appCommands.showDeleteAllDataConfirmation,
            titleVisibility: .visible
        ) {
            Button("Alle Daten löschen", role: .destructive) {
                deleteAllData()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Alle Fahrzeuge, Betankungen, sonstigen Ausgaben, Kategorien und Erinnerungen sowie der gespeicherte Tankerkönig-API-Schlüssel und die angepinnten Spritpreise werden unwiderruflich gelöscht. Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
        // Export/Import laufen bewusst NICHT über `.fileExporter`/`.fileImporter`,
        // sondern über direkte `NSSavePanel`/`NSOpenPanel` (siehe
        // `presentExportPanel`/`presentImportPanel`): Beide SwiftUI-Modifier
        // zeigen den Dialog als Sheet, das am Fenster verankert und nicht frei
        // verschiebbar ist (siehe auch `DocumentsView.presentFolderPicker`).
        .onChange(of: appCommands.showExportDialog) { _, isShown in
            guard isShown else { return }
            appCommands.showExportDialog = false
            presentExportPanel()
        }
        .onChange(of: appCommands.showImportDialog) { _, isShown in
            guard isShown else { return }
            appCommands.showImportDialog = false
            presentImportPanel()
        }
        .alert(
            "Datenübertragung fehlgeschlagen",
            isPresented: Binding(
                get: { appCommands.transferError != nil },
                set: { if !$0 { appCommands.transferError = nil } }
            ),
            presenting: appCommands.transferError
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .modifier(UpdateNoticeModifier(updateChecker: updateChecker))
    }

    /// Dateiname-Vorschlag ohne Endung; `fileExporter` ergänzt „.json".
    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "FuhrparkDesktop_\(formatter.string(from: Date()))"
    }

    private func presentExportPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(exportFilename).json"
        panel.prompt = "Sichern"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DataTransfer.exportData().write(to: url, options: .atomic)
        } catch {
            appCommands.transferError = error.localizedDescription
        }
    }

    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Importieren"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importData(from: url)
    }

    private func importData(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            // Auswahl zuerst zurücksetzen, da der Import alle Daten löscht.
            selection = .statistics
            try DataTransfer.importData(data)
        } catch {
            appCommands.transferError = error.localizedDescription
        }
    }

    private func deleteAllData() {
        // Auswahl zuerst zurücksetzen, damit der Detailbereich nicht auf ein
        // gleich gelöschtes (invalidiertes) Fahrzeug zugreift.
        selection = .statistics
        PersistenceController.shared.deleteAllData()
        fuelPricesViewModel.resetAPIKey()
        pinnedFuelPricesViewModel.resetPinnedSelections()
    }
}

/// Bündelt die vier Präsentationen der Update-Prüfung in einem eigenen
/// `ViewModifier` – hält `body` schlank genug für den Type-Checker (sonst
/// „unable to type-check this expression in reasonable time", siehe
/// `FuelEntryListAlertsModifier` in `FuelEntryListWindow.swift` für dasselbe
/// Muster).
private struct UpdateNoticeModifier: ViewModifier {
    @Bindable var updateChecker: UpdateChecker

    func body(content: Content) -> some View {
        content
            .sheet(item: $updateChecker.availableRelease) { release in
                UpdateAvailableSheet(
                    release: release,
                    currentVersion: updateChecker.currentVersion,
                    automaticChecks: $updateChecker.automaticChecksEnabled,
                    onSkip: { updateChecker.skipOfferedRelease() },
                    onDismiss: { updateChecker.availableRelease = nil }
                )
            }
            .confirmationDialog(
                "Nach neuen Versionen suchen?",
                isPresented: $updateChecker.showsPermissionQuestion,
                titleVisibility: .visible
            ) {
                Button("Ja, beim Start nachsehen") {
                    Task { await updateChecker.answerPermissionQuestion(allowed: true) }
                }
                Button("Nein", role: .cancel) {
                    Task { await updateChecker.answerPermissionQuestion(allowed: false) }
                }
            } message: {
                Text("""
                    FuhrparkDesktop kann beim Start höchstens einmal täglich nachsehen, \
                    ob eine neue Version vorliegt. Dabei wird nur eine kleine Datei von \
                    fuhrpark-macos.gerd-klaus.de geladen – es werden keine Angaben über \
                    dich oder deinen Fuhrpark übertragen, auch nicht die verwendete \
                    Version.

                    Die Einstellung lässt sich jederzeit im Menü „FuhrparkDesktop“ ändern.
                    """)
            }
            .alert("Du hast die neueste Version", isPresented: $updateChecker.showsUpToDateConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("FuhrparkDesktop \(updateChecker.currentVersion) ist aktuell.")
            }
            .alert(
                "Suche nach Updates fehlgeschlagen",
                isPresented: Binding(
                    get: { updateChecker.manualCheckError != nil },
                    set: { if !$0 { updateChecker.manualCheckError = nil } }
                ),
                presenting: updateChecker.manualCheckError
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(AppCommands())
        .environment(FuelPricesViewModel())
        .environment(PinnedFuelPricesViewModel())
        .environment(UpdateChecker())
}
