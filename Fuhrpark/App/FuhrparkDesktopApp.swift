import SwiftUI

@main
struct FuhrparkDesktopApp: App {
    let persistenceController = PersistenceController.shared
    @State private var appCommands = AppCommands()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(appCommands)
                .frame(minWidth: 800, idealWidth: 1000, minHeight: 500, idealHeight: 650)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Tools") {
                Button("Alle Daten löschen…") {
                    appCommands.showDeleteAllDataConfirmation = true
                }
            }
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
