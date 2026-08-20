import Charts
import SwiftUI

/// Erkennt für ein `Chart` mit datumsbasierter X-Achse per Mausbewegung den
/// nächstgelegenen Datenpunkt und meldet ihn über `hovered`.
///
/// Bewusst über `.onContinuousHover` statt `chartXSelection(value:)`, da
/// Letzteres an eine Zieh-/Tippgeste gebunden ist – auf dem Mac soll aber
/// reine Mausbewegung ohne Klicken genügen.
struct ChartDateHoverModifier<Point>: ViewModifier {
    let points: [Point]
    let date: (Point) -> Date
    @Binding var hovered: Point?

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            guard let anchor = proxy.plotFrame else {
                                hovered = nil
                                return
                            }
                            let plotFrame = geometry[anchor]
                            let x = location.x - plotFrame.origin.x
                            guard x >= 0, x <= plotFrame.width,
                                  let hoveredDate: Date = proxy.value(atX: x) else {
                                hovered = nil
                                return
                            }
                            hovered = points.min {
                                abs(date($0).timeIntervalSince(hoveredDate))
                                    < abs(date($1).timeIntervalSince(hoveredDate))
                            }
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
    }
}

extension View {
    func chartDateHover<Point>(
        points: [Point],
        date: @escaping (Point) -> Date,
        hovered: Binding<Point?>
    ) -> some View {
        modifier(ChartDateHoverModifier(points: points, date: date, hovered: hovered))
    }
}
