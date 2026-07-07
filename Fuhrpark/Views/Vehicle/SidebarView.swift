import SwiftUI
import CoreData

struct SidebarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selection: SidebarSelection

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Vehicle.lastChangedDts, ascending: false),
            NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)
        ],
        animation: .default
    )
    private var vehicles: FetchedResults<Vehicle>

    @State private var isPresentingNewVehicle = false
    @State private var vehiclePendingDeletion: Vehicle?

    var body: some View {
        List {
            Section("Allgemein") {
                Button {
                    selection = .statistics
                } label: {
                    Label("Statistik", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground(for: .statistics))
            }

            Section("Fahrzeuge") {
                ForEach(vehicles) { vehicle in
                    Button {
                        selection = .vehicle(vehicle)
                    } label: {
                        VehicleRow(vehicle: vehicle)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(for: .vehicle(vehicle)))
                    .contextMenu {
                        Button("Fahrzeug löschen", role: .destructive) {
                            vehiclePendingDeletion = vehicle
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        vehiclePendingDeletion = vehicles[index]
                    }
                }
            }
        }
        .navigationTitle("Fuhrpark")
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingNewVehicle = true
                } label: {
                    Label("Neues Fahrzeug", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewVehicle) {
            VehicleFormView()
        }
        .confirmationDialog(
            "Fahrzeug wirklich löschen?",
            isPresented: Binding(
                get: { vehiclePendingDeletion != nil },
                set: { if !$0 { vehiclePendingDeletion = nil } }
            ),
            presenting: vehiclePendingDeletion
        ) { vehicle in
            Button("Löschen", role: .destructive) {
                delete(vehicle)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { vehicle in
            Text("„\(vehicle.licensePlate ?? "")“ und alle zugehörigen Betankungen und Ausgaben werden unwiderruflich gelöscht.")
        }
    }

    private func rowBackground(for item: SidebarSelection) -> Color {
        selection == item ? Color.accentColor.opacity(0.2) : Color.clear
    }

    private func delete(_ vehicle: Vehicle) {
        if selection == .vehicle(vehicle) {
            selection = .statistics
        }
        viewContext.delete(vehicle)
        PersistenceController.shared.save(context: viewContext)
    }
}

private struct VehicleRow: View {
    @ObservedObject var vehicle: Vehicle

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.licensePlate ?? "")
                    .font(.headline)
                Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
