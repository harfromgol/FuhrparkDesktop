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

            // Die Beschriftung darf nicht nachgeben: Nach dem ersten Klick
            // macht die Segmentleiste alle Segmente so breit wie das
            // breiteste („Stillgelegt“) und drückte „Status“ sonst auf „St…“
            // zusammen oder in zwei Zeilen. Die Popover-Breite unten ist so
            // gewählt, dass Beschriftung und Leiste nebeneinander passen.
            LabeledContent {
                Picker("Status", selection: $statusFilter) {
                    ForEach(FahrzeugStatusFilter.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            } label: {
                Text("Status")
                    .fixedSize()
            }

            LabeledContent("Kennzeichen") {
                VehiclePicker(vehicles: availableVehicles, selection: $selectedVehicleFilter, placeholder: "Alle")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Sortierung")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                // `.frame(maxWidth: .infinity)` allein reicht bei einem
                // segmentierten Picker nicht – der Rahmen wird zwar breiter,
                // der Picker selbst bleibt bei seiner Idealbreite und wirkt
                // darin nur zentriert. `LabeledContent` mit ausgeblendetem
                // Label (wie bei „Status" oben) gibt dem Inhalt dagegen die
                // volle Zeilenbreite als feste statt „bis zu"-Vorgabe, das
                // zwingt den Picker zum tatsächlichen Strecken.
                LabeledContent("") {
                    Picker("Sortierung", selection: $sortOrder) {
                        ForEach(FuelEntrySortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                .labelsHidden()
            }
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
    }
}
