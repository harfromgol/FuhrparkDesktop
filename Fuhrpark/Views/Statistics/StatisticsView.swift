import SwiftUI
import CoreData

/// Flottenweite Statistik über alle Fahrzeuge.
struct StatisticsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)],
        animation: .default
    )
    private var vehicles: FetchedResults<Vehicle>

    private var totalCost: Decimal { vehicles.reduce(.zero) { $0 + $1.totalCost } }
    private var totalFuelCost: Decimal { vehicles.reduce(.zero) { $0 + $1.totalFuelCost } }
    private var totalExpenseCost: Decimal { vehicles.reduce(.zero) { $0 + $1.totalExpenseCost } }

    /// Aggregierte Kosten pro Kalenderjahr über alle Fahrzeuge, neuestes Jahr zuerst.
    private var costsByYear: [YearlyCost] {
        let calendar = Calendar.current
        var fuelByYear: [Int: Decimal] = [:]
        var expenseByYear: [Int: Decimal] = [:]

        for vehicle in vehicles {
            for entry in vehicle.sortedFuelEntries {
                guard let date = entry.date else { continue }
                let year = calendar.component(.year, from: date)
                fuelByYear[year, default: 0] += entry.amount?.decimalValue ?? 0
            }
            for expense in vehicle.sortedExpenses {
                guard let date = expense.date else { continue }
                let year = calendar.component(.year, from: date)
                expenseByYear[year, default: 0] += expense.amount?.decimalValue ?? 0
            }
        }

        let years = Set(fuelByYear.keys).union(expenseByYear.keys)
        return years
            .map { YearlyCost(year: $0, fuel: fuelByYear[$0, default: 0], expense: expenseByYear[$0, default: 0]) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if vehicles.isEmpty {
                    ContentUnavailableView(
                        "Keine Daten",
                        systemImage: "chart.bar",
                        description: Text("Lege ein Fahrzeug an, um Statistiken zu sehen.")
                    )
                    .padding(.top, 60)
                } else {
                    GlassCard(title: "Übersicht") {
                        HStack(alignment: .top, spacing: 16) {
                            StatTile(
                                title: "Fahrzeuge",
                                value: "\(vehicles.count)",
                                systemImage: "car.2.fill"
                            )
                            Divider()
                            StatTile(
                                title: "Gesamtkosten",
                                value: DisplayFormatter.currencyString(totalCost),
                                systemImage: "sum"
                            )
                        }
                    }

                    GlassCard(title: "Kosten je Fahrzeug") {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow {
                                Text("Fahrzeug")
                                Text("Betankungen").gridColumnAlignment(.trailing)
                                Text("Sonstige").gridColumnAlignment(.trailing)
                                Text("Gesamt").gridColumnAlignment(.trailing)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Divider()

                            ForEach(vehicles) { vehicle in
                                GridRow {
                                    Text(vehicle.licensePlate ?? "")
                                    Text(DisplayFormatter.currencyString(vehicle.totalFuelCost))
                                    Text(DisplayFormatter.currencyString(vehicle.totalExpenseCost))
                                    Text(DisplayFormatter.currencyString(vehicle.totalCost))
                                        .bold()
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    GlassCard(title: "Kosten pro Jahr") {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow {
                                Text("Jahr")
                                Text("Betankungen").gridColumnAlignment(.trailing)
                                Text("Sonstige").gridColumnAlignment(.trailing)
                                Text("Gesamt").gridColumnAlignment(.trailing)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Divider()

                            ForEach(costsByYear) { item in
                                GridRow {
                                    Text(String(item.year))
                                    Text(DisplayFormatter.currencyString(item.fuel))
                                    Text(DisplayFormatter.currencyString(item.expense))
                                    Text(DisplayFormatter.currencyString(item.total))
                                        .bold()
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Statistik")
    }
}
