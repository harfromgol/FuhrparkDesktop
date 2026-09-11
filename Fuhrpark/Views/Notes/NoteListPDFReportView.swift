import SwiftUI

/// Druckfreundliche Darstellung der Notizenliste eines Fahrzeugs für den
/// PDF-Export (siehe `ReportPDFGenerator`). Zeigt die aktuell nach Jahr
/// gefilterte, aber NICHT auf die Bildschirm-Seitengröße beschränkte Liste
/// als durchgehende Tabelle (nicht als Karte pro Eintrag wie `NoteRow`).
/// Aufbau nach dem Vorbild von `FuelEntryListPDFReportView`, mit einem
/// Unterschied: der Notiztext wird NICHT auf eine Zeile gekürzt, sondern
/// mehrzeilig komplett dargestellt – Zeilen sind hier deshalb unterschiedlich
/// hoch, siehe `singleRow` unten.
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
                rowInfo: .init(
                    rowCount: notizen.count,
                    chromeOnly: AnyView(notesSection(notizen[0..<0])),
                    // Zeilen sind wegen des mehrzeiligen Texts unterschiedlich
                    // hoch – jede Zeile für die Zeilenumbruch-Berechnung in
                    // `ReportPDFGenerator` einzeln vermessbar machen, statt
                    // (wie im gleich hohen Standardfall) eine gemittelte Höhe
                    // anzunehmen.
                    singleRow: { index in AnyView(notesSection(notizen[index..<(index + 1)])) }
                )
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
    /// entgegen: `sections` ruft dies mehrfach auf (alle Zeilen für die
    /// Anzeige, null Zeilen zur Kopfhöhen-Messung, sowie je Notiz einmal mit
    /// genau einer Zeile zur Messung ihrer individuellen Höhe – siehe
    /// `singleRow`).
    private func notesSection(_ items: ArraySlice<Notiz>) -> some View {
        PDFReportCard {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.bottom, 6)

                Divider()

                ForEach(Array(items.enumerated()), id: \.element.objectID) { index, notiz in
                    noteRow(notiz)
                        .padding(.vertical, 4)
                        // Zebra-Streifen für bessere Lesbarkeit bei vielen Zeilen.
                        .background(index.isMultiple(of: 2) ? Color.clear : Color.gray.opacity(0.08))
                }
            }
        }
    }

    /// Spaltenköpfe – einzeilig, da kurze, feste Beschriftungen.
    private var headerRow: some View {
        HStack(spacing: 12) {
            Text("Datum").frame(width: 78, alignment: .leading)
            Text("Text").frame(maxWidth: .infinity, alignment: .leading)
            Text("Dokumente").frame(width: 70, alignment: .trailing)
        }
        .lineLimit(1)
        .font(.caption)
        .foregroundStyle(.gray)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Eine Notiz-Zeile mit drei fest breiten Spalten. Anders als bei der
    /// Kopfzeile ist der Text hier NICHT auf eine Zeile begrenzt (kein
    /// `.lineLimit`) – die Notiz soll vollständig lesbar sein statt mit „…“
    /// abgeschnitten zu werden. `alignment: .top`, damit Datum/Dokumente bei
    /// mehrzeiligem Text oben bündig mit der ersten Zeile stehen.
    private func noteRow(_ notiz: Notiz) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(FieldValidator.string(from: notiz.date ?? Date()))
                .lineLimit(1)
                .frame(width: 78, alignment: .leading)
            Text(notiz.text ?? "")
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(notiz.sortedDokumente.isEmpty ? "–" : "\(notiz.sortedDokumente.count)")
                .lineLimit(1)
                .frame(width: 70, alignment: .trailing)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
