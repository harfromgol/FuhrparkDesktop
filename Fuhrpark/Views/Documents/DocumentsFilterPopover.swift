import SwiftUI

/// Einfachauswahl für den Fahrzeugstatus im Dokumente-Filter.
enum FahrzeugStatusFilter: String, CaseIterable, Identifiable {
    case alle, aktiv, stillgelegt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alle: "Alle"
        case .aktiv: "Aktiv"
        case .stillgelegt: "Stillgelegt"
        }
    }
}

/// Filtereinstellungen für die Dokumente-Ansicht, geöffnet über das
/// Filter-Symbol neben dem Zahnrad. Fahrzeug- und Kategorie-Auswahl sind
/// Dropdowns mit fester Größe, damit sich das Popover nicht verschiebt, wenn
/// sich durch die Kaskade die Anzahl der wählbaren Fahrzeuge/Kategorien
/// ändert (anders als die zuvor verwendeten Chip-Gitter). Der Fahrzeugfilter
/// nutzt denselben `VehiclePicker` wie die Formulare (Neue Notiz/Ausgabe/
/// Erinnerung) – gruppiert nach Aktiv/Stillgelegt, mit Hersteller/Modell/
/// km-Stand je Zeile.
///
/// Die vier Filter verunden sich und kaskadieren in dieser Reihenfolge:
/// Fahrzeugstatus schränkt die wählbaren Fahrzeuge ein, beide zusammen
/// schränken die wählbaren Kategorien ein. `availableVehicles`/
/// `availableCategoryNames` kommen dafür bereits vorgefiltert von
/// `DocumentsView` herein – diese Ansicht rechnet selbst nichts nach.
struct DocumentsFilterPopover: View {
    @Binding var statusFilter: FahrzeugStatusFilter
    @Binding var selectedVehicleFilter: Vehicle?
    @Binding var selectedCategoryFilter: String?
    @Binding var isDateFilterActive: Bool
    @Binding var dateFrom: Date
    @Binding var dateTo: Date

    let availableVehicles: [Vehicle]
    let availableCategoryNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filter")
                    .font(.headline)
                Spacer()
                Button("Zurücksetzen") {
                    statusFilter = .alle
                    selectedVehicleFilter = nil
                    selectedCategoryFilter = nil
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
                VehiclePicker(vehicles: availableVehicles, selection: $selectedVehicleFilter, placeholder: "Alle")
            }

            LabeledContent("Kategorie") {
                Picker("Kategorie", selection: $selectedCategoryFilter) {
                    Text("Alle").tag(String?.none)
                    ForEach(availableCategoryNames, id: \.self) { name in
                        Text(name).tag(String?.some(name))
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
