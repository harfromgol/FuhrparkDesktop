import SwiftUI

@main
struct FuhrparkDesktopApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .frame(minWidth: 800, idealWidth: 1000, minHeight: 500, idealHeight: 650)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
