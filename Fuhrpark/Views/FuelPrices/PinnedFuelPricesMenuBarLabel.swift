import SwiftUI

/// Inhalt des Menüleisten-Icons selbst (nicht das Popover dahinter). Bei
/// genau einer angepinnten Kombination steht der Preis direkt neben dem
/// Icon in der Menüleiste – bei mehreren wäre nicht erkennbar, welcher
/// Preis gemeint ist, dort bleibt es beim reinen Icon.
struct PinnedFuelPricesMenuBarLabel: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    /// `nil` bei keiner oder mehreren Anpinnungen. Bei genau einer immer ein
    /// Text (notfalls „–"), damit das Icon nicht flackernd zwischen Icon-only
    /// und Icon+Preis wechselt, während der erste Preis noch lädt.
    private var singleSelectionPriceText: String? {
        guard vm.pinnedSelections.count == 1, let selection = vm.pinnedSelections.first else { return nil }
        guard let price = vm.snapshots[selection.id]?.price else { return "–" }
        return DisplayFormatter.pricePerLiterString(Decimal(price))
    }

    var body: some View {
        Group {
            if let singleSelectionPriceText {
                Label(singleSelectionPriceText, systemImage: "fuelpump.fill")
                    .labelStyle(.titleAndIcon)
            } else {
                Image(systemName: "fuelpump.fill")
            }
        }
        .accessibilityLabel("Spritpreise")
    }
}
