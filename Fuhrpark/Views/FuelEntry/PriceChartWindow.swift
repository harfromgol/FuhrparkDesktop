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

    @State private var hoveredPoint: FuelPricePoint?

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
                    description: Text("Für eine Verlaufsdarstellung sind mindestens zwei \(vehicleRef.engineType.refuelNounPlural) nötig.")
                )
            } else {
                Chart {
                    ForEach(points) { point in
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
                    if let hoveredPoint {
                        PointMark(
                            x: .value("Datum", hoveredPoint.date),
                            y: .value("Preis", hoveredPoint.price)
                        )
                        .symbolSize(150)
                        .foregroundStyle(Color.accentColor)
                        .annotation(position: .top) {
                            VStack(spacing: 2) {
                                Text(FieldValidator.string(from: hoveredPoint.date))
                                Text(priceLabel(hoveredPoint.price))
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .chartYScale(domain: yDomain)
                // Fester Rand links/rechts der Zeitachse, unabhängig vom Inhalt –
                // sonst verschiebt sich die Achse (und mit ihr die äußeren
                // Datenpunkte), sobald der Hover-Tooltip am Rand mehr Platz
                // braucht, als gerade da ist.
                .chartXScale(range: .plotDimension(padding: 40))
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
                .chartDateHover(points: points, date: \.date, hovered: $hoveredPoint)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 340)
        .navigationTitle("\(vehicleRef.engineType.priceTitle)-Verlauf – \(vehicleRef.licensePlate)")
    }

    private func priceLabel(_ price: Double) -> String {
        let value = DisplayFormatter.pricePerLiter.string(from: NSNumber(value: price)) ?? "\(price)"
        return value + vehicleRef.engineType.pricePerUnitSuffix
    }
}
