import SwiftUI

/// Sheet hinter „Neue Buchung“ in `ExpensesOverviewWindow`: fragt zuerst das
/// Fahrzeug ab und zeigt danach im selben Sheet das gewohnte
/// `ExpenseFormView`.
///
/// Der vorgeschaltete Schritt ist nötig, weil `ExpenseFormView` ein festes
/// Fahrzeug braucht – Kategorien und Empfänger-Vorschläge hängen am Fahrzeug
/// und werden dort schon im `init` per `@FetchRequest` darauf eingegrenzt. In
/// den Fahrzeugdetails steht das Fahrzeug von vornherein fest; im
/// fahrzeugübergreifenden Fenster muss es erst gewählt werden. Stillgelegte
/// Fahrzeuge bleiben wählbar, sonstige Buchungen sind dort weiterhin erlaubt.
struct NewExpenseFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let vehicles: [Vehicle]

    @State private var selectedVehicle: Vehicle?
    /// Erst mit „Weiter“ gesetzt – ab dann zeigt das Sheet das Formular.
    @State private var confirmedVehicle: Vehicle?

    /// `preselectedVehicle` ist das im Fenster gefilterte Fahrzeug, falls
    /// eines gewählt ist: Wer gerade die Buchungen eines Fahrzeugs ansieht,
    /// will die neue in aller Regel auch dort anlegen.
    init(vehicles: [Vehicle], preselectedVehicle: Vehicle? = nil) {
        self.vehicles = vehicles
        _selectedVehicle = State(initialValue: preselectedVehicle)
    }

    var body: some View {
        if let confirmedVehicle {
            ExpenseFormView(vehicle: confirmedVehicle)
        } else {
            vehicleStep
        }
    }

    private var vehicleStep: some View {
        VStack(spacing: 0) {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard(title: "Fahrzeug") {
                        VehiclePicker(vehicles: vehicles, selection: $selectedVehicle)
                        Text("Eine Buchung gehört zu genau einem Fahrzeug. Im nächsten Schritt stehen dessen Kategorien zur Auswahl.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Abbrechen", role: .cancel) { dismiss() }
                    .pointerStyle(.link)
                Spacer()
                Button("Weiter") { confirmedVehicle = selectedVehicle }
                    .buttonStyle(.glassProminent)
                    .disabled(selectedVehicle == nil)
                    .pointerStyle(selectedVehicle != nil ? .link : nil)
            }
            .padding(16)
        }
        .frame(width: 440)
    }
}
