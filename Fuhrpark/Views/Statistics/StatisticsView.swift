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

                            Divider()

                            GridRow {
                                Text("Gesamt")
                                Text(DisplayFormatter.currencyString(totalFuelCost))
                                Text(DisplayFormatter.currencyString(totalExpenseCost))
                                Text(DisplayFormatter.currencyString(totalCost))
                            }
                            .font(.subheadline.bold())
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Statistik")
    }
}
