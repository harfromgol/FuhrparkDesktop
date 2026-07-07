import SwiftUI

struct FuelEntryFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    @State private var dateText = FieldValidator.string(from: Date())
    @State private var odometerText = ""
    @State private var station = ""
    @State private var priceText = ""
    @State private var litersText = ""
    @State private var manualConsumptionText = ""

    @State private var manualConsumption = false
    @State private var previousEntryExists = true
    @State private var fullTank = true

    @State private var dateValid = false
    @State private var odometerValid = false
    @State private var stationValid = false
    @State private var priceValid = false
    @State private var litersValid = false
    @State private var manualConsumptionValid = false

    private var previousEntry: FuelEntry? {
        vehicle.previousFuelEntry(before: nil)
    }

    private var minimumOdometer: Int32 {
        max(vehicle.odometer, vehicle.sortedFuelEntries.map(\.odometer).max() ?? 0)
    }

    private var computedConsumption: Double? {
        guard let currentOdometer = FieldValidator.intValue(odometerText),
              let liters = FieldValidator.decimalValue(litersText) else { return nil }
        return FuelConsumptionCalculator.automaticConsumption(
            currentOdometer: currentOdometer,
            currentLiters: liters,
            previousEntryExists: previousEntryExists,
            currentFullTank: fullTank,
            previousEntry: previousEntry
        )
    }

    private var computedAmount: Decimal? {
        guard priceValid, litersValid,
              let price = FieldValidator.decimalValue(priceText),
              let liters = FieldValidator.decimalValue(litersText) else { return nil }
        var result = price * liters
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 2, .plain)
        return rounded
    }

    private var isFormValid: Bool {
        let baseValid = dateValid && odometerValid && stationValid && priceValid && litersValid && computedAmount != nil
        guard baseValid else { return false }
        return manualConsumption ? manualConsumptionValid : true
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard(title: "Fahrzeug") {
                        Text(vehicle.licensePlate ?? "")
                            .font(.title3.bold())
                        Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    GlassCard(title: "Betankung") {
                        DateValidatedField(title: "Datum", text: $dateText, isValidBinding: $dateValid)
                        ValidatedField(
                            title: "Kilometerstand",
                            text: $odometerText,
                            kind: .integer(minDigits: 1, maxDigits: 8),
                            isValidBinding: $odometerValid,
                            extraValidation: { text in
                                guard let value = FieldValidator.intValue(text) else { return false }
                                return value > minimumOdometer
                            },
                            extraErrorMessage: "Muss größer als \(minimumOdometer) km sein"
                        )
                        ValidatedField(
                            title: "Tankstelle",
                            text: $station,
                            kind: .text(min: 1, max: 30),
                            isValidBinding: $stationValid
                        )
                        ValidatedField(
                            title: "Preis pro Liter (€)",
                            text: $priceText,
                            kind: .decimal(fractionDigits: 3, minLength: 5, maxLength: 6),
                            isValidBinding: $priceValid
                        )
                        ValidatedField(
                            title: "Menge (Liter)",
                            text: $litersText,
                            kind: .decimal(fractionDigits: 2, minLength: 4, maxLength: 5),
                            isValidBinding: $litersValid
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Betrag (€)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                if let computedAmount {
                                    Text(DisplayFormatter.currencyString(computedAmount))
                                        .bold()
                                } else {
                                    Text("wird berechnet …")
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    GlassCard(title: "Optionen") {
                        Toggle("Vorherige Betankung eingetragen?", isOn: $previousEntryExists)
                        Toggle("Vollgetankt?", isOn: $fullTank)
                        Toggle("Verbrauch manuell eintragen?", isOn: $manualConsumption)

                        if manualConsumption {
                            ValidatedField(
                                title: "Verbrauch (l/100km)",
                                text: $manualConsumptionText,
                                kind: .decimal(fractionDigits: 2, minLength: 4, maxLength: 6),
                                isValidBinding: $manualConsumptionValid
                            )
                        } else {
                            HStack {
                                Text("Berechneter Verbrauch")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let computedConsumption {
                                    Text("\(DisplayFormatter.string(from: Decimal(computedConsumption), formatter: DisplayFormatter.consumption)) l/100km")
                                        .bold()
                                } else {
                                    Text("nicht berechenbar")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Abbrechen", role: .cancel) { dismiss() }
                Spacer()
                Button("Speichern") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(!isFormValid)
            }
            .padding(16)
        }
        .frame(width: 460, height: 660)
    }

    private func save() {
        let entry = FuelEntry(context: viewContext)
        entry.id = UUID()
        entry.date = FieldValidator.dateValue(dateText) ?? Date()
        entry.odometer = FieldValidator.intValue(odometerText) ?? 0
        entry.station = station
        entry.pricePerLiter = NSDecimalNumber(decimal: FieldValidator.decimalValue(priceText) ?? 0)
        entry.liters = NSDecimalNumber(decimal: FieldValidator.decimalValue(litersText) ?? 0)
        entry.amount = NSDecimalNumber(decimal: computedAmount ?? 0)
        entry.manualConsumption = manualConsumption
        entry.previousEntryExists = previousEntryExists
        entry.fullTank = fullTank
        entry.vehicle = vehicle

        if manualConsumption {
            if let value = FieldValidator.decimalValue(manualConsumptionText) {
                entry.consumption = NSDecimalNumber(decimal: value)
            }
        } else if let computedConsumption {
            entry.consumption = NSNumber(value: computedConsumption)
        }

        vehicle.touch()
        PersistenceController.shared.save(context: viewContext)
        dismiss()
    }
}
