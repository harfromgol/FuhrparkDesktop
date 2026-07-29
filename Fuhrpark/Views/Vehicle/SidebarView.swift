import SwiftUI
import CoreData

struct SidebarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppCommands.self) private var appCommands
    @Binding var selection: SidebarSelection

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Vehicle.lastChangedDts, ascending: false),
            NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)
        ],
        animation: .default
    )
    private var vehicles: FetchedResults<Vehicle>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isDone == NO"),
        animation: .default
    )
    private var openReminders: FetchedResults<Erinnerung>

    @State private var isPresentingNewVehicle = false
    @State private var vehiclePendingDeletion: Vehicle?

    /// Anzahl offener Erinnerungen, die bereits fällig sind (siehe `Erinnerung.isDue`).
    /// Liest `dailyDueCheckTick` mit, damit der Badge auch ohne Klick oder
    /// Datenänderung einmal täglich neu berechnet wird (siehe dort).
    private var dueReminderCount: Int {
        _ = appCommands.dailyDueCheckTick
        return openReminders.filter(\.isDue).count
    }

    /// Aktive Fahrzeuge in der bestehenden Sortierung (zuletzt geändert zuerst).
    private var activeVehicles: [Vehicle] {
        vehicles.filter { !$0.decommissioned }
    }

    /// Stillgelegte Fahrzeuge, alphabetisch nach Kennzeichen.
    private var decommissionedVehicles: [Vehicle] {
        vehicles
            .filter(\.decommissioned)
            .sorted { ($0.licensePlate ?? "") < ($1.licensePlate ?? "") }
    }

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
                message: { "„\($0.licensePlate ?? "")“ und alle zugehörigen \($0.engineType.refuelNounPlural), Ausgaben und Erinnerungen werden unwiderruflich gelöscht." },
                action: delete
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

                Button {
                    selection = .documents
                } label: {
                    Label("Dokumente", systemImage: "folder.fill")
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .listRowBackground(rowBackground(for: .documents))

                Button {
                    selection = .reminders
                } label: {
                    HStack {
                        Label("Erinnerungen", systemImage: "bell.fill")
                        Spacer()
                        if dueReminderCount > 0 {
                            ReminderCountBadge(count: dueReminderCount)
                        }
                    }
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .listRowBackground(rowBackground(for: .reminders))

                Button {
                    selection = .fuelPrices
                } label: {
                    Label("Spritpreise", systemImage: "fuelpump.circle")
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .listRowBackground(rowBackground(for: .fuelPrices))
            }

            Section("Fahrzeuge") {
                ForEach(activeVehicles) { vehicle in
                    vehicleRow(vehicle)
                }
                .onDelete { offsets in
                    for index in offsets {
                        vehiclePendingDeletion = activeVehicles[index]
                    }
                }
            }

            if !decommissionedVehicles.isEmpty {
                Section("Stillgelegte Fahrzeuge") {
                    ForEach(decommissionedVehicles) { vehicle in
                        vehicleRow(vehicle)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            vehiclePendingDeletion = decommissionedVehicles[index]
                        }
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
    }

    private func rowBackground(for item: SidebarSelection) -> Color {
        selection == item ? Color.accentColor.opacity(0.2) : Color.clear
    }

    private func delete(_ vehicle: Vehicle) {
        if selection == .vehicle(vehicle) {
            selection = .statistics
        }
        vehicle.delete(in: viewContext)
    }
}

/// Wiederverwendbarer Bestätigungsdialog für eine Fahrzeug-Aktion (Löschen bzw.
/// Stilllegen). Als eigener `ViewModifier`, damit die aufrufende View schlank
/// und für den Type-Checker handhabbar bleibt. Wird von `SidebarView` (Löschen
/// per Wisch-Geste) und `VehicleDetailView` (Aktionsmenü) genutzt.
struct VehicleConfirmationModifier: ViewModifier {
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

/// Rote numerische Marke für die Anzahl fälliger Erinnerungen.
struct ReminderCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.red, in: Capsule())
    }
}
