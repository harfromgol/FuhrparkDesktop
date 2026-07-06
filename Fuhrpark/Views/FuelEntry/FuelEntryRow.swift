import SwiftUI

/// Zeilendarstellung einer einzelnen Betankung.
struct FuelEntryRow: View {
    @ObservedObject var entry: FuelEntry

    /// Verbrauch (l/100km): vorrangig der gespeicherte Wert, sonst live berechnet.
    private var consumptionValue: Double? {
        if let stored = entry.consumption?.doubleValue {
            return stored
        }
        guard let vehicle = entry.vehicle else { return nil }
        return FuelConsumptionCalculator.automaticConsumption(
            currentOdometer: entry.odometer,
            currentLiters: entry.liters?.decimalValue ?? 0,
            previousEntryExists: entry.previousEntryExists,
            currentFullTank: entry.fullTank,
            previousEntry: vehicle.previousFuelEntry(before: entry)
        )
    }

    private var consumptionText: String {
        guard let value = consumptionValue else { return "–" }
        return "\(DisplayFormatter.string(from: Decimal(value), formatter: DisplayFormatter.consumption)) l/100km"
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
                    Text("\(DisplayFormatter.string(from: entry.liters?.decimalValue ?? 0, formatter: DisplayFormatter.decimal2)) l à \(DisplayFormatter.pricePerLiterString(entry.pricePerLiter?.decimalValue ?? 0))/l")
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
