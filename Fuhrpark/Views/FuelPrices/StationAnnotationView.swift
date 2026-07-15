import SwiftUI

/// Inhalt einer Karten-Markierung: eine Preiszeile je aktuell angehakter,
/// von der Station geführter Kraftstoffsorte.
struct StationAnnotationView: View {
    let station: GasStation
    let enabled: Set<FuelKind>

    private var visibleKinds: [FuelKind] {
        FuelKind.allCases.filter { enabled.contains($0) && $0.price(for: station) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(station.brand.isEmpty ? station.name : station.brand)
                .font(.caption2.bold())
                .lineLimit(1)

            ForEach(visibleKinds) { kind in
                if let price = kind.price(for: station) {
                    HStack(spacing: 6) {
                        Text(kind.displayName)
                        Spacer()
                        Text(DisplayFormatter.pricePerLiterString(Decimal(price)))
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}
