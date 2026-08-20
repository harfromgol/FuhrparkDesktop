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

    @State private var hoveredYear: Int?
    @State private var hoverLocation: CGPoint = .zero

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
                    .opacity(hoveredYear == nil || hoveredYear == point.year ? 1 : 0.35)
                }
                .chartYAxisLabel("km")
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        hoverLocation = location
                                        guard let anchor = proxy.plotFrame else {
                                            hoveredYear = nil
                                            return
                                        }
                                        let plotFrame = geometry[anchor]
                                        let x = location.x - plotFrame.origin.x
                                        let y = location.y - plotFrame.origin.y
                                        guard x >= 0, x <= plotFrame.width,
                                              let yearString: String = proxy.value(atX: x),
                                              let year = Int(yearString),
                                              let point = points.first(where: { $0.year == year }),
                                              let value: Double = proxy.value(atY: y) else {
                                            hoveredYear = nil
                                            return
                                        }
                                        let barValue = Double(point.kilometers)
                                        let withinBar = barValue >= 0
                                            ? (value >= 0 && value <= barValue)
                                            : (value <= 0 && value >= barValue)
                                        hoveredYear = withinBar ? year : nil
                                    case .ended:
                                        hoveredYear = nil
                                    }
                                }
                            if let hoveredYear, let point = points.first(where: { $0.year == hoveredYear }) {
                                VStack(spacing: 2) {
                                    Text(String(hoveredYear))
                                    Text("\(DisplayFormatter.odometerString(point.kilometers)) km")
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .fixedSize()
                                .position(clampedTooltipPosition(in: geometry.size))
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 340)
        .navigationTitle("Gefahrene km pro Jahr – \(vehicleRef.licensePlate)")
    }

    /// Tooltip-Position, an den Mauszeiger gebunden statt an einen festen
    /// Balken – verschiebt beim Hover nie das Diagramm selbst (nur die
    /// Opazität ändert sich), und bleibt innerhalb der Fenstergrenzen.
    private func clampedTooltipPosition(in size: CGSize) -> CGPoint {
        let halfWidth: CGFloat = 60
        let x = min(max(hoverLocation.x, halfWidth), size.width - halfWidth)
        let y = max(hoverLocation.y - 28, 20)
        return CGPoint(x: x, y: y)
    }
}
