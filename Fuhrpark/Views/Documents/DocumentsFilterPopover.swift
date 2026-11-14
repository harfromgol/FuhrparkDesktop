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
/// `DocumentsOverviewWindow` herein – diese Ansicht rechnet selbst nichts nach.
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

                GridRow {
                    Text("Kategorie")
                        .fixedSize()
                    StretchingMenuPicker(
                        title: "Kategorie",
                        selection: $selectedCategoryFilter,
                        options: [(String?.none, "Alle")] + availableCategoryNames.map { (String?.some($0), $0) }
                    )
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
