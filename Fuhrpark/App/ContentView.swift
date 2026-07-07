import SwiftUI

/// Auswahl in der Seitenleiste: allgemeine Statistik oder ein Fahrzeug.
enum SidebarSelection: Hashable {
    case statistics
    case vehicle(Vehicle)
}

struct ContentView: View {
    @Environment(AppCommands.self) private var appCommands
    @State private var selection: SidebarSelection = .statistics

    var body: some View {
        @Bindable var appCommands = appCommands

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
            Text("Alle Fahrzeuge, Betankungen, sonstigen Ausgaben und Kategorien werden unwiderruflich gelöscht. Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
    }

    private func deleteAllData() {
        // Auswahl zuerst zurücksetzen, damit der Detailbereich nicht auf ein
        // gleich gelöschtes (invalidiertes) Fahrzeug zugreift.
        selection = .statistics
        PersistenceController.shared.deleteAllData()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(AppCommands())
}
