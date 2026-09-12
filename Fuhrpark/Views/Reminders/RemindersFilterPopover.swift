import SwiftUI

/// Filtereinstellungen für die Erinnerungen-Ansicht, identisch aufgebaut wie
/// `NotesFilterPopover`/`DocumentsFilterPopover` – auch derselbe
/// `VehiclePicker` für den Fahrzeugfilter (Einfachauswahl, nach Aktiv/
/// Stillgelegt gruppiert, mit Hersteller/Modell/km-Stand je Zeile).
struct RemindersFilterPopover: View {
    @Binding var statusFilter: RemindersView.StatusFilter
    @Binding var selectedVehicleFilter: Vehicle?

    let availableVehicles: [Vehicle]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filter")
                    .font(.headline)
                Spacer()
                Button("Zurücksetzen") {
                    statusFilter = .all
                    selectedVehicleFilter = nil
                }
                .buttonStyle(.borderless)
                .pointerStyle(.link)
            }

            LabeledContent("Status") {
                Picker("Status", selection: $statusFilter) {
                    ForEach(RemindersView.StatusFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            LabeledContent("Fahrzeug") {
                VehiclePicker(vehicles: availableVehicles, selection: $selectedVehicleFilter, placeholder: "Alle")
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
