import SwiftUI

/// Popover zum Ein-/Ausblenden einzelner Spalten der Tabellenansicht
/// (`FuelEntriesTable`) in `FuelEntriesView` – aufgerufen über den Button
/// neben der Überschrift „Betankungen (…)“, nur in der Tabellenansicht
/// sichtbar. Die letzte verbleibende sichtbare Spalte lässt sich nicht
/// abwählen, sonst bliebe die Tabelle spaltenlos zurück.
struct FuelEntriesColumnsPopover: View {
    @Binding var visibleColumns: Set<FuelEntryTableColumn>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spalten")
                .font(.headline)

            ForEach(FuelEntryTableColumn.allCases) { column in
                Toggle(column.rawValue, isOn: binding(for: column))
                    .toggleStyle(.checkbox)
                    .disabled(isLastVisibleColumn(column))
            }
        }
        .padding(16)
        .frame(width: 220, alignment: .leading)
    }

    private func isLastVisibleColumn(_ column: FuelEntryTableColumn) -> Bool {
        visibleColumns.count == 1 && visibleColumns.contains(column)
    }

    private func binding(for column: FuelEntryTableColumn) -> Binding<Bool> {
        Binding(
            get: { visibleColumns.contains(column) },
            set: { isOn in
                if isOn {
                    visibleColumns.insert(column)
                } else {
                    visibleColumns.remove(column)
                }
            }
        )
    }
}
