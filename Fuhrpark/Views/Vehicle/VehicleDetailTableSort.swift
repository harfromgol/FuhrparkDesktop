import SwiftUI

/// Eine sortierbare Spalte einer der Statistiktabellen (Fahrzeug-
/// Detailansicht oder flottenweite Statistik). `defaultAscending` ist die
/// Richtung, die beim erstmaligen Klick auf diese Spalte (oder als
/// allgemeiner Anfangswert der jeweils ersten Spalte) verwendet wird:
/// Text-Spalten aufsteigend, numerische Spalten absteigend.
protocol SortableColumn: RawRepresentable, CaseIterable, Hashable where RawValue == String {
    var defaultAscending: Bool { get }
}

enum ExpenseCategorySortColumn: String, SortableColumn {
    case category, total, share
    var defaultAscending: Bool { self == .category }
}

/// Spalten einer Jahres-Kosten-Tabelle, sowohl der fahrzeugeigenen
/// (`VehicleDetailView`) als auch der flottenweit aggregierten
/// (`StatisticsView`) – gleiche Spalten, gleiche Standardrichtungen, daher
/// von beiden Tabellen geteilt (unterschieden über `TableSort.table`).
enum YearlyCostSortColumn: String, SortableColumn {
    case year, fuel, expense, total
    var defaultAscending: Bool { false }
}

enum YearlyDistanceSortColumn: String, SortableColumn {
    case year, kilometers, odometer
    var defaultAscending: Bool { false }
}

enum CostPerVehicleSortColumn: String, SortableColumn {
    case licensePlate, fuel, expense, total
    var defaultAscending: Bool { self == .licensePlate }
}

/// Aktuelle Sortierung einer Tabelle, samt Persistenz in `TableSortStore`.
/// Klick auf die bereits aktive Spalte dreht die Richtung um, Klick auf
/// eine andere Spalte übernimmt deren `defaultAscending`.
struct TableSort<Column: SortableColumn> {
    var column: Column
    var ascending: Bool
    let table: TableSortStore.Table

    static func initial(for table: TableSortStore.Table) -> TableSort<Column> {
        if let saved = TableSortStore.sortState(for: table),
           let column = Column(rawValue: saved.column) {
            return TableSort(column: column, ascending: saved.ascending, table: table)
        }
        // Jede der Spalten-Enums hat mindestens einen Fall (Kategorie,
        // Fahrzeug, Jahr) – `allCases` kann hier nie leer sein.
        let firstColumn = Column.allCases.first!
        return TableSort(column: firstColumn, ascending: firstColumn.defaultAscending, table: table)
    }

    mutating func select(_ newColumn: Column) {
        if column == newColumn {
            ascending.toggle()
        } else {
            column = newColumn
            ascending = newColumn.defaultAscending
        }
        TableSortStore.setSortState(column: column.rawValue, ascending: ascending, for: table)
    }

    func isActive(_ candidate: Column) -> Bool { candidate == column }
}

/// Kopfzellen-Titel einer sortierbaren Statistiktabelle: reiner Text,
/// solange die Tabelle weniger als zwei Zeilen hat (Sortierung macht dann
/// keinen Sinn), sonst klickbar mit Sortier-Chevron. Der Chevron ist
/// dauerhaft sichtbar, aber ausschließlich an der gerade aktiven Spalte –
/// ein Klick auf eine andere Spalte lässt ihn dorthin „springen", damit auf
/// einen Blick klar ist, wonach sortiert ist.
struct SortHeaderCell: View {
    let title: String
    let isActive: Bool
    let ascending: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        if isEnabled {
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(title)
                    if isActive {
                        Image(systemName: ascending ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                }
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
        } else {
            Text(title)
        }
    }
}
