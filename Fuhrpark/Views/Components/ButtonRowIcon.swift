import SwiftUI

extension View {
    /// Größe für die reinen Symbol-Buttons (Filter, Zahnrad) in der Kopfzeile
    /// der Übersichtsfenster, in der rechts der Button „Neue …“ steht.
    ///
    /// Das Symbol ist so hoch wie dieser Button (25 pt, live gemessen). In
    /// der Standardgröße war es mit 13 pt nur halb so hoch und wirkte neben
    /// dem Button verloren.
    func buttonRowIcon() -> some View {
        font(.system(size: 25))
    }
}

/// Das Filter-Symbol der Kopfzeile: Ohne gesetzten Filter ein leerer Kreis in
/// der üblichen gedämpften Symbolfarbe, mit gesetztem Filter ausgefüllt und
/// violett – so ist auf einen Blick zu sehen, dass die Liste eingeschränkt
/// ist.
struct FilterButtonIcon: View {
    let isActive: Bool

    /// Echtes Violett (Farbton 270°). Das System-`.purple` liegt bei etwa
    /// 290° und wirkt eher magenta. Zum Anpassen genügt es, diesen Wert zu
    /// ändern.
    private static let activeColor = Color(hue: 0.75, saturation: 0.6, brightness: 0.95)

    var body: some View {
        Image(systemName: isActive
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle")
            .buttonRowIcon()
            // `.secondary` ist die Farbe, die ein Symbol-Button ohnehin hat
            // (live nachgemessen); so bleibt der Normalzustand unverändert.
            .foregroundStyle(isActive ? Self.activeColor : Color.secondary)
    }
}
