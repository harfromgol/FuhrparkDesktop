import SwiftUI

/// Druckfreundliche Darstellung der Notizenliste eines Fahrzeugs für den
/// PDF-Export (siehe `ReportPDFGenerator`). Zeigt die aktuell nach Jahr
/// gefilterte, aber NICHT auf die Bildschirm-Seitengröße beschränkte Liste
/// als durchgehende Tabelle (nicht als Karte pro Eintrag wie `NoteRow`).
/// Aufbau 1:1 nach dem Vorbild von `FuelEntryListPDFReportView`.
struct NoteListPDFReportView: View {
    let vehicleRef: VehicleRef
    let notizen: [Notiz]
    let selectedYear: Int?

    var sections: [PDFReportSection] {
        var result: [PDFReportSection] = [
            PDFReportSection(view: AnyView(reportHeader), rowInfo: nil)
        ]
        if !notizen.isEmpty {
            result.append(PDFReportSection(
                view: AnyView(notesSection(notizen[0..<notizen.count])),
                rowInfo: .init(rowCount: notizen.count, chromeOnly: AnyView(notesSection(notizen[0..<0])))
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
            Text("Notizen – \(vehicleRef.licensePlate)")
                .font(.title.bold())
            Text("\(selectedYear.map { "Jahr \($0)" } ?? "Alle Jahre") · Erstellt am \(FieldValidator.string(from: Date()))")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    /// Nimmt bewusst einen Zeilen-Ausschnitt statt immer aller Notizen
    /// entgegen: `sections` ruft dies zweimal auf (alle Zeilen für die
    /// Anzeige, null Zeilen zur Kopf-/Zeilenhöhen-Messung in
    /// `ReportPDFGenerator`).
    private func notesSection(_ items: ArraySlice<Notiz>) -> some View {
        PDFReportCard {
            VStack(alignment: .leading, spacing: 0) {
                row(
                    Text("Datum"),
                    Text("Text"),
                    Text("Dokumente")
                )
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.bottom, 6)

                Divider()

                ForEach(Array(items.enumerated()), id: \.element.objectID) { index, notiz in
                    row(
                        Text(FieldValidator.string(from: notiz.date ?? Date())),
                        Text(notiz.text ?? ""),
                        Text(notiz.sortedDokumente.isEmpty ? "–" : "\(notiz.sortedDokumente.count)")
                    )
                    .font(.subheadline)
                    .padding(.vertical, 4)
                    // Zebra-Streifen für bessere Lesbarkeit bei vielen Zeilen.
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.gray.opacity(0.08))
                }
            }
        }
    }

    /// Eine Tabellenzeile mit drei fest breiten Spalten – feste statt
    /// inhaltsabhängiger Breiten halten jede Zeile exakt gleich hoch
    /// (einzeilig durch `.lineLimit(1)`), was `ReportPDFGenerator`s
    /// Zeilenumbruch-Berechnung voraussetzt.
    private func row(
        _ date: Text,
        _ text: Text,
        _ documents: Text
    ) -> some View {
        HStack(spacing: 12) {
            date.frame(width: 78, alignment: .leading)
            text.frame(maxWidth: .infinity, alignment: .leading)
            documents.frame(width: 70, alignment: .trailing)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
