import SwiftUI
import CoreData
import Charts

/// Ein Segment eines gestapelten Balkens (Jahr, Art und Betrag).
private struct YearlyCostSegment: Identifiable {
    let id: String
    let year: Int
    /// Reihenfolge im Array bestimmt die Stapel-Reihenfolge: "Sonstige"
    /// zuerst (unten), "Betankungen" danach (oben) – siehe `segments`.
    let kind: String
    let amount: Double
}

/// Eigenständiges Fenster mit den Kosten pro Jahr eines Fahrzeugs als
/// gestapeltes Balkendiagramm: je Jahr ein Balken, unten der Anteil
/// "Sonstige", darüber "Betankungen" (Swift Charts stapelt BarMarks mit
/// gleichem X-Wert automatisch in Plot-Reihenfolge).
struct YearlyCostChartWindow: View {
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

    private var segments: [YearlyCostSegment] {
        guard let vehicle = vehicles.first else { return [] }
        return vehicle.costsByYear
            .sorted { $0.year < $1.year }
            .flatMap { item -> [YearlyCostSegment] in
                [
                    YearlyCostSegment(
                        id: "\(item.year)-sonstige",
                        year: item.year,
                        kind: "Sonstige",
                        amount: NSDecimalNumber(decimal: item.expense).doubleValue
                    ),
                    YearlyCostSegment(
                        id: "\(item.year)-betankungen",
                        year: item.year,
                        kind: "Betankungen",
                        amount: NSDecimalNumber(decimal: item.fuel).doubleValue
                    )
                ]
            }
    }

    private var years: Set<Int> { Set(segments.map(\.year)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if years.count < 2 {
                ContentUnavailableView(
                    "Zu wenige Daten",
                    systemImage: "chart.bar",
                    description: Text("Für eine Verlaufsdarstellung sind mindestens zwei Jahre mit Kosten nötig.")
                )
            } else {
                Chart(segments) { segment in
                    BarMark(
                        x: .value("Jahr", String(segment.year)),
                        y: .value("Betrag", segment.amount)
                    )
                    .foregroundStyle(by: .value("Art", segment.kind))
                }
                .chartYAxisLabel("€")
                .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 340)
        .navigationTitle("Kosten pro Jahr – \(vehicleRef.licensePlate)")
    }
}
