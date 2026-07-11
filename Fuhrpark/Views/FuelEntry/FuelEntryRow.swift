import SwiftUI

/// Zeilendarstellung einer einzelnen Betankung.
struct FuelEntryRow: View {
    @ObservedObject var entry: FuelEntry

    private var engineType: EngineType {
        entry.vehicle?.engineType ?? .combustion
    }

    /// Verbrauch: vorrangig der gespeicherte Wert, sonst live berechnet.
    private var consumptionValue: Double? {
        entry.vehicle?.effectiveConsumption(for: entry)
    }

    private var consumptionText: String {
        guard let value = consumptionValue else { return "–" }
        return "\(DisplayFormatter.string(from: Decimal(value), formatter: DisplayFormatter.consumption)) \(engineType.consumptionUnit)"
    }

    var body: some View {
        GlassCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(FieldValidator.string(from: entry.date ?? Date()))
                        .font(.subheadline.bold())
                    Text("\(entry.station ?? "") · \(entry.odometer) km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(DisplayFormatter.string(from: entry.liters?.decimalValue ?? 0, formatter: DisplayFormatter.decimal2)) \(engineType.energyUnit) à \(DisplayFormatter.pricePerLiterString(entry.pricePerLiter?.decimalValue ?? 0))\(engineType.pricePerUnitSuffix)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(DisplayFormatter.currencyString(entry.amount?.decimalValue ?? 0))
                        .font(.subheadline.bold())
                    Text("Verbrauch: \(consumptionText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
