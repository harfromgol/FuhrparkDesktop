import SwiftUI
import AppKit

/// Aufklappmenü, das die angebotene Breite ganz ausfüllt – das Gegenstück zu
/// `StretchingSegmentedPicker` für `Picker(...).pickerStyle(.menu)`.
///
/// Auch das SwiftUI-Menü bleibt immer so schmal wie sein gerade gewählter
/// Eintrag, `.frame(maxWidth: .infinity)` verbreitert nur den Rahmen darum
/// (live geprüft). In einem Formular, dessen übrige Auswahlen bis zum rechten
/// Rand reichen, stünde es sonst als einziges kurz da. Dahinter steht
/// dasselbe AppKit-Element (`NSPopUpButton`), das auch SwiftUI verwendet.
struct StretchingMenuPicker<Value: Hashable>: View {
    /// Name des Menüs für Bedienungshilfen (VoiceOver); sichtbar ist er
    /// nicht, die Beschriftung steht daneben.
    let title: String
    @Binding var selection: Value
    /// Die Auswahlmöglichkeiten in Anzeigereihenfolge, jeweils Wert und
    /// Beschriftung.
    let options: [(value: Value, title: String)]

    var body: some View {
        StretchingPopUpButton(
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

/// Die AppKit-Brücke hinter `StretchingMenuPicker` – bewusst ohne Generics,
/// weil der Koordinator eine `@objc`-Aktion braucht.
private struct StretchingPopUpButton: NSViewRepresentable {
    let titles: [String]
    @Binding var selectedIndex: Int
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedIndex: $selectedIndex)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        button.setAccessibilityLabel(accessibilityLabel)
        populate(button)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.selectedIndex = $selectedIndex
        if button.itemTitles != titles {
            populate(button)
        } else if button.indexOfSelectedItem != selectedIndex {
            button.selectItem(at: selectedIndex)
        }
    }

    /// Baut die Einträge neu auf. Über das Menü statt über
    /// `addItems(withTitles:)`, weil letzteres gleichlautende Einträge
    /// stillschweigend zusammenlegt und die Indizes dann nicht mehr zu
    /// `titles` passten.
    private func populate(_ button: NSPopUpButton) {
        button.removeAllItems()
        for title in titles {
            button.menu?.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
        }
        button.selectItem(at: selectedIndex)
    }

    /// Nimmt die angebotene Breite an, unterschreitet aber nie die Breite,
    /// die der längste Eintrag braucht. Ohne konkretes Angebot (SwiftUI fragt
    /// beim Ausmessen auch nach der Ideal- und der Maximalgröße) gilt die
    /// natürliche Breite.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
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

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            selectedIndex.wrappedValue = sender.indexOfSelectedItem
        }
    }
}
