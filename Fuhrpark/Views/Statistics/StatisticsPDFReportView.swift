import SwiftUI

/// Druckfreundliche Darstellung des flottenweiten Statistikberichts für den
/// PDF-Export (siehe `ReportPDFGenerator`). Enthält bewusst nur die Karten
/// „Übersicht", „Kosten je Fahrzeug" und „Kosten pro Jahr" – das
/// Diagramm-Icon der Statistikseite hat hier kein Gegenstück, da im PDF
/// (wie beim Fahrzeugbericht) nur echte Seiteninhalte landen, keine nur in
/// eigenen Fenstern existierenden Diagramme.
struct StatisticsPDFReportView: View {
    let vehicleCount: Int
    let totalCost: Decimal
    let costPerVehicleList: [Vehicle]
    let costsByYear: [YearlyCost]

    /// Siehe `VehiclePDFReportView.sections` für die Begründung dieser
    /// Struktur (Grundlage für `ReportPDFGenerator`s Seitenumbruch-Logik).
    var sections: [PDFReportSection] {
        var result: [PDFReportSection] = [
            PDFReportSection(view: AnyView(reportHeader), rowInfo: nil),
            PDFReportSection(view: AnyView(overviewSection), rowInfo: nil)
        ]
        if !costPerVehicleList.isEmpty {
            result.append(PDFReportSection(
                view: AnyView(costPerVehicleSection(costPerVehicleList[0..<costPerVehicleList.count])),
                rowInfo: .init(rowCount: costPerVehicleList.count, chromeOnly: AnyView(costPerVehicleSection(costPerVehicleList[0..<0])))
            ))
        }
        if !costsByYear.isEmpty {
            result.append(PDFReportSection(
                view: AnyView(costPerYearSection(costsByYear[0..<costsByYear.count])),
                rowInfo: .init(rowCount: costsByYear.count, chromeOnly: AnyView(costPerYearSection(costsByYear[0..<0])))
            ))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PDFReportLayout.sectionSpacing) {
            ForEach(sections.indices, id: \.self) { sections[$0].view }
        }
        // Nur horizontal – oben/unten übernimmt `ReportPDFGenerator` den
        // Rand einheitlich auf JEDER Seite (siehe dort), nicht nur am
        // Anfang/Ende des Gesamtinhalts.
        .padding(.horizontal, PDFReportLayout.horizontalPadding)
        .frame(width: PDFReportLayout.pageWidth, alignment: .leading)
        .foregroundStyle(.black)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Statistikbericht")
                .font(.title.bold())
            Text("Erstellt am \(FieldValidator.string(from: Date()))")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    private var overviewSection: some View {
        PDFReportCard(title: "Übersicht") {
            HStack(alignment: .top, spacing: 16) {
                StatTile(title: "Fahrzeuge", value: "\(vehicleCount)", systemImage: "car.2.fill")
                Divider()
                StatTile(title: "Gesamtkosten", value: DisplayFormatter.costString(totalCost), systemImage: "sum")
            }
        }
    }

    /// Nimmt bewusst einen Zeilen-Ausschnitt statt immer aller Fahrzeuge
    /// entgegen: `sections` ruft dies zweimal auf (alle Zeilen für die
    /// Anzeige, null Zeilen zur Kopf-/Zeilenhöhen-Messung in
    /// `ReportPDFGenerator`).
    private func costPerVehicleSection(_ items: ArraySlice<Vehicle>) -> some View {
        PDFReportCard(title: "Kosten je Fahrzeug") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Fahrzeug")
                    Text("Betankungen").gridColumnAlignment(.trailing)
                    Text("Sonstige").gridColumnAlignment(.trailing)
                    Text("Gesamt").gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.gray)

                Divider()

                ForEach(items) { vehicle in
                    GridRow {
                        Text(vehicle.licensePlate ?? "")
                        Text(DisplayFormatter.currencyString(vehicle.totalFuelCost))
                        Text(DisplayFormatter.costString(vehicle.totalExpenseCost))
                        Text(DisplayFormatter.costString(vehicle.totalCost)).bold()
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func costPerYearSection(_ items: ArraySlice<YearlyCost>) -> some View {
        PDFReportCard(title: "Kosten pro Jahr") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Jahr")
                    Text("Betankungen").gridColumnAlignment(.trailing)
                    Text("Sonstige").gridColumnAlignment(.trailing)
                    Text("Gesamt").gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.gray)

                Divider()

                ForEach(items) { item in
                    GridRow {
                        Text(String(item.year))
                        Text(DisplayFormatter.currencyString(item.fuel))
                        Text(DisplayFormatter.costString(item.expense))
                        Text(DisplayFormatter.costString(item.total)).bold()
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}
