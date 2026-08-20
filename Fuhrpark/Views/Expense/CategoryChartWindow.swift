import SwiftUI
import CoreData
import Charts

/// Ein Tortenstück des Kategorie-Donut-Charts (Kategoriename und Betrag).
private struct CategorySlice: Identifiable {
    let id: String
    let category: String
    let total: Double
    let totalDecimal: Decimal
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

    @State private var hoveredSlice: CategorySlice?
    @State private var hoverLocation: CGPoint = .zero

    /// Negative oder Null-Beträge (z. B. eine Kategorie mit mehr Einnahmen als
    /// Ausgaben) lassen sich in einem Donut-Chart nicht sinnvoll darstellen
    /// und werden daher ausgeblendet.
    private var slices: [CategorySlice] {
        guard let vehicle = vehicles.first else { return [] }
        return vehicle.expenseCostByCategory
            .filter { $0.total > 0 }
            .map { CategorySlice(
                id: $0.category,
                category: $0.category,
                total: NSDecimalNumber(decimal: $0.total).doubleValue,
                totalDecimal: $0.total
            ) }
    }

    /// Summe aller dargestellten Kategorien – Grundlage des Anteils im
    /// Hover-Tooltip. Bewusst die Summe der sichtbaren Tortenstücke (nicht
    /// `vehicle.totalCost`, das auch Betankungen einschließt), damit der
    /// angezeigte Anteil zum Sektorwinkel passt, den man gerade sieht.
    private var slicesTotal: Double {
        slices.reduce(0) { $0 + $1.total }
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
                    .opacity(hoveredSlice == nil || hoveredSlice?.id == slice.id ? 1 : 0.35)
                }
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
                                            hoveredSlice = nil
                                            return
                                        }
                                        hoveredSlice = slice(at: location, plotFrame: geometry[anchor])
                                    case .ended:
                                        hoveredSlice = nil
                                    }
                                }
                            if let hoveredSlice {
                                VStack(spacing: 2) {
                                    Text(DisplayFormatter.costString(hoveredSlice.totalDecimal))
                                    Text(percentLabel(hoveredSlice))
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
        .frame(minWidth: 480, minHeight: 420)
        .navigationTitle("Gesamtkosten pro Kategorie – \(vehicleRef.licensePlate)")
    }

    private func percentLabel(_ slice: CategorySlice) -> String {
        guard slicesTotal > 0 else { return "–" }
        return DisplayFormatter.percentString(Decimal(slice.total / slicesTotal))
    }

    /// Ermittelt das Tortenstück unter der Mausposition: Abstand vom
    /// Kreismittelpunkt muss zwischen Innen- und Außenradius liegen, der
    /// Winkel (im Uhrzeigersinn ab 12 Uhr, wie `SectorMark` zeichnet)
    /// bestimmt, welche Kategorie an der Reihe ist.
    private func slice(at location: CGPoint, plotFrame: CGRect) -> CategorySlice? {
        guard plotFrame != .zero else { return nil }
        let center = CGPoint(x: plotFrame.midX, y: plotFrame.midY)
        let radius = min(plotFrame.width, plotFrame.height) / 2
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance <= radius, distance >= radius * 0.6 else { return nil }

        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let fraction = angle / (2 * .pi)

        let total = slicesTotal
        guard total > 0 else { return nil }
        var cumulative = 0.0
        for slice in slices {
            let sliceFraction = slice.total / total
            if fraction < cumulative + sliceFraction {
                return slice
            }
            cumulative += sliceFraction
        }
        return slices.last
    }

    /// Tooltip-Position, an den Mauszeiger gebunden statt an einen festen
    /// Datenpunkt (bei einem Donut wird eine Fläche gehovert, kein
    /// einzelner Punkt) – dadurch verschiebt sich nie etwas am Diagramm
    /// selbst, nur der Tooltip folgt der Maus. Innerhalb der Fenstergrenzen
    /// gehalten, damit er am Rand nicht abgeschnitten wird.
    private func clampedTooltipPosition(in size: CGSize) -> CGPoint {
        let halfWidth: CGFloat = 70
        let x = min(max(hoverLocation.x, halfWidth), size.width - halfWidth)
        let y = max(hoverLocation.y - 28, 20)
        return CGPoint(x: x, y: y)
    }
}
