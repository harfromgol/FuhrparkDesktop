import SwiftUI

struct VehicleFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    /// Fahrzeug, das bearbeitet wird; `nil` beim Anlegen eines neuen Fahrzeugs.
    let vehicleToEdit: Vehicle?

    @State private var licensePlate = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var odometerText = ""
    @State private var engineType: EngineType = .combustion

    @State private var licensePlateValid = false
    @State private var manufacturerValid = false
    @State private var modelValid = false
    @State private var odometerValid = false

    init(vehicleToEdit: Vehicle? = nil) {
        self.vehicleToEdit = vehicleToEdit
        _licensePlate = State(initialValue: vehicleToEdit?.licensePlate ?? "")
        _manufacturer = State(initialValue: vehicleToEdit?.manufacturer ?? "")
        _model = State(initialValue: vehicleToEdit?.model ?? "")
        _odometerText = State(initialValue: vehicleToEdit.map { String($0.odometer) } ?? "")
        _engineType = State(initialValue: vehicleToEdit?.engineType ?? .combustion)
    }

    private var isFormValid: Bool {
        licensePlateValid && manufacturerValid && modelValid && odometerValid
    }

    /// km-Stand der ersten (kilometerniedrigsten) Betankung dieses Fahrzeugs,
    /// falls beim Bearbeiten bereits welche erfasst wurden – der Tachostand
    /// darf diesen nicht erreichen, da er den Fahrzeug-Anfangsstand darstellt.
    private var earliestFuelEntryOdometer: Int32? {
        vehicleToEdit?.sortedFuelEntries.first?.odometer
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GlassEffectContainer {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard(title: "Fahrzeugdaten") {
                        ValidatedField(
                            title: "Kennzeichen",
                            text: $licensePlate,
                            kind: .licensePlate,
                            isValidBinding: $licensePlateValid
                        )
                        ValidatedField(
                            title: "Hersteller",
                            text: $manufacturer,
                            kind: .text(min: 1, max: 15),
                            isValidBinding: $manufacturerValid
                        )
                        ValidatedField(
                            title: "Modell",
                            text: $model,
                            kind: .text(min: 1, max: 30),
                            isValidBinding: $modelValid
                        )
                        ValidatedField(
                            title: "Tachostand (km)",
                            text: $odometerText,
                            kind: .integer(minDigits: 1, maxDigits: 6),
                            isValidBinding: $odometerValid,
                            extraValidation: { text in
                                guard let limit = earliestFuelEntryOdometer, let value = FieldValidator.intValue(text) else { return true }
                                return value < limit
                            },
                            extraErrorMessage: earliestFuelEntryOdometer.map { "Muss kleiner als \(DisplayFormatter.odometerString($0)) km sein (km-Stand der ersten Betankung)" }
                        )
                    }

                    GlassCard(title: "Motorart") {
                        Picker("Motorart", selection: $engineType) {
                            ForEach(EngineType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
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
        .frame(width: 420, height: 620)
    }

    private func save() {
        let vehicle = vehicleToEdit ?? Vehicle(context: viewContext)
        if vehicleToEdit == nil {
            vehicle.id = UUID()
            vehicle.createdAt = Date()
        }
        vehicle.licensePlate = licensePlate
        vehicle.manufacturer = manufacturer
        vehicle.model = model
        vehicle.odometer = FieldValidator.intValue(odometerText) ?? 0
        vehicle.engineType = engineType
        vehicle.lastChangedDts = Date()

        PersistenceController.shared.save(context: viewContext)
        dismiss()
    }
}

#Preview {
    VehicleFormView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
