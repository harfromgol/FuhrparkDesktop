import SwiftUI
import CoreData
import Charts

/// Ein Tortenstück des Kategorie-Donut-Charts (Kategoriename und Betrag).
private struct CategorySlice: Identifiable {
    let id: String
    let category: String
    let total: Double
}

/// Eigenständiges Fenster mit den Gesamtkosten pro Kategorie eines Fahrzeugs
/// als Donut-Chart (Swift Charts `SectorMark` mit `innerRadius`).
struct CategoryChartWindow: View {
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

    /// Negative oder Null-Beträge (z. B. eine Kategorie mit mehr Einnahmen als
    /// Ausgaben) lassen sich in einem Donut-Chart nicht sinnvoll darstellen
    /// und werden daher ausgeblendet.
    private var slices: [CategorySlice] {
        guard let vehicle = vehicles.first else { return [] }
        return vehicle.expenseCostByCategory
            .filter { $0.total > 0 }
            .map { CategorySlice(id: $0.category, category: $0.category, total: NSDecimalNumber(decimal: $0.total).doubleValue) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if slices.count < 2 {
                ContentUnavailableView(
                    "Zu wenige Daten",
                    systemImage: "chart.pie",
                    description: Text("Für ein Kreisdiagramm sind mindestens zwei Kategorien mit Kosten nötig.")
                )
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Betrag", slice.total),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(by: .value("Kategorie", slice.category))
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 420)
        .navigationTitle("Gesamtkosten pro Kategorie – \(vehicleRef.licensePlate)")
    }
}
