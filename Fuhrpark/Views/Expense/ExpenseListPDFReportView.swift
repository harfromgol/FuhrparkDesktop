import SwiftUI

/// Druckfreundliche Darstellung der Ausgabenliste für den PDF-Export (siehe
/// `ReportPDFGenerator`). Zeigt die aktuell nach Kategorie gefilterte, aber
/// NICHT auf die Bildschirm-Seitengröße beschränkte Liste als durchgehende
/// Tabelle (nicht als Karte pro Eintrag wie `ExpenseRow`), damit deutlich
/// mehr Zeilen auf eine Seite passen. Aufbau 1:1 nach dem Vorbild von
/// `FuelEntryListPDFReportView`.
struct ExpenseListPDFReportView: View {
    let vehicleRef: VehicleRef
    let expenses: [Expense]
    let categoryFilterLabel: String

    var sections: [PDFReportSection] {
        var result: [PDFReportSection] = [
            PDFReportSection(view: AnyView(reportHeader), rowInfo: nil)
        ]
        if !expenses.isEmpty {
            result.append(PDFReportSection(
                view: AnyView(expensesSection(expenses[0..<expenses.count])),
                rowInfo: .init(rowCount: expenses.count, chromeOnly: AnyView(expensesSection(expenses[0..<0])))
            ))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PDFReportLayout.sectionSpacing) {
            ForEach(sections.indices, id: \.self) { sections[$0].view }
        }
        .padding(.horizontal, PDFReportLayout.horizontalPadding)
        .frame(width: PDFReportLayout.pageWidth, alignment: .leading)
        .foregroundStyle(.black)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sonstige Ausgaben – \(vehicleRef.licensePlate)")
                .font(.title.bold())
            Text("\(categoryFilterLabel) · Erstellt am \(FieldValidator.string(from: Date()))")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    /// Nimmt bewusst einen Zeilen-Ausschnitt statt immer aller Ausgaben
    /// entgegen: `sections` ruft dies zweimal auf (alle Zeilen für die
    /// Anzeige, null Zeilen zur Kopf-/Zeilenhöhen-Messung in
    /// `ReportPDFGenerator`).
    private func expensesSection(_ items: ArraySlice<Expense>) -> some View {
        PDFReportCard {
            VStack(alignment: .leading, spacing: 0) {
                row(
                    Text("Datum"),
                    Text("Empfänger"),
                    Text("Zweck"),
                    Text("Kategorie"),
                    Text("Betrag")
                )
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.bottom, 6)

                Divider()

                ForEach(Array(items.enumerated()), id: \.element.objectID) { index, expense in
                    row(
                        Text(FieldValidator.string(from: expense.date ?? Date())),
                        Text(expense.recipient ?? ""),
                        Text(expense.purpose ?? ""),
                        Text(expense.categoriesDisplay.isEmpty ? "–" : expense.categoriesDisplay),
                        Text((expense.isIncome ? "+" : "") + DisplayFormatter.currencyString(expense.amount?.decimalValue ?? 0)).bold()
                    )
                    .font(.subheadline)
                    .padding(.vertical, 4)
                    // Zebra-Streifen für bessere Lesbarkeit bei vielen Zeilen.
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.gray.opacity(0.08))
                }
            }
        }
    }

    /// Eine Tabellenzeile mit fünf fest breiten Spalten – feste statt
    /// inhaltsabhängiger Breiten halten jede Zeile exakt gleich hoch
    /// (einzeilig durch `.lineLimit(1)`), was `ReportPDFGenerator`s
    /// Zeilenumbruch-Berechnung voraussetzt.
    private func row(
        _ date: Text,
        _ recipient: Text,
        _ purpose: Text,
        _ category: Text,
        _ amount: Text
    ) -> some View {
        HStack(spacing: 12) {
            date.frame(width: 70, alignment: .leading)
            recipient.frame(width: 110, alignment: .leading)
            purpose.frame(maxWidth: .infinity, alignment: .leading)
            category.frame(width: 90, alignment: .leading)
            amount.frame(width: 70, alignment: .trailing)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
