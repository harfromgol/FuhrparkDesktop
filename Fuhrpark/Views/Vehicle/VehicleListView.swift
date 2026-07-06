import SwiftUI
import CoreData

struct VehicleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedVehicle: Vehicle?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)],
        animation: .default
    )
    private var vehicles: FetchedResults<Vehicle>

    @State private var isPresentingNewVehicle = false
    @State private var vehiclePendingDeletion: Vehicle?

    var body: some View {
        List {
            ForEach(vehicles) { vehicle in
                Button {
                    selectedVehicle = vehicle
                } label: {
                    VehicleRow(vehicle: vehicle, isSelected: selectedVehicle == vehicle)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selectedVehicle == vehicle ? Color.accentColor.opacity(0.2) : Color.clear
                )
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

    private func delete(_ vehicle: Vehicle) {
        if selectedVehicle == vehicle {
            selectedVehicle = nil
        }
        viewContext.delete(vehicle)
        PersistenceController.shared.save(context: viewContext)
    }
}

private struct VehicleRow: View {
    @ObservedObject var vehicle: Vehicle
    var isSelected: Bool

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

#Preview {
    VehicleListView(selectedVehicle: .constant(nil))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
