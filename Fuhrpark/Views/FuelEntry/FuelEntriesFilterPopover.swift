import SwiftUI

/// Sortierrichtung für die fahrzeugübergreifenden Tabellenfenster: primär
/// nach Datum, bei Gleichstand zusätzlich nach km-Stand
/// (`FuelEntriesOverviewWindow.sortedEntries`) bzw. nach Empfänger
/// (`ExpensesOverviewWindow.sortedExpenses`).
enum FuelEntrySortOrder: String, CaseIterable, Identifiable {
    case ascending = "Aufsteigend"
    case descending = "Absteigend"

    var id: String { rawValue }
}

/// Filter- und Anzeigeoptionen für die fahrzeugübergreifende
/// Betankungsübersicht (`FuelEntriesOverviewWindow`) – unverändert
/// mitgenutzt von der Übersicht der sonstigen Buchungen
/// (`ExpensesOverviewWindow`), die dieselben drei Einstellungen braucht.
/// Aufgebaut wie
/// `NotesFilterPopover`/`DocumentsFilterPopover` (Status/Fahrzeug-Kaskade).
/// Anders als dort steht hier zusätzlich die „Sortierung“ im selben Popover
/// – die fahrzeugübergreifende Liste hat kein einzelnes Fahrzeug, an dessen
/// Detailkarte eine zweite Optionsleiste (wie
/// `ReminderListWindow.displayOptions`) angebracht werden könnte.
/// „Zurücksetzen“ betrifft bewusst nur Status und Fahrzeug – die Sortierung
/// ist eine Anzeige-Präferenz, kein einschränkender Filter.
struct FuelEntriesFilterPopover: View {
    @Binding var statusFilter: FahrzeugStatusFilter
    @Binding var selectedVehicleFilter: Vehicle?
    @Binding var sortOrder: FuelEntrySortOrder

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
                }
                .buttonStyle(.borderless)
                .pointerStyle(.link)
            }

            // Beschriftungen und Auswahlen stehen in zwei Spalten, damit alle
            // drei Zeilen links wie rechts bündig abschließen: Die erste
            // Spalte ist so breit wie die längste Beschriftung, die zweite
            // füllt den Rest. Die Segmentleisten sind dafür
            // `StretchingSegmentedPicker` statt des SwiftUI-`Picker`, der sich
            // nicht auf die Spaltenbreite strecken lässt.
            //
            // Die Beschriftungen dürfen nicht nachgeben (`fixedSize`): Eine
            // Segmentleiste beansprucht ihre volle Breite und drückte
            // „Status“ sonst auf „St…“ zusammen oder in zwei Zeilen – so
            // geschehen mit der SwiftUI-Leiste, die nach dem ersten Klick
            // alle Segmente so breit macht wie das breiteste. Die
            // Popover-Breite unten ist so gewählt, dass die längste
            // Beschriftung und die breiteste Leiste nebeneinander passen.
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
                    Text("Kennzeichen")
                        .fixedSize()
                    VehiclePicker(vehicles: availableVehicles, selection: $selectedVehicleFilter, placeholder: "Alle")
                }

                Divider()

                GridRow {
                    Text("Sortierung")
                        .fixedSize()
                    StretchingSegmentedPicker(
                        title: "Sortierung",
                        selection: $sortOrder,
                        options: FuelEntrySortOrder.allCases.map { ($0, $0.rawValue) }
                    )
                }
            }
        }
        .padding(16)
        .frame(width: 376, alignment: .leading)
    }
}
