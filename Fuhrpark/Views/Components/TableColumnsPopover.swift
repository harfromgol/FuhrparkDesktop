import SwiftUI

/// Popover zum Ein-/Ausblenden einzelner Spalten einer Tabelle – aufgerufen
/// über den Button neben der Tabellenüberschrift in
/// `FuelEntriesOverviewWindow` (Spalten: `FuelEntryTableColumn`) und
/// `ExpensesOverviewWindow` (Spalten: `ExpenseTableColumn`). Die Spalten
/// erscheinen in der Reihenfolge ihrer Deklaration, beschriftet mit ihrem
/// Rohwert. Die letzte verbleibende sichtbare Spalte lässt sich nicht
/// abwählen, sonst bliebe die Tabelle spaltenlos zurück.
struct TableColumnsPopover<Column>: View
where Column: CaseIterable & Identifiable & Hashable & RawRepresentable,
      Column.RawValue == String,
      Column.AllCases: RandomAccessCollection {
    @Binding var visibleColumns: Set<Column>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spalten")
                .font(.headline)

            ForEach(Column.allCases) { column in
                Toggle(column.rawValue, isOn: binding(for: column))
                    .toggleStyle(.checkbox)
                    .disabled(isLastVisibleColumn(column))
            }
        }
        .padding(16)
        .frame(width: 220, alignment: .leading)
    }

    private func isLastVisibleColumn(_ column: Column) -> Bool {
        visibleColumns.count == 1 && visibleColumns.contains(column)
    }

    private func binding(for column: Column) -> Binding<Bool> {
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
