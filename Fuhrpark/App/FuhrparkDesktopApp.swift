import SwiftUI

@main
struct FuhrparkDesktopApp: App {
    /// Feste ID des Hauptfensters – für „Neues Fenster“ / „Fenster schließen“.
    static let mainWindowID = "main"

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
            Button("Alle Daten löschen…") {
                appCommands.showDeleteAllDataConfirmation = true
            }
        }
    }
}
