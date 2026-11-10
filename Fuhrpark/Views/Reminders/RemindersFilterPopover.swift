import SwiftUI

/// Status-Filter der Erinnerungslisten (`RemindersOverviewWindow`,
/// `ReminderListWindow`). Die Rohwerte sind bewusst von der Beschriftung
/// getrennt: `RemindersOverviewFilterStore` speichert sie in den
/// UserDefaults, eine geänderte Beschriftung darf den gespeicherten Filter
/// nicht verwerfen.
enum ReminderStatusFilter: String, CaseIterable, Identifiable {
    case all
    case open
    case done

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "Alle"
        case .open: "Offen"
        case .done: "Erledigt"
        }
    }
}

/// Filtereinstellungen für das Erinnerungen-Fenster
/// (`RemindersOverviewWindow`), identisch aufgebaut wie
/// `NotesFilterPopover`/`DocumentsFilterPopover` – auch derselbe
/// `VehiclePicker` für den Fahrzeugfilter (Einfachauswahl, nach Aktiv/
/// Stillgelegt gruppiert, mit Hersteller/Modell/km-Stand je Zeile).
struct RemindersFilterPopover: View {
    @Binding var statusFilter: ReminderStatusFilter
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
                    ForEach(ReminderStatusFilter.allCases) { Text($0.displayName).tag($0) }
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
