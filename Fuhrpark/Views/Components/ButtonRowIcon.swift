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
