import SwiftUI

struct VehicleFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var licensePlate = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var odometerText = ""
    @State private var engineType: EngineType = .combustion

    @State private var licensePlateValid = false
    @State private var manufacturerValid = false
    @State private var modelValid = false
    @State private var odometerValid = false

    private var isFormValid: Bool {
        licensePlateValid && manufacturerValid && modelValid && odometerValid
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
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
                            isValidBinding: $odometerValid
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
        let vehicle = Vehicle(context: viewContext)
        vehicle.id = UUID()
        vehicle.licensePlate = licensePlate
        vehicle.manufacturer = manufacturer
        vehicle.model = model
        vehicle.odometer = FieldValidator.intValue(odometerText) ?? 0
        vehicle.engineType = engineType
        let now = Date()
        vehicle.createdAt = now
        vehicle.lastChangedDts = now

        PersistenceController.shared.save(context: viewContext)
        dismiss()
    }
}

#Preview {
    VehicleFormView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
