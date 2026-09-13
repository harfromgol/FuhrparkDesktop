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
                .alignment(.center)
            }
            if visibleColumns.contains(.licensePlate) {
                TableColumn("Kennzeichen") { entry in
                    Text(entry.vehicle?.licensePlate ?? "–")
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.odometer) {
                TableColumn("km-Stand") { entry in
                    trailingCell("\(entry.odometer) km")
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.pricePerLiter) {
                TableColumn("Preis pro Liter") { entry in
                    trailingCell("\(DisplayFormatter.pricePerLiterString(entry.pricePerLiter?.decimalValue ?? 0))\(engineType(for: entry).pricePerUnitSuffix)")
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.liters) {
                TableColumn("Getankt") { entry in
                    trailingCell("\(DisplayFormatter.string(from: entry.liters?.decimalValue ?? 0, formatter: DisplayFormatter.decimal2)) \(engineType(for: entry).energyUnit)")
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.amount) {
                TableColumn("Gesamt") { entry in
                    trailingCell(DisplayFormatter.currencyString(entry.amount?.decimalValue ?? 0))
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.consumption) {
                TableColumn("Verbrauch") { entry in
                    trailingCell(consumptionText(for: entry))
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.station) {
                TableColumn("Tankstelle") { entry in
                    Text(entry.station ?? "")
                }
                .alignment(.center)
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

    /// Rechtsbündige Ausrichtung der Werte in numerischen Spalten (km-Stand,
    /// Preis pro Liter, Getankt, Gesamt, Verbrauch) – unabhängig von der
    /// zentrierten Kopfzeile (`.alignment(.center)` oben), die nur den
    /// Spaltentitel betrifft, nicht den vom `content`-Closure selbst
    /// gerenderten Zellinhalt.
    private func trailingCell(_ text: String) -> some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func engineType(for entry: FuelEntry) -> EngineType {
        entry.vehicle?.engineType ?? .combustion
    }

    private func consumptionText(for entry: FuelEntry) -> String {
        guard let value = entry.vehicle?.effectiveConsumption(for: entry) else { return "–" }
        return "\(DisplayFormatter.string(from: Decimal(value), formatter: DisplayFormatter.consumption)) \(engineType(for: entry).consumptionUnit)"
    }
}
