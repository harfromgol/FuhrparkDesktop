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
    @State private var vehiclePendingDecommission: Vehicle?

    var body: some View {
        list
            .navigationTitle("Fuhrpark")
            .toolbar {
                ToolbarItem {
                    Button {
                        isPresentingNewVehicle = true
                    } label: {
                        Label("Neues Fahrzeug", systemImage: "plus")
                    }
                    .pointerStyle(.link)
                }
            }
            .sheet(isPresented: $isPresentingNewVehicle) {
                VehicleFormView()
            }
            .modifier(VehicleConfirmationModifier(
                pending: $vehiclePendingDeletion,
                title: "Fahrzeug wirklich löschen?",
                actionLabel: "Löschen",
                actionRole: .destructive,
                message: { "„\($0.licensePlate ?? "")“ und alle zugehörigen \($0.engineType.refuelNounPlural) und Ausgaben werden unwiderruflich gelöscht." },
                action: delete
            ))
            .modifier(VehicleConfirmationModifier(
                pending: $vehiclePendingDecommission,
                title: "Fahrzeug wirklich stilllegen?",
                actionLabel: "Stilllegen",
                actionRole: nil,
                message: { "„\($0.licensePlate ?? "")“ wird als stillgelegt (verschrottet oder verkauft) markiert. Danach können keine \($0.engineType.refuelNounPlural) und sonstigen Ausgaben mehr erfasst werden." },
                action: decommission
            ))
    }

    private var list: some View {
        List {
            Section("Allgemein") {
                Button {
                    selection = .statistics
                } label: {
                    Label("Statistik", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .listRowBackground(rowBackground(for: .statistics))
            }

            Section("Fahrzeuge") {
                ForEach(vehicles) { vehicle in
                    vehicleRow(vehicle)
                }
                .onDelete { offsets in
                    for index in offsets {
                        vehiclePendingDeletion = vehicles[index]
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        Button {
            selection = .vehicle(vehicle)
        } label: {
            VehicleRow(vehicle: vehicle)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .listRowBackground(rowBackground(for: .vehicle(vehicle)))
        .contextMenu { vehicleContextMenu(for: vehicle) }
    }

    @ViewBuilder
    private func vehicleContextMenu(for vehicle: Vehicle) -> some View {
        if vehicle.decommissioned {
            Button("Wieder in Betrieb nehmen") {
                reactivate(vehicle)
            }
        } else {
            Button("Fahrzeug stilllegen") {
                vehiclePendingDecommission = vehicle
            }
        }
        Button("Fahrzeug löschen", role: .destructive) {
            vehiclePendingDeletion = vehicle
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

    private func decommission(_ vehicle: Vehicle) {
        vehicle.decommissioned = true
        PersistenceController.shared.save(context: viewContext)
    }

    private func reactivate(_ vehicle: Vehicle) {
        vehicle.decommissioned = false
        PersistenceController.shared.save(context: viewContext)
    }
}

/// Wiederverwendbarer Bestätigungsdialog für eine Fahrzeug-Aktion (Löschen bzw.
/// Stilllegen). Als eigener `ViewModifier`, damit `SidebarView.body` schlank und
/// für den Type-Checker handhabbar bleibt.
private struct VehicleConfirmationModifier: ViewModifier {
    @Binding var pending: Vehicle?
    let title: String
    let actionLabel: String
    let actionRole: ButtonRole?
    let message: (Vehicle) -> String
    let action: (Vehicle) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            presenting: pending
        ) { vehicle in
            Button(actionLabel, role: actionRole) { action(vehicle) }
            Button("Abbrechen", role: .cancel) { }
        } message: { vehicle in
            Text(message(vehicle))
        }
    }
}

private struct VehicleRow: View {
    @ObservedObject var vehicle: Vehicle

    private var dimmed: Double { vehicle.decommissioned ? 0.5 : 1 }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vehicle.licensePlate ?? "")
                        .font(.headline)
                        .opacity(dimmed)
                    if vehicle.decommissioned {
                        DecommissionedBadge()
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Anfangsstand: \(DisplayFormatter.odometerString(vehicle.odometer)) km")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Höchststand: \(DisplayFormatter.odometerString(vehicle.highestOdometer)) km")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .opacity(dimmed)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.leading, 5)
        .contentShape(Rectangle())
    }
}

/// Rote „Stillgelegt"-Marke. Adaptives System-Rot (Dark: heller, Light: satter),
/// daher auf hellem und dunklem Hintergrund gut lesbar.
struct DecommissionedBadge: View {
    var showsIcon = false

    var body: some View {
        Group {
            if showsIcon {
                Label("Stillgelegt", systemImage: "xmark.seal.fill")
            } else {
                Text("Stillgelegt")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.red)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.red.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(.red.opacity(0.4), lineWidth: 0.5))
    }
}
