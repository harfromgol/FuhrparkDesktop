import SwiftUI
import CoreData
import Charts

/// Ein Datenpunkt des Spritpreis-Verlaufs (Datum und Preis pro Liter).
private struct FuelPricePoint: Identifiable {
    let id: UUID
    let date: Date
    let price: Double
}

/// Eigenständiges Fenster mit dem grafischen Spritpreis-Verlauf eines Fahrzeugs:
/// X-Achse Datum, Y-Achse Preis pro Liter, als Linie mit Punkten.
struct PriceChartWindow: View {
    let vehicleRef: VehicleRef

    @FetchRequest private var entries: FetchedResults<FuelEntry>

    init(vehicleRef: VehicleRef) {
        self.vehicleRef = vehicleRef
        _entries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.date, ascending: true)],
            predicate: NSPredicate(format: "vehicle.id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
    }

    private var points: [FuelPricePoint] {
        entries.compactMap { entry in
            guard let date = entry.date, let price = entry.pricePerLiter?.decimalValue else { return nil }
            return FuelPricePoint(
                id: entry.id ?? UUID(),
                date: date,
                price: NSDecimalNumber(decimal: price).doubleValue
            )
        }
    }

    /// Y-Achsen-Bereich eng um die Datenwerte (statt bei 0 zu beginnen), damit
    /// der Preisverlauf gut sichtbar ist.
    private var yDomain: ClosedRange<Double> {
        let prices = points.map(\.price)
        guard let lo = prices.min(), let hi = prices.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.2, 0.05)
        return max(lo - pad, 0)...(hi + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if points.count < 2 {
                ContentUnavailableView(
                    "Zu wenige Daten",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Für eine Verlaufsdarstellung sind mindestens zwei Betankungen nötig.")
                )
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value("Preis", point.price)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(Color.accentColor)

                    PointMark(
                        x: .value("Datum", point.date),
                        y: .value("Preis", point.price)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let price = value.as(Double.self) {
                                Text(priceLabel(price))
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 340)
        .navigationTitle("Spritpreis-Verlauf – \(vehicleRef.licensePlate)")
    }

    private func priceLabel(_ price: Double) -> String {
        DisplayFormatter.pricePerLiter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
}
