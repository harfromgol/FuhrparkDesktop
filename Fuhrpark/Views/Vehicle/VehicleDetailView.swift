import SwiftUI

struct VehicleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var vehicle: Vehicle

    @State private var isPresentingNewFuelEntry = false
    @State private var isPresentingNewExpense = false
    @State private var fuelEntryPendingDeletion: FuelEntry?
    @State private var expensePendingDeletion: Expense?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                statistics

                sectionHeader(
                    title: "Betankungen",
                    systemImage: "fuelpump.fill",
                    action: { isPresentingNewFuelEntry = true },
                    actionLabel: "Neue Betankung"
                )

                if vehicle.sortedFuelEntries.isEmpty {
                    emptyRow("Noch keine Betankungen erfasst.")
                } else {
                    ForEach(vehicle.sortedFuelEntries.reversed()) { entry in
                        FuelEntryRow(entry: entry)
                            .contextMenu {
                                Button("Löschen", role: .destructive) {
                                    fuelEntryPendingDeletion = entry
                                }
                            }
                    }
                }

                sectionHeader(
                    title: "Sonstige Ausgaben",
                    systemImage: "eurosign.circle.fill",
                    action: { isPresentingNewExpense = true },
                    actionLabel: "Neue Ausgabe"
                )

                if vehicle.sortedExpenses.isEmpty {
                    emptyRow("Noch keine Ausgaben erfasst.")
                } else {
                    ForEach(vehicle.sortedExpenses) { expense in
                        ExpenseRow(expense: expense)
                            .contextMenu {
                                Button("Löschen", role: .destructive) {
                                    expensePendingDeletion = expense
                                }
                            }
                    }
                }
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
        .confirmationDialog(
            "Betankung löschen?",
            isPresented: Binding(
                get: { fuelEntryPendingDeletion != nil },
                set: { if !$0 { fuelEntryPendingDeletion = nil } }
            ),
            presenting: fuelEntryPendingDeletion
        ) { entry in
            Button("Löschen", role: .destructive) {
                viewContext.delete(entry)
                PersistenceController.shared.save(context: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        }
        .confirmationDialog(
            "Ausgabe löschen?",
            isPresented: Binding(
                get: { expensePendingDeletion != nil },
                set: { if !$0 { expensePendingDeletion = nil } }
            ),
            presenting: expensePendingDeletion
        ) { expense in
            Button("Löschen", role: .destructive) {
                viewContext.delete(expense)
                PersistenceController.shared.save(context: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
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

    private func sectionHeader(title: String, systemImage: String, action: @escaping () -> Void, actionLabel: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Spacer()
            Button(actionLabel, systemImage: "plus", action: action)
                .buttonStyle(.glass)
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}

private struct FuelEntryRow: View {
    @ObservedObject var entry: FuelEntry

    var body: some View {
        GlassCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(FieldValidator.string(from: entry.date ?? Date()))
                        .font(.subheadline.bold())
                    Text("\(entry.station ?? "") · \(entry.odometer) km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(DisplayFormatter.string(from: entry.liters?.decimalValue ?? 0, formatter: DisplayFormatter.decimal2)) l à \(DisplayFormatter.currencyString(entry.pricePerLiter?.decimalValue ?? 0))/l")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(DisplayFormatter.currencyString(entry.amount?.decimalValue ?? 0))
                        .font(.subheadline.bold())
                    if let consumption = entry.consumption?.doubleValue {
                        Text("\(DisplayFormatter.string(from: Decimal(consumption), formatter: DisplayFormatter.consumption)) l/100km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ExpenseRow: View {
    @ObservedObject var expense: Expense

    var body: some View {
        GlassCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(FieldValidator.string(from: expense.date ?? Date()))
                        .font(.subheadline.bold())
                    Text(expense.recipient ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(expense.purpose ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(DisplayFormatter.currencyString(expense.amount?.decimalValue ?? 0))
                        .font(.subheadline.bold())
                    Text(expense.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let vehicle = (try! context.fetch(Vehicle.fetchRequest()) as! [Vehicle]).first!
    return VehicleDetailView(vehicle: vehicle)
        .environment(\.managedObjectContext, context)
}
