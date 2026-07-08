import SwiftUI
import AppKit

@main
struct FuhrparkDesktopApp: App {
    /// Feste ID des Hauptfensters – für „Neues Fenster“ / „Fenster schließen“.
    static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let persistenceController = PersistenceController.shared
    @State private var appCommands = AppCommands()

    var body: some Scene {
        // Einzelfenster-Szene: kann per Menü geschlossen und wieder geöffnet werden.
        Window("FuhrparkDesktop", id: Self.mainWindowID) {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(appCommands)
                .frame(minWidth: 800, idealWidth: 1000, minHeight: 500, idealHeight: 650)
                .onAppear { appCommands.isMainWindowOpen = true }
                .onDisappear { appCommands.isMainWindowOpen = false }
        }
        .commands {
            AppMenuCommands(appCommands: appCommands)
        }

        WindowGroup("Betankungen", id: "fuel-list", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                FuelEntryListWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
        .defaultSize(width: 400, height: 520)

        WindowGroup("Sonstige Ausgaben", id: "expense-list", for: VehicleRef.self) { $vehicleRef in
            if let vehicleRef {
                ExpenseListWindow(vehicleRef: vehicleRef)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
        .defaultSize(width: 400, height: 520)
    }
}

/// Menübefehle: „Ablage“ (Neues Fenster / Fenster schließen) und „Tools“.
struct AppMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    /// Geteilter Zustand (Öffnungszustand des Hauptfensters, Löschabfrage).
    let appCommands: AppCommands

    var body: some Commands {
        // Ablage-Menü: Hauptfenster öffnen bzw. schließen.
        CommandGroup(replacing: .newItem) {
            Button("Neues Fenster") {
                openWindow(id: FuhrparkDesktopApp.mainWindowID)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(appCommands.isMainWindowOpen)

            Button("Fenster schließen") {
                dismissWindow(id: FuhrparkDesktopApp.mainWindowID)
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(!appCommands.isMainWindowOpen)
        }

        CommandMenu("Tools") {
            Button("Daten exportieren", systemImage: "square.and.arrow.up") {
                appCommands.showExportDialog = true
            }
            Button("Daten importieren", systemImage: "square.and.arrow.down") {
                appCommands.showImportDialog = true
            }

            Divider()

            Button("Alle Daten löschen", systemImage: "trash") {
                appCommands.showDeleteAllDataConfirmation = true
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
