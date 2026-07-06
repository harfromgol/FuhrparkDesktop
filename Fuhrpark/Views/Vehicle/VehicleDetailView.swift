import SwiftUI

struct VehicleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var vehicle: Vehicle

    @State private var isPresentingNewFuelEntry = false
    @State private var isPresentingNewExpense = false

    private var vehicleRef: VehicleRef? {
        guard let id = vehicle.id else { return nil }
        return VehicleRef(id: id, licensePlate: vehicle.licensePlate ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                statistics

                sectionHeader(title: "Betankungen", systemImage: "fuelpump.fill") {
                    Button("Neue Betankung", systemImage: "plus") {
                        isPresentingNewFuelEntry = true
                    }
                    .buttonStyle(.glass)
                    if !vehicle.sortedFuelEntries.isEmpty {
                        Button("Liste anzeigen", systemImage: "list.bullet") {
                            if let vehicleRef {
                                openWindow(id: "fuel-list", value: vehicleRef)
                            }
                        }
                        .buttonStyle(.glass)
                    }
                }

                Text("\(vehicle.sortedFuelEntries.count) Betankung(en) erfasst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                sectionHeader(title: "Sonstige Ausgaben", systemImage: "eurosign.circle.fill") {
                    Button("Neue Ausgabe", systemImage: "plus") {
                        isPresentingNewExpense = true
                    }
                    .buttonStyle(.glass)
                    if !vehicle.sortedExpenses.isEmpty {
                        Button("Liste anzeigen", systemImage: "list.bullet") {
                            if let vehicleRef {
                                openWindow(id: "expense-list", value: vehicleRef)
                            }
                        }
                        .buttonStyle(.glass)
                    }
                }

                Text("\(vehicle.sortedExpenses.count) Ausgabe(n) erfasst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle(vehicle.licensePlate ?? "")
        .sheet(isPresented: $isPresentingNewFuelEntry) {
            FuelEntryFormView(vehicle: vehicle)
        }
        .sheet(isPresented: $isPresentingNewExpense) {
            ExpenseFormView(vehicle: vehicle)
        }
    }

    private var header: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.licensePlate ?? "")
                        .font(.title2.bold())
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .foregroundStyle(.secondary)
                    Text("\(vehicle.odometer) km · \(vehicle.engineType.displayName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
    }

    private var statistics: some View {
        GlassCard(title: "Statistik") {
            HStack(alignment: .top, spacing: 16) {
                statItem(
                    title: "Gesamtkosten",
                    value: DisplayFormatter.currencyString(vehicle.totalCost),
                    systemImage: "sum"
                )
                Divider()
                statItem(
                    title: "Kosten / km",
                    value: vehicle.costPerKilometer.map { DisplayFormatter.currencyString($0) } ?? "–",
                    systemImage: "gauge.with.dots.needle.bottom.50percent",
                    subtitle: vehicle.drivenKilometers.map { "\($0) km gefahren" } ?? "keine Fahrleistung erfasst"
                )
            }
        }
    }

    private func statItem(title: String, value: String, systemImage: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader<Buttons: View>(
        title: String,
        systemImage: String,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Spacer()
            buttons()
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let vehicle = (try! context.fetch(Vehicle.fetchRequest()) as! [Vehicle]).first!
    return VehicleDetailView(vehicle: vehicle)
        .environment(\.managedObjectContext, context)
}
