import SwiftUI

/// Eine Tankstelle im Listen-Fenster: Stammdaten plus eine Checkbox mit
/// Preis je Sorte, die die Station führt.
struct GasStationPriceRow: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    let station: GasStation

    private var availableKinds: [FuelKind] {
        FuelKind.allCases.filter { $0.price(for: station) != nil }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.brand.isEmpty ? station.name : station.brand)
                        .font(.subheadline.bold())
                    Text("\(station.street) \(station.houseNumber), \(station.place)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(availableKinds) { kind in
                    if let price = kind.price(for: station) {
                        Toggle(isOn: Binding(
                            get: { vm.isPinned(stationId: station.id, fuelKind: kind) },
                            set: { isOn in
                                if isOn {
                                    vm.pin(station, fuelKind: kind)
                                } else {
                                    vm.unpin(PinnedFuelSelection(station: station, fuelKind: kind).id)
                                }
                            }
                        )) {
                            HStack {
                                Text(kind.displayName)
                                Spacer()
                                Text(DisplayFormatter.pricePerLiterString(Decimal(price)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }
}
