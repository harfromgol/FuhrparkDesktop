import SwiftUI

/// Anlegen einer Betankung (kein Bearbeiten – `FuelEntryListWindow`s
/// Kontextmenü bietet dafür nur „Löschen“ an). Meist mit fest vorgegebenem
/// Fahrzeug aus der Fahrzeugdetail-Ansicht geöffnet; ohne Fahrzeug (Aufruf
/// aus der fahrzeugübergreifenden `FuelEntriesView`) zeigt die
/// „Fahrzeug“-Karte stattdessen einen `VehiclePicker“ – analog zu
/// `NoteFormView`/`ReminderFormView`. Die übrigen Felder hängen über die
/// Kraftstoffart von `selectedVehicle` ab (Beschriftungen, minimaler
/// km-Stand, bekannte Tankstellen) und erscheinen deshalb erst, sobald ein
/// Fahrzeug gewählt ist.
struct FuelEntryFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    /// Wenn gesetzt (Aufruf aus der Fahrzeugdetail-Ansicht), ist das Fahrzeug
    /// fest vorgegeben und wird statt der Auswahl nur noch angezeigt.
    let fixedVehicle: Vehicle?

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var selectedVehicle: Vehicle?

    private var engineType: EngineType { selectedVehicle?.engineType ?? .combustion }

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

    init(vehicle: Vehicle? = nil) {
        self.fixedVehicle = vehicle
        _selectedVehicle = State(initialValue: vehicle)
    }

    private var previousEntry: FuelEntry? {
        selectedVehicle?.previousFuelEntry(before: nil)
    }

    private var minimumOdometer: Int32 {
        guard let selectedVehicle else { return 0 }
        return max(selectedVehicle.odometer, selectedVehicle.sortedFuelEntries.map(\.odometer).max() ?? 0)
    }

    /// Bereits erfasste Tankstellen des gewählten Fahrzeugs (distinct,
    /// case-insensitiv, alphabetisch) als Vorschläge für die
    /// Autovervollständigung.
    private var knownStations: [String] {
        guard let selectedVehicle else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for entry in selectedVehicle.sortedFuelEntries {
            let name = (entry.station ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            result.append(name)
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
        guard selectedVehicle != nil else { return false }
        let baseValid = dateValid && odometerValid && stationValid && priceValid && litersValid && computedAmount != nil
        guard baseValid else { return false }
        return manualConsumption ? manualConsumptionValid : true
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GlassEffectContainer {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard(title: "Fahrzeug") {
                        if let fixedVehicle {
                            Text(fixedVehicle.licensePlate ?? "")
                                .font(.title3.bold())
                            Text("\(fixedVehicle.manufacturer ?? "") \(fixedVehicle.model ?? "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VehiclePicker(vehicles: Array(vehicles), selection: $selectedVehicle)
                        }
                    }

                    if selectedVehicle != nil {
                    GlassCard(title: engineType.refuelNoun) {
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
                        SuggestingField(
                            title: engineType.stationLabel,
                            text: $station,
                            isValidBinding: $stationValid,
                            suggestions: knownStations
                        )
                        ValidatedField(
                            title: engineType.pricePerUnitFieldLabel,
                            text: $priceText,
                            kind: .decimal(fractionDigits: 3, minLength: 5, maxLength: 6),
                            isValidBinding: $priceValid
                        )
                        ValidatedField(
                            title: engineType.amountFieldLabel,
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
                        Toggle("Vorherige \(engineType.refuelNoun) eingetragen?", isOn: $previousEntryExists)
                        Toggle(engineType.fullLabel, isOn: $fullTank)
                        Toggle("Verbrauch manuell eintragen?", isOn: $manualConsumption)

                        if manualConsumption {
                            ValidatedField(
                                title: "Verbrauch (\(engineType.consumptionUnit))",
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
                                    Text("\(DisplayFormatter.string(from: Decimal(computedConsumption), formatter: DisplayFormatter.consumption)) \(engineType.consumptionUnit)")
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
                }
                .padding(20)
                }
            }

            Divider()

            HStack {
                Button("Abbrechen", role: .cancel) { dismiss() }
                    .pointerStyle(.link)
                Spacer()
                Button("Speichern") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(!isFormValid)
                    .pointerStyle(isFormValid ? .link : nil)
            }
            .padding(16)
        }
        .frame(width: 460, height: 940)
    }

    private func save() {
        guard let selectedVehicle else { return }
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
        entry.vehicle = selectedVehicle

        if manualConsumption {
            if let value = FieldValidator.decimalValue(manualConsumptionText) {
                entry.consumption = NSDecimalNumber(decimal: value)
            }
        } else if let computedConsumption {
            entry.consumption = NSNumber(value: computedConsumption)
        }

        selectedVehicle.touch()
        PersistenceController.shared.save(context: viewContext)
        dismiss()
    }
}
