import SwiftUI

/// Welche Spalten der Tabellenansicht (`FuelEntriesTable`) sichtbar sind –
/// einstellbar über `FuelEntriesColumnsPopover`. Nur eine Anzeige-Präferenz
/// für die laufende Sitzung, keine Filterung, deshalb bewusst nicht in
/// `FuelEntriesOverviewFilterStore` persistiert.
enum FuelEntryTableColumn: String, CaseIterable, Identifiable {
    case date = "Datum"
    case licensePlate = "Kennzeichen"
    case odometer = "km-Stand"
    case pricePerLiter = "Preis pro Liter"
    case liters = "Getankt"
    case amount = "Gesamt"
    case consumption = "Verbrauch"
    case station = "Tankstelle"

    var id: String { rawValue }
}

/// Tabellarische Alternative zur Karten-Liste (`FuelEntryRow`) in
/// `FuelEntriesView`, umschaltbar über deren Layout-Switch. Zeigt dieselben
/// (bereits gefilterten, sortierten und paginierten) Einträge wie die
/// Karten-Liste – nur die Darstellung unterscheidet sich.
struct FuelEntriesTable: View {
    let entries: [FuelEntry]
    let visibleColumns: Set<FuelEntryTableColumn>
    let onDelete: (FuelEntry) -> Void

    @State private var selection = Set<FuelEntry.ID>()

    var body: some View {
        Table(entries, selection: $selection) {
            if visibleColumns.contains(.date) {
                TableColumn("Datum") { entry in
                    Text(FieldValidator.string(from: entry.date ?? Date()))
                }
            }
            if visibleColumns.contains(.licensePlate) {
                TableColumn("Kennzeichen") { entry in
                    Text(entry.vehicle?.licensePlate ?? "–")
                }
            }
            if visibleColumns.contains(.odometer) {
                TableColumn("km-Stand") { entry in
                    Text("\(entry.odometer) km")
                }
            }
            if visibleColumns.contains(.pricePerLiter) {
                TableColumn("Preis pro Liter") { entry in
                    Text("\(DisplayFormatter.pricePerLiterString(entry.pricePerLiter?.decimalValue ?? 0))\(engineType(for: entry).pricePerUnitSuffix)")
                }
            }
            if visibleColumns.contains(.liters) {
                TableColumn("Getankt") { entry in
                    Text("\(DisplayFormatter.string(from: entry.liters?.decimalValue ?? 0, formatter: DisplayFormatter.decimal2)) \(engineType(for: entry).energyUnit)")
                }
            }
            if visibleColumns.contains(.amount) {
                TableColumn("Gesamt") { entry in
                    Text(DisplayFormatter.currencyString(entry.amount?.decimalValue ?? 0))
                }
            }
            if visibleColumns.contains(.consumption) {
                TableColumn("Verbrauch") { entry in
                    Text(consumptionText(for: entry))
                }
            }
            if visibleColumns.contains(.station) {
                TableColumn("Tankstelle") { entry in
                    Text(entry.station ?? "")
                }
            }
        }
        .frame(maxHeight: .infinity)
        .contextMenu(forSelectionType: FuelEntry.ID.self) { selectedIDs in
            if let id = selectedIDs.first, let entry = entries.first(where: { $0.id == id }) {
                Button("Löschen", role: .destructive) {
                    onDelete(entry)
                }
            }
        }
    }

    private func engineType(for entry: FuelEntry) -> EngineType {
        entry.vehicle?.engineType ?? .combustion
    }

    private func consumptionText(for entry: FuelEntry) -> String {
        guard let value = entry.vehicle?.effectiveConsumption(for: entry) else { return "–" }
        return "\(DisplayFormatter.string(from: Decimal(value), formatter: DisplayFormatter.consumption)) \(engineType(for: entry).consumptionUnit)"
    }
}
