import SwiftUI
import AppKit

/// Kein `@main`: Der Programmeinstieg liegt in `main.swift`, weil dasselbe
/// Binary auch als MCP-Server laufen kann und die Weiche vor der
/// AppKit-Initialisierung greifen muss.
struct FuhrparkDesktopApp: App {
    /// Feste ID des Hauptfensters – für „Neues Fenster“ / „Fenster schließen“.
    static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let persistenceController = PersistenceController.shared
    @State private var appCommands = AppCommands()
    @State private var fuelPricesViewModel = FuelPricesViewModel()
    @State private var pinnedFuelPricesViewModel = PinnedFuelPricesViewModel()
    @State private var updateChecker = UpdateChecker()
    /// Wendet das gespeicherte Erscheinungsbild an, sobald der App-Start
    /// abgeschlossen ist (siehe dessen `init()` zum Grund für die Verzögerung).
    @State private var appearanceSettings = AppearanceSettings()

    var body: some Scene {
        // Einzelfenster-Szene: kann per Menü geschlossen und wieder geöffnet
        // werden. Der Titel nennt beim Testbau den Container mit, damit man
        // ihm nicht versehentlich echte Daten anvertraut.
        Window(AppVariant.windowTitle, id: Self.mainWindowID) {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(appCommands)
                .environment(fuelPricesViewModel)
                .environment(pinnedFuelPricesViewModel)
                .environment(updateChecker)
                .environment(appearanceSettings)
                .frame(minWidth: 800, idealWidth: 1000, minHeight: 500, idealHeight: 650)
                .onAppear { appCommands.isMainWindowOpen = true }
                .onDisappear { appCommands.isMainWindowOpen = false }
                .task { await appCommands.scheduleDailyDueCheck() }
                .task { await updateChecker.checkAutomatically() }
                .persistWindowFrame(Self.mainWindowID)
        }
        .commands {
            AppMenuCommands(appCommands: appCommands, updateChecker: updateChecker)
        }

        // Singleton wie das Hauptfenster (kein Payload, keine
        // Mehrfachinstanzen nötig) – deshalb `Window`, nicht `WindowGroup`
        // wie bei den übrigen, VehicleRef-parametrisierten Fenstern unten.
        Window("Tankstellenliste", id: "gas-station-list") {
            GasStationListWindow()
                .environment(fuelPricesViewModel)
                .environment(pinnedFuelPricesViewModel)
                .persistWindowFrame("gas-station-list")
        }
        .defaultSize(width: 480, height: 560)

        // Menüleisten-Icon erscheint erst, sobald mindestens eine
        // Tankstelle/Sorte angepinnt ist (`isMenuBarVisible`) – siehe
        // Doc-Kommentar dort für den Grund, warum das ein echtes,
        // schreibbares Binding auf dem View-Model ist statt eines rein aus
        // `pinnedSelections` berechneten. Bewusst `@Bindable` statt eines von
        // Hand gebauten `Binding(get:set:)`: Nur ein über `@Bindable`
        // erzeugtes Binding liest/schreibt wirklich live auf die
        // `@Observable`-Speicherung – ein händisches Binding wurde von
        // SwiftUI bei dieser Szene nicht zuverlässig neu ausgewertet, sodass
        // ein `isMenuBarVisible = false` (z. B. bei „App zurücksetzen")
        // das Icon nicht entfernte.
        @Bindable var pinnedFuelPricesBindable = pinnedFuelPricesViewModel
        MenuBarExtra(isInserted: $pinnedFuelPricesBindable.isMenuBarVisible) {
            PinnedFuelPricesMenuView()
                .environment(pinnedFuelPricesViewModel)
        } label: {
            PinnedFuelPricesMenuBarLabel()
                .environment(pinnedFuelPricesViewModel)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Betankungen", id: "fuel-list", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                FuelEntryListWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .persistWindowFrame("fuel-list")
            }
        }
        .defaultSize(width: 400, height: 520)

        WindowGroup("Sonstige Ausgaben", id: "expense-list", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                ExpenseListWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .persistWindowFrame("expense-list")
            }
        }
        .defaultSize(width: 400, height: 520)

        WindowGroup("Spritpreis-Verlauf", id: "price-chart", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                PriceChartWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .persistWindowFrame("price-chart")
            }
        }
        .defaultSize(width: 620, height: 420)

        WindowGroup("Verbrauch-Verlauf", id: "consumption-chart", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                ConsumptionChartWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .persistWindowFrame("consumption-chart")
            }
        }
        .defaultSize(width: 620, height: 420)

        WindowGroup("Gefahrene km pro Jahr", id: "distance-chart", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                DistanceChartWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .persistWindowFrame("distance-chart")
            }
        }
        .defaultSize(width: 620, height: 420)

        WindowGroup("Gesamtkosten pro Kategorie", id: "category-chart", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                CategoryChartWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .persistWindowFrame("category-chart")
            }
        }
        .defaultSize(width: 620, height: 480)

        WindowGroup("Kosten pro Jahr", id: "yearly-cost-chart", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                YearlyCostChartWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .persistWindowFrame("yearly-cost-chart")
            }
        }
        .defaultSize(width: 620, height: 420)
    }
}

/// Menübefehle: App-Menü (Update-Prüfung), „Ablage“ (Neues Fenster / Fenster
/// schließen) und „Tools“.
struct AppMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    /// Geteilter Zustand (Öffnungszustand des Hauptfensters, Löschabfrage).
    let appCommands: AppCommands

    /// Update-Prüfung; die Dialoge dazu zeigt `ContentView`.
    @Bindable var updateChecker: UpdateChecker

    var body: some Commands {
        // Direkt unter „Über FuhrparkDesktop”, gefolgt von der Update-Prüfung
        // – dort suchen macOS-Nutzer beides. Zwei separate
        // `CommandGroup(after: .appInfo)`-Blöcke würden ohne Trennlinie
        // dazwischen verschmelzen (live geprüft); die vom Nutzer gewünschten
        // Trennlinien um „Einstellungen …” müssen deshalb explizit als
        // `Divider()` in derselben Gruppe stehen, wie schon im Tools-Menü
        // unten. Der frühere Toggle „Automatisch nach Updates suchen” liegt
        // jetzt in den Einstellungen (Abschnitt „Updates”, siehe
        // `SettingsView.swift`) – dort auch der Weg zurück, falls der
        // Einrichtungsassistent (`SetupWizardView`, siehe `ContentView.swift`)
        // oder eine spätere Abwahl das automatische Prüfen ausgeschaltet hat.
        CommandGroup(after: .appInfo) {
            Divider()

            Button("Einstellungen …") {
                appCommands.showSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Nach Updates suchen …") {
                Task { await updateChecker.checkManually() }
            }
            .disabled(updateChecker.isChecking)
        }

        // Ablage-Menü: Hauptfenster öffnen bzw. jeweils fokussiertes Fenster schließen.
        CommandGroup(replacing: .newItem) {
            Button("Neues Fenster") {
                openWindow(id: FuhrparkDesktopApp.mainWindowID)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(appCommands.isMainWindowOpen)

            // Schließt das gerade fokussierte Fenster (Haupt-, Listen- oder
            // Chart-Fenster) statt fest verdrahtet immer das Hauptfenster –
            // sonst schließt ⌘W in einem Listen-/Chart-Fenster fälschlich
            // das Hauptfenster.
            Button("Fenster schließen") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        CommandMenu("Tools") {
            Button("Backup erstellen …", systemImage: "externaldrive.badge.plus") {
                appCommands.showBackupFolderPicker = true
            }
            .disabled(appCommands.isBackupRunning)

            Button("Backup einspielen …", systemImage: "externaldrive.badge.checkmark") {
                appCommands.showRestoreFilePicker = true
            }
            .disabled(appCommands.isBackupRunning)

            Divider()

            // JSON-Export/Import zur Datenübergabe an die FuhrparkWeb-App
            // (separat vom Backup, siehe dessen Doc-Kommentare zur Abgrenzung).
            Menu("Fuhrpark Web") {
                Button("JSON exportieren", systemImage: "square.and.arrow.up") {
                    appCommands.showExportDialog = true
                }
                Button("JSON importieren", systemImage: "square.and.arrow.down") {
                    appCommands.showImportDialog = true
                }
            }

            Divider()

            Button("App zurücksetzen", systemImage: "arrow.counterclockwise") {
                appCommands.showResetAppConfirmation = true
            }
        }
    }
}

/// Blendet die nicht benötigten Standardmenüs Darstellung und Hilfe aus.
///
/// Diese Menütitel verschwinden über die SwiftUI-`commands` nicht (Darstellung
/// hält „Vollbildmodus“, Hilfe ergänzt AppKit selbst), und SwiftUI/AppKit bauen
/// die Leiste beim Fensterwechsel neu auf. Die Menüs werden daher bei jedem
/// Menüaufbau ausgeblendet. Wichtig: Ausblenden (`isHidden`) statt Entfernen –
/// die Einträge bleiben in SwiftUIs Menüstruktur, sonst kollidiert der Eingriff
/// mit dessen Update-Zyklus und blockiert z. B. die Fahrzeugauswahl.
///
/// Das Bearbeiten-Menü bleibt bewusst erhalten, da sonst ⌘A/⌘C/⌘V/⌘X/⌘Z in
/// Textfeldern nicht mehr funktionieren.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bei jedem Menüaufbau die nicht benötigten Menüs ausblenden. Wichtig:
        // Ausblenden (statt Entfernen) lässt die Einträge in SwiftUIs
        // Menüstruktur bestehen – sonst kollidiert der Eingriff mit SwiftUIs
        // Update-Zyklus und blockiert z. B. die Fahrzeugauswahl.
        NotificationCenter.default.addObserver(
            forName: NSMenu.didAddItemNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { hideMenus(["Darstellung", "View", "Hilfe", "Help"]) }
        }
        hideMenus(["Darstellung", "View", "Hilfe", "Help"])
    }
}

/// Blendet die angegebenen Top-Level-Menüs in `NSApp.mainMenu` aus.
@MainActor
private func hideMenus(_ titles: Set<String>) {
    guard let mainMenu = NSApp.mainMenu else { return }
    for item in mainMenu.items where titles.contains(item.title) && !item.isHidden {
        item.isHidden = true
    }
}
