import SwiftUI

/// Welche Spalten der Tabelle (`ExpensesTable`) sichtbar sind – einstellbar
/// über `TableColumnsPopover`, gespeichert in `ExpensesOverviewFilterStore`.
/// Die Reihenfolge der Fälle ist zugleich die Reihenfolge im Spalten-Popover
/// und entspricht der Spaltenfolge in der Tabelle.
enum ExpenseTableColumn: String, CaseIterable, Identifiable {
    case date = "Datum"
    case licensePlate = "Kennzeichen"
    case recipient = "Empfänger"
    case purpose = "Verwendungszweck"
    case amount = "Betrag"
    case categories = "Kategorien"
    case documents = "Dokumente"

    var id: String { rawValue }
}

/// Tabelle der fahrzeugübergreifenden Übersicht der sonstigen Buchungen
/// (`ExpensesOverviewWindow`). Bekommt die bereits gefilterten und sortierten
/// Ausgaben/Einnahmen übergeben und stellt sie nur dar – aufgebaut wie
/// `FuelEntriesTable`.
struct ExpensesTable: View {
    let expenses: [Expense]
    let visibleColumns: Set<ExpenseTableColumn>
    let onDelete: (Expense) -> Void
    /// Meldet, wenn sich ein Dokument nicht öffnen ließ (etwa weil die Datei
    /// im Arbeitsverzeichnis fehlt) – den Alert dazu zeigt das Fenster.
    let onError: (String) -> Void

    @State private var selection = Set<Expense.ID>()

    var body: some View {
        Table(expenses, selection: $selection) {
            if visibleColumns.contains(.date) {
                TableColumn("Datum") { expense in
                    Text(FieldValidator.string(from: expense.date ?? Date()))
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.licensePlate) {
                TableColumn("Kennzeichen") { expense in
                    Text(expense.vehicle?.licensePlate ?? "–")
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.recipient) {
                TableColumn("Empfänger") { expense in
                    leadingCell(expense.recipient ?? "")
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.purpose) {
                TableColumn("Verwendungszweck") { expense in
                    leadingCell(expense.purpose ?? "")
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.amount) {
                TableColumn("Betrag") { expense in
                    amountCell(for: expense)
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.categories) {
                TableColumn("Kategorien") { expense in
                    leadingCell(expense.categoriesDisplay.isEmpty ? "–" : expense.categoriesDisplay)
                }
                .alignment(.center)
            }
            if visibleColumns.contains(.documents) {
                TableColumn("Dokumente") { expense in
                    ExpenseDocumentsCell(expense: expense, onError: onError)
                }
                .alignment(.center)
            }
        }
        .frame(maxHeight: .infinity)
        .contextMenu(forSelectionType: Expense.ID.self) { selectedIDs in
            if let id = selectedIDs.first, let expense = expenses.first(where: { $0.id == id }) {
                Button("Löschen", role: .destructive) {
                    onDelete(expense)
                }
            }
        }
    }

    /// Linksbündige Ausrichtung der Textspalten – unabhängig von der
    /// zentrierten Kopfzeile (`.alignment(.center)` oben), siehe
    /// `FuelEntriesTable.trailingCell` zum selben Punkt.
    private func leadingCell(_ text: String) -> some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Betrag rechtsbündig; Einnahmen wie in `ExpenseRow` mit „+“ und grün.
    private func amountCell(for expense: Expense) -> some View {
        Text((expense.isIncome ? "+" : "") + DisplayFormatter.currencyString(expense.amount?.decimalValue ?? 0))
            .foregroundStyle(expense.isIncome ? AnyShapeStyle(Color.green) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Zelle der Spalte „Dokumente“: eine Zeile je zugeordnetem Dokument, die
/// Zeile wächst mit der Anzahl. Ein Klick öffnet das Dokument mit der
/// zuständigen Standard-App (`Dokument.open()`).
///
/// Eigener View mit `@ObservedObject`, damit die Zelle auch dann neu
/// gezeichnet wird, wenn sich nur die Zuordnung ändert – etwa wenn ein Beleg
/// im Dokumente-Fenster entfernt wird, während diese Tabelle offen ist.
private struct ExpenseDocumentsCell: View {
    @ObservedObject var expense: Expense
    let onError: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(expense.sortedDocuments) { document in
                Button {
                    do {
                        try document.open()
                    } catch {
                        onError(error.localizedDescription)
                    }
                } label: {
                    Label(document.filename, systemImage: "doc")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help("„\(document.filename)“ öffnen")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
