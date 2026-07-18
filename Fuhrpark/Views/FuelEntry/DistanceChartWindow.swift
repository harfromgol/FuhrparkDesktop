import SwiftUI
import CoreData
import Charts

/// Ein Datenpunkt des Kilometer-Verlaufs (Jahr und gefahrene Kilometer).
private struct DistancePoint: Identifiable {
    let id: Int
    let year: Int
    let kilometers: Int32
}

/// Eigenständiges Fenster mit den gefahrenen Kilometern pro Jahr eines
/// Fahrzeugs: X-Achse Jahr, Y-Achse km, als Balkendiagramm (im Gegensatz zu
/// Verbrauchs-/Spritpreis-Verlauf sind die Werte bereits pro Kalenderjahr
/// gebündelt, siehe `Vehicle.kilometersByYear`).
struct DistanceChartWindow: View {
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

    private var points: [DistancePoint] {
        guard let vehicle = vehicles.first else { return [] }
        return vehicle.kilometersByYear
            .sorted { $0.year < $1.year }
            .map { DistancePoint(id: $0.year, year: $0.year, kilometers: $0.kilometers) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if points.count < 2 {
                ContentUnavailableView(
                    "Zu wenige Daten",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Für eine Verlaufsdarstellung sind mindestens zwei Jahre mit gefahrenen Kilometern nötig.")
                )
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Jahr", String(point.year)),
                        y: .value("km", point.kilometers)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYAxisLabel("km")
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 340)
        .navigationTitle("Gefahrene km pro Jahr – \(vehicleRef.licensePlate)")
    }
}
