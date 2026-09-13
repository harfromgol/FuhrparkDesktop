import SwiftUI

/// Sortierrichtung für die fahrzeugübergreifende Betankungsübersicht: primär
/// nach Datum, bei Gleichstand zusätzlich nach km-Stand (siehe
/// `FuelEntriesView.sortedEntries`).
enum FuelEntrySortOrder: String, CaseIterable, Identifiable {
    case ascending = "Aufsteigend"
    case descending = "Absteigend"

    var id: String { rawValue }
}

/// Filter- und Anzeigeoptionen für die fahrzeugübergreifende
/// Betankungsübersicht (`FuelEntriesView`), aufgebaut wie
/// `NotesFilterPopover`/`DocumentsFilterPopover` (Status/Fahrzeug-Kaskade).
/// Anders als dort stehen hier zusätzlich „Anzahl Resultate“ und
/// „Sortierung“ im selben Popover – die fahrzeugübergreifende Liste hat kein
/// einzelnes Fahrzeug, an dessen Detailkarte eine zweite Optionsleiste (wie
/// `ReminderListWindow.displayOptions`) angebracht werden könnte.
/// „Zurücksetzen“ betrifft bewusst nur Status und Fahrzeug – Seitengröße und
/// Sortierung sind Anzeige-Präferenzen, keine einschränkenden Filter.
struct FuelEntriesFilterPopover: View {
    @Binding var statusFilter: FahrzeugStatusFilter
    @Binding var selectedVehicleFilter: Vehicle?
    @Binding var showAllResults: Bool
    @Binding var pageSize: Int
    @Binding var sortOrder: FuelEntrySortOrder

    let availableVehicles: [Vehicle]
    let maxPageSize: Int

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

            LabeledContent("Status") {
                Picker("Status", selection: $statusFilter) {
                    ForEach(FahrzeugStatusFilter.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            LabeledContent("Kennzeichen") {
                VehiclePicker(vehicles: availableVehicles, selection: $selectedVehicleFilter, placeholder: "Alle")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Resultate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Alle anzeigen")
                    Spacer()
                    Toggle("Alle anzeigen", isOn: $showAllResults)
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                }

                if !showAllResults {
                    HStack {
                        Text("Anzahl Resultate")
                        Spacer()
                        Stepper("\(pageSize)", value: $pageSize, in: 1...maxPageSize)
                            .fixedSize()
                    }
                }
            }

            Divider()

            HStack {
                Text("Sortierung")
                Spacer()
                Picker("Sortierung", selection: $sortOrder) {
                    ForEach(FuelEntrySortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
