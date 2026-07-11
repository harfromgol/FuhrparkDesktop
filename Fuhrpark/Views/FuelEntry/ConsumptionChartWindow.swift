import SwiftUI
import CoreData
import Charts

/// Ein Datenpunkt des Verbrauchsverlaufs (Datum und Verbrauch in l/100km).
private struct ConsumptionPoint: Identifiable {
    let id: Int
    let date: Date
    let consumption: Double
}

/// Eigenständiges Fenster mit dem grafischen Verbrauchsverlauf eines Fahrzeugs:
/// X-Achse Datum, Y-Achse Verbrauch (l/100km), als Linie mit Punkten.
struct ConsumptionChartWindow: View {
    let vehicleRef: VehicleRef

    @FetchRequest private var vehicles: FetchedResults<Vehicle>

    init(vehicleRef: VehicleRef) {
        self.vehicleRef = vehicleRef
        _vehicles = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.id, ascending: true)],
            predicate: NSPredicate(format: "id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
    }

    private var points: [ConsumptionPoint] {
        guard let vehicle = vehicles.first else { return [] }
        return vehicle.consumptionHistory.enumerated().map { index, item in
            ConsumptionPoint(id: index, date: item.date, consumption: item.consumption)
        }
    }

    /// Y-Achsen-Bereich eng um die Datenwerte (statt bei 0 zu beginnen), damit
    /// der Verbrauchsverlauf gut sichtbar ist.
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.consumption)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.2, 0.2)
        return max(lo - pad, 0)...(hi + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if points.count < 2 {
                ContentUnavailableView(
                    "Zu wenige Daten",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Für eine Verlaufsdarstellung sind mindestens zwei Verbrauchswerte nötig.")
                )
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value("Verbrauch", point.consumption)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(Color.accentColor)

                    PointMark(
                        x: .value("Datum", point.date),
                        y: .value("Verbrauch", point.consumption)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYScale(domain: yDomain)
                .chartYAxisLabel(vehicleRef.engineType.consumptionUnit)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let consumption = value.as(Double.self) {
                                Text(consumptionLabel(consumption))
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 340)
        .navigationTitle("Verbrauch-Verlauf – \(vehicleRef.licensePlate)")
    }

    private func consumptionLabel(_ value: Double) -> String {
        DisplayFormatter.string(from: Decimal(value), formatter: DisplayFormatter.consumption)
    }
}
