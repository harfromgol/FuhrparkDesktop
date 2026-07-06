import SwiftUI

struct ContentView: View {
    @State private var selectedVehicle: Vehicle?

    var body: some View {
        NavigationSplitView {
            VehicleListView(selectedVehicle: $selectedVehicle)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let selectedVehicle {
                VehicleDetailView(vehicle: selectedVehicle)
                    .id(selectedVehicle.objectID)
            } else {
                ContentUnavailableView(
                    "Kein Fahrzeug ausgewählt",
                    systemImage: "car.2",
                    description: Text("Wähle links ein Fahrzeug aus oder lege ein neues an.")
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
