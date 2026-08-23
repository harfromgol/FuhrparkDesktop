import SwiftUI

/// Eine sortierbare Spalte einer der drei Statistiktabellen in
/// `VehicleDetailView`. `defaultAscending` ist die Richtung, die beim
/// erstmaligen Klick auf diese Spalte (oder als allgemeiner Anfangswert der
/// jeweils ersten Spalte) verwendet wird: Text-Spalten aufsteigend,
/// numerische Spalten absteigend.
protocol SortableColumn: RawRepresentable, CaseIterable, Hashable where RawValue == String {
    var defaultAscending: Bool { get }
}

enum ExpenseCategorySortColumn: String, SortableColumn {
    case category, total, share
    var defaultAscending: Bool { self == .category }
}

enum YearlyCostSortColumn: String, SortableColumn {
    case year, fuel, expense, total
    var defaultAscending: Bool { false }
}

enum YearlyDistanceSortColumn: String, SortableColumn {
    case year, kilometers, odometer
    var defaultAscending: Bool { false }
}

/// Aktuelle Sortierung einer Tabelle, samt Persistenz in
/// `VehicleDetailTableSortStore`. Klick auf die bereits aktive Spalte
/// dreht die Richtung um, Klick auf eine andere Spalte übernimmt deren
/// `defaultAscending`.
struct TableSort<Column: SortableColumn> {
    var column: Column
    var ascending: Bool
    let table: VehicleDetailTableSortStore.Table

    static func initial(for table: VehicleDetailTableSortStore.Table) -> TableSort<Column> {
        if let saved = VehicleDetailTableSortStore.sortState(for: table),
           let column = Column(rawValue: saved.column) {
            return TableSort(column: column, ascending: saved.ascending, table: table)
        }
        // Jede der drei Spalten-Enums hat mindestens einen Fall (Kategorie,
        // Jahr) – `allCases` kann hier nie leer sein.
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
        VehicleDetailTableSortStore.setSortState(column: column.rawValue, ascending: ascending, for: table)
    }

    func isActive(_ candidate: Column) -> Bool { candidate == column }

    /// Anzeige-Richtung für eine Kopfzelle: die tatsächliche Richtung für die
    /// aktive Spalte, sonst die Richtung, die ein Klick auf `candidate`
    /// ergäbe (für den dezenten Hover-Hinweis auf noch inaktiven Spalten).
    func displayAscending(_ candidate: Column) -> Bool {
        isActive(candidate) ? ascending : candidate.defaultAscending
    }
}

/// Kopfzellen-Titel einer der drei Statistiktabellen: reiner Text, solange
/// die Tabelle weniger als zwei Zeilen hat (Sortierung macht dann keinen
/// Sinn), sonst klickbar mit Sortier-Chevron, der ausschließlich beim
/// Überfahren der Kopfzeile mit der Maus sichtbar ist – auch für die
/// gerade aktive Spalte, damit die Kopfzeile im Ruhezustand aufgeräumt
/// bleibt.
struct SortHeaderCell: View {
    let title: String
    let isActive: Bool
    let ascending: Bool
    let isEnabled: Bool
    let isHeaderHovered: Bool
    let action: () -> Void

    private var showIcon: Bool {
        isEnabled && isHeaderHovered
    }

    var body: some View {
        if isEnabled {
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(title)
                    if showIcon {
                        Image(systemName: ascending ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(isActive ? .secondary : .tertiary)
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
