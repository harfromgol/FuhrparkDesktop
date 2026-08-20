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

    @State private var hoveredSegment: YearlyCostSegment?
    @State private var hoverLocation: CGPoint = .zero

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
                    .opacity(hoveredSegment == nil || hoveredSegment?.id == segment.id ? 1 : 0.35)
                }
                .chartYAxisLabel("€")
                .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
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
                                            hoveredSegment = nil
                                            return
                                        }
                                        let plotFrame = geometry[anchor]
                                        let x = location.x - plotFrame.origin.x
                                        let y = location.y - plotFrame.origin.y
                                        guard x >= 0, x <= plotFrame.width,
                                              let yearString: String = proxy.value(atX: x),
                                              let year = Int(yearString),
                                              let value: Double = proxy.value(atY: y) else {
                                            hoveredSegment = nil
                                            return
                                        }
                                        hoveredSegment = segment(forYear: year, value: value)
                                    case .ended:
                                        hoveredSegment = nil
                                    }
                                }
                            if let hoveredSegment {
                                VStack(spacing: 2) {
                                    Text(String(hoveredSegment.year))
                                    Text(DisplayFormatter.costString(Decimal(hoveredSegment.amount)))
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
        .navigationTitle("Kosten pro Jahr – \(vehicleRef.licensePlate)")
    }

    /// Ermittelt das gestapelte Segment unter der Mausposition: `value` ist
    /// der Y-Achsenwert (0 = Balkenboden), die Segmente eines Jahres werden
    /// in Stapel-Reihenfolge (Sonstige zuerst/unten) kumuliert durchsucht.
    private func segment(forYear year: Int, value: Double) -> YearlyCostSegment? {
        guard value >= 0 else { return nil }
        var cumulative = 0.0
        for segment in segments where segment.year == year {
            cumulative += segment.amount
            if value <= cumulative {
                return segment
            }
        }
        return nil
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
