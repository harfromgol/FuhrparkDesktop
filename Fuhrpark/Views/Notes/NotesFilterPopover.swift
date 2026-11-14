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

            // Beschriftungen und Auswahlen stehen in zwei Spalten und
            // schließen links wie rechts bündig ab – Aufbau und Begründung
            // wie in `FuelEntriesFilterPopover`.
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 16) {
                GridRow {
                    Text("Status")
                        .fixedSize()
                    StretchingSegmentedPicker(
                        title: "Status",
                        selection: $statusFilter,
                        options: FahrzeugStatusFilter.allCases.map { ($0, $0.displayName) }
                    )
                }

                GridRow {
                    Text("Fahrzeug")
                        .fixedSize()
                    VehiclePicker(vehicles: availableVehicles, selection: $selectedVehicleFilter, placeholder: "Alle")
                }
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
        .frame(width: 376, alignment: .leading)
    }
}
