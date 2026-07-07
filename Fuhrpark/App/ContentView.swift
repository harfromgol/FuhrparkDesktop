import SwiftUI

/// Auswahl in der Seitenleiste: allgemeine Statistik oder ein Fahrzeug.
enum SidebarSelection: Hashable {
    case statistics
    case vehicle(Vehicle)
}

struct ContentView: View {
    @State private var selection: SidebarSelection = .statistics

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            switch selection {
            case .statistics:
                StatisticsView()
            case .vehicle(let vehicle):
                VehicleDetailView(vehicle: vehicle)
                    .id(vehicle.objectID)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
