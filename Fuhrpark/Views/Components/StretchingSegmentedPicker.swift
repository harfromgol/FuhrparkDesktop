import SwiftUI
import AppKit

/// Segmentleiste, die die angebotene Breite ganz ausfüllt und sie gleichmäßig
/// auf ihre Segmente verteilt.
///
/// Nötig, weil `Picker(...).pickerStyle(.segmented)` das nicht kann: Die
/// SwiftUI-Leiste bleibt immer bei ihrer Idealbreite, auch mit
/// `.frame(maxWidth: .infinity)` oder einer festen `.frame(width:)` – der
/// Rahmen wird breiter, die Leiste darin nur zentriert (live geprüft). In
/// einem Formular mit mehreren Zeilen schließen unterschiedlich lange Leisten
/// deshalb rechts nicht bündig ab. Dahinter steht dasselbe AppKit-Element
/// (`NSSegmentedControl`), das auch SwiftUI verwendet, das Aussehen ist also
/// identisch.
struct StretchingSegmentedPicker<Value: Hashable>: View {
    /// Name der Leiste für Bedienungshilfen (VoiceOver); sichtbar ist er
    /// nicht, die Beschriftung steht daneben.
    let title: String
    @Binding var selection: Value
    /// Die Auswahlmöglichkeiten in Anzeigereihenfolge, jeweils Wert und
    /// Beschriftung.
    let options: [(value: Value, title: String)]

    var body: some View {
        StretchingSegmentedControl(
            titles: options.map(\.title),
            selectedIndex: Binding(
                get: { options.firstIndex { $0.value == selection } ?? 0 },
                set: { index in
                    guard options.indices.contains(index) else { return }
                    selection = options[index].value
                }
            ),
            accessibilityLabel: title
        )
    }
}

/// Die AppKit-Brücke hinter `StretchingSegmentedPicker` – bewusst ohne
/// Generics, weil der Koordinator eine `@objc`-Aktion braucht.
private struct StretchingSegmentedControl: NSViewRepresentable {
    let titles: [String]
    @Binding var selectedIndex: Int
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedIndex: $selectedIndex)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: titles,
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:))
        )
        control.segmentDistribution = .fillEqually
        control.setAccessibilityLabel(accessibilityLabel)
        control.selectedSegment = selectedIndex
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selectedIndex = $selectedIndex
        if control.selectedSegment != selectedIndex {
            control.selectedSegment = selectedIndex
        }
    }

    /// Nimmt die angebotene Breite an, unterschreitet aber nie die Breite,
    /// die die Beschriftungen brauchen. Ohne konkretes Angebot (SwiftUI fragt
    /// beim Ausmessen auch nach der Ideal- und der Maximalgröße) gilt die
    /// natürliche Breite.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        let fitting = nsView.fittingSize
        guard let proposedWidth = proposal.width, proposedWidth.isFinite else {
            return fitting
        }
        return CGSize(width: max(proposedWidth, fitting.width), height: fitting.height)
    }

    @MainActor
    final class Coordinator: NSObject {
        var selectedIndex: Binding<Int>

        init(selectedIndex: Binding<Int>) {
            self.selectedIndex = selectedIndex
        }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            selectedIndex.wrappedValue = sender.selectedSegment
        }
    }
}
