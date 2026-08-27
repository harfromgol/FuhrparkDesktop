import SwiftUI

/// Filtereinstellungen für die Notizen-Ansicht, aufgebaut wie
/// `DocumentsFilterPopover`, nur ohne Kategorie-Filter – Notizen kennen
/// keine Kategorien.
struct NotesFilterPopover: View {
    @Binding var statusFilter: FahrzeugStatusFilter
    @Binding var selectedVehicleFilter: Vehicle?
    @Binding var isDateFilterActive: Bool
    @Binding var dateFrom: Date
    @Binding var dateTo: Date

    let availableVehicles: [Vehicle]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filter")
                    .font(.headline)
                Spacer()
                Button("Zurücksetzen") {
                    statusFilter = .alle
                    selectedVehicleFilter = nil
                    isDateFilterActive = false
                }
                .buttonStyle(.borderless)
                .pointerStyle(.link)
            }

            LabeledContent("Status") {
                Picker("Status", selection: $statusFilter) {
                    ForEach(FahrzeugStatusFilter.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            LabeledContent("Fahrzeug") {
                Picker("Fahrzeug", selection: $selectedVehicleFilter) {
                    Text("Alle").tag(Vehicle?.none)
                    ForEach(availableVehicles) { vehicle in
                        Text(vehicle.licensePlate ?? "").tag(Vehicle?.some(vehicle))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Zeitraum eingrenzen", isOn: $isDateFilterActive)
                    .toggleStyle(.checkbox)
                if isDateFilterActive {
                    HStack {
                        DatePicker(
                            "Von",
                            selection: $dateFrom,
                            in: ...dateTo,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "Bis",
                            selection: $dateTo,
                            in: dateFrom...,
                            displayedComponents: .date
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
