import SwiftUI

/// Filtereinstellungen für die Erinnerungen-Ansicht, aufgebaut wie
/// `NotesFilterPopover`. Der Fahrzeugfilter erlaubt hier aber weiterhin eine
/// Mehrfachauswahl (mehrere Kennzeichen gleichzeitig) – deshalb ein echtes
/// `Menu` mit `Toggle`-Einträgen statt eines `Picker`s, der nur einen
/// einzelnen Auswahlwert kennt.
struct RemindersFilterPopover: View {
    @Binding var statusFilter: RemindersView.StatusFilter
    @Binding var selectedVehicleFilter: Set<Vehicle>

    let availableVehicles: [Vehicle]

    private var vehicleFilterTitle: String {
        switch selectedVehicleFilter.count {
        case 0: return "Alle"
        case 1: return selectedVehicleFilter.first?.licensePlate ?? "1 Fahrzeug"
        default: return "\(selectedVehicleFilter.count) Fahrzeuge"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filter")
                    .font(.headline)
                Spacer()
                Button("Zurücksetzen") {
                    statusFilter = .all
                    selectedVehicleFilter.removeAll()
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
                Menu(vehicleFilterTitle) {
                    ForEach(availableVehicles) { vehicle in
                        Toggle(vehicle.licensePlate ?? "", isOn: Binding(
                            get: { selectedVehicleFilter.contains(vehicle) },
                            set: { isOn in
                                if isOn {
                                    selectedVehicleFilter.insert(vehicle)
                                } else {
                                    selectedVehicleFilter.remove(vehicle)
                                }
                            }
                        ))
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
