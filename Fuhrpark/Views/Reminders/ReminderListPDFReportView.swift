import SwiftUI

/// Druckfreundliche Darstellung der Erinnerungsliste eines Fahrzeugs für den
/// PDF-Export (siehe `ReportPDFGenerator`). Zeigt die Liste als durchgehende
/// Tabelle (nicht als Karte pro Eintrag wie `ReminderRow`). Aufbau nach dem
/// Vorbild von `FuelEntryListPDFReportView` – anders als bei
/// `NoteListPDFReportView` reicht hier eine über alle Zeilen gemittelte Höhe
/// (kein `singleRow` in `RowInfo`), da der Titel mit maximal 40 Zeichen
/// (siehe `ReminderFormView`) einzeilig bleibt.
struct ReminderListPDFReportView: View {
    let vehicleRef: VehicleRef
    let reminders: [Erinnerung]

    var sections: [PDFReportSection] {
        var result: [PDFReportSection] = [
            PDFReportSection(view: AnyView(reportHeader), rowInfo: nil)
        ]
        if !reminders.isEmpty {
            result.append(PDFReportSection(
                view: AnyView(remindersSection(reminders[0..<reminders.count])),
                rowInfo: .init(rowCount: reminders.count, chromeOnly: AnyView(remindersSection(reminders[0..<0])))
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
            Text("Erinnerungen – \(vehicleRef.licensePlate)")
                .font(.title.bold())
            Text("Erstellt am \(FieldValidator.string(from: Date()))")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    /// Nimmt bewusst einen Zeilen-Ausschnitt statt immer aller Erinnerungen
    /// entgegen: `sections` ruft dies zweimal auf (alle Zeilen für die
    /// Anzeige, null Zeilen zur Kopf-/Zeilenhöhen-Messung in
    /// `ReportPDFGenerator`).
    private func remindersSection(_ items: ArraySlice<Erinnerung>) -> some View {
        PDFReportCard {
            VStack(alignment: .leading, spacing: 0) {
                row(
                    Text("Fälligkeit"),
                    Text("Titel"),
                    Text("Status")
                )
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.bottom, 6)

                Divider()

                ForEach(Array(items.enumerated()), id: \.element.objectID) { index, reminder in
                    row(
                        Text(FieldValidator.string(from: reminder.dueDate ?? Date())),
                        Text(reminder.title ?? ""),
                        Text(reminder.isDone ? "Erledigt" : "Offen")
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
        _ due: Text,
        _ title: Text,
        _ status: Text
    ) -> some View {
        HStack(spacing: 12) {
            due.frame(width: 78, alignment: .leading)
            title.frame(maxWidth: .infinity, alignment: .leading)
            status.frame(width: 70, alignment: .trailing)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
