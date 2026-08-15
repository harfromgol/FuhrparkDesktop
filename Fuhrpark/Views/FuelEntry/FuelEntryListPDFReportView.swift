import SwiftUI

/// Druckfreundliche Darstellung der Betankungsliste für den PDF-Export
/// (siehe `ReportPDFGenerator`). Zeigt die aktuell nach Jahr gefilterte,
/// aber NICHT auf die Bildschirm-Seitengröße beschränkte Liste als
/// durchgehende Tabelle (nicht als Karte pro Eintrag wie `FuelEntryRow`),
/// damit deutlich mehr Zeilen auf eine Seite passen.
struct FuelEntryListPDFReportView: View {
    let vehicleRef: VehicleRef
    let entries: [FuelEntry]
    let selectedYear: Int?

    /// Siehe `StatisticsPDFReportView.sections` für die Begründung dieser
    /// Struktur (Grundlage für `ReportPDFGenerator`s Seitenumbruch-Logik).
    var sections: [PDFReportSection] {
        var result: [PDFReportSection] = [
            PDFReportSection(view: AnyView(reportHeader), rowInfo: nil)
        ]
        if !entries.isEmpty {
            result.append(PDFReportSection(
                view: AnyView(entriesSection(entries[0..<entries.count])),
                rowInfo: .init(rowCount: entries.count, chromeOnly: AnyView(entriesSection(entries[0..<0])))
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
            Text("\(vehicleRef.engineType.refuelNounPlural) – \(vehicleRef.licensePlate)")
                .font(.title.bold())
            Text("\(selectedYear.map { "Jahr \($0)" } ?? "Alle Jahre") · Erstellt am \(FieldValidator.string(from: Date()))")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    /// Nimmt bewusst einen Zeilen-Ausschnitt statt immer aller Einträge
    /// entgegen: `sections` ruft dies zweimal auf (alle Zeilen für die
    /// Anzeige, null Zeilen zur Kopf-/Zeilenhöhen-Messung in
    /// `ReportPDFGenerator`).
    ///
    /// Feste Spaltenbreiten statt `Grid`: Ein `.background(...)` auf einer
    /// `GridRow` färbt nur die einzelnen Zellen, nicht die Zeile am Stück
    /// (Lücken zwischen den Spalten blieben ungefärbt) – für einen
    /// durchgehenden Zebra-Streifen braucht es eine echte `HStack`-Zeile mit
    /// `.frame(maxWidth: .infinity)`, auf die sich der Hintergrund als Ganzes
    /// legt.
    private func entriesSection(_ items: ArraySlice<FuelEntry>) -> some View {
        PDFReportCard {
            VStack(alignment: .leading, spacing: 0) {
                row(
                    Text("Datum"),
                    Text("km-Stand"),
                    Text("Menge"),
                    Text("Preis"),
                    Text("Betrag"),
                    Text(vehicleRef.engineType.stationLabel)
                )
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.bottom, 6)

                Divider()

                ForEach(Array(items.enumerated()), id: \.element.objectID) { index, entry in
                    row(
                        Text(FieldValidator.string(from: entry.date ?? Date())),
                        Text("\(entry.odometer) km"),
                        Text("\(DisplayFormatter.string(from: entry.liters?.decimalValue ?? 0, formatter: DisplayFormatter.decimal2)) \(vehicleRef.engineType.energyUnit)"),
                        Text(DisplayFormatter.pricePerLiterString(entry.pricePerLiter?.decimalValue ?? 0)),
                        Text(DisplayFormatter.currencyString(entry.amount?.decimalValue ?? 0)).bold(),
                        Text(entry.station ?? "–")
                    )
                    .font(.subheadline)
                    .padding(.vertical, 4)
                    // Zebra-Streifen für bessere Lesbarkeit bei vielen Zeilen.
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.gray.opacity(0.08))
                }
            }
        }
    }

    /// Eine Tabellenzeile mit sechs fest breiten Spalten – feste statt
    /// inhaltsabhängiger Breiten halten jede Zeile exakt gleich hoch
    /// (einzeilig durch `.lineLimit(1)`), was `ReportPDFGenerator`s
    /// Zeilenumbruch-Berechnung voraussetzt.
    private func row(
        _ date: Text,
        _ odometer: Text,
        _ amount: Text,
        _ price: Text,
        _ total: Text,
        _ station: Text
    ) -> some View {
        HStack(spacing: 12) {
            date.frame(width: 78, alignment: .leading)
            odometer.frame(width: 72, alignment: .trailing)
            amount.frame(width: 60, alignment: .trailing)
            price.frame(width: 60, alignment: .trailing)
            total.frame(width: 64, alignment: .trailing)
            station.frame(maxWidth: .infinity, alignment: .leading)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
