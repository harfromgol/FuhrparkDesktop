import SwiftUI

/// Druckfreundliche Darstellung des Fahrzeugberichts für den PDF-Export
/// (siehe `VehicleReportPDFGenerator`). Bewusst getrennt von
/// `VehicleDetailView`: Liquid-Glass-Karten (`GlassCard`) rendern in einem
/// Offscreen-PDF-Kontext nicht sinnvoll und wären für ein Druck-/
/// Archivdokument ohnehin unpassend – hier daher feste, helle
/// Schwarz-auf-Weiß-Darstellung ohne jede Interaktion (keine Buttons, Menüs
/// oder Diagramm-Links).
struct VehiclePDFReportView: View {
    let vehicle: Vehicle
    let enabledCards: Set<StatisticsCard>

    static let pageWidth: CGFloat = 595.28 // A4 bei 72dpi
    private static let horizontalPadding: CGFloat = 24
    /// Breite, mit der `VehicleReportPDFGenerator` jeden Abschnitt einzeln
    /// vermisst – muss der tatsächlichen Breite innerhalb der Padding-VStack
    /// entsprechen, sonst weichen Einzel- und Gesamtmessung voneinander ab.
    static let contentWidth = pageWidth - horizontalPadding * 2
    /// Muss mit dem `spacing` der VStack unten übereinstimmen – wird für die
    /// Seitenumbruch-Berechnung in `VehicleReportPDFGenerator` gebraucht.
    static let sectionSpacing: CGFloat = 16
    /// Inneres Padding von `ReportCard` – wird für die Zeilenumbruch-
    /// Berechnung in `VehicleReportPDFGenerator` gebraucht: eine isoliert
    /// (mit 0 Zeilen) vermessene Karte enthält dieses Padding direkt nach
    /// dem Titel/Spaltenköpfen, in der echten Karte mit Zeilen sitzt es
    /// aber erst nach der letzten Zeile. Ohne Korrektur um genau dieses
    /// Padding würde jeder berechnete Zeilenumbruch zu weit in den Inhalt
    /// hineinragen (siehe `VehicleReportPDFGenerator.pageStartOffsets`).
    static let cardPadding: CGFloat = 14

    /// Ein Abschnitt für die Seitenumbruch-Berechnung in
    /// `VehicleReportPDFGenerator`: die Ansicht selbst (immer mit allen
    /// Zeilen, wie im Bericht sichtbar) sowie – nur bei Tabellen-Karten mit
    /// unterschiedlich vielen Zeilen (Kategorien/Jahre) – zusätzliche
    /// Zeileninformationen, damit ein Umbruch nötigenfalls an einer
    /// Zeilengrenze INNERHALB der Karte gesetzt werden kann, statt nur an
    /// der Kartengrenze. Ohne das könnte eine Karte, die durch viele Jahre/
    /// Kategorien höher als eine Seite wird, mitten in einer Zeile
    /// zerschnitten werden.
    struct ReportSection {
        let view: AnyView
        let rowInfo: RowInfo?

        struct RowInfo {
            let rowCount: Int
            /// Dieselbe Karte, aber mit null Zeilen – für die separate
            /// Messung von Kopf- (Titel/Spaltenköpfe) vs. Zeilenhöhe.
            let chromeOnly: AnyView
        }
    }

    /// Alle sichtbaren Abschnitte in Reihenfolge. Als eigene, von außen
    /// lesbare Liste (statt eines direkt in `body` verschachtelten
    /// `if`-Blocks), damit `VehicleReportPDFGenerator` jeden Abschnitt
    /// einzeln vermessen und Seitenumbrüche setzen kann, ohne eine Karte
    /// oder Zeile mittendrin zu zerschneiden.
    var sections: [ReportSection] {
        var result: [ReportSection] = [
            ReportSection(view: AnyView(reportHeader), rowInfo: nil),
            ReportSection(view: AnyView(headerStatsSection), rowInfo: nil)
        ]
        if !vehicle.sortedFuelEntries.isEmpty {
            result.append(ReportSection(view: AnyView(fuelStatsSection), rowInfo: nil))
        }
        if !vehicle.sortedExpenses.isEmpty {
            result.append(ReportSection(view: AnyView(expenseStatsSection), rowInfo: nil))
        }
        if enabledCards.contains(.consumption), !vehicle.sortedFuelEntries.isEmpty {
            result.append(ReportSection(view: AnyView(consumptionSection), rowInfo: nil))
        }
        if enabledCards.contains(.price), !vehicle.sortedFuelEntries.isEmpty {
            result.append(ReportSection(view: AnyView(priceSection), rowInfo: nil))
        }
        if enabledCards.contains(.expenseCategory), !vehicle.sortedExpenses.isEmpty {
            let items = vehicle.expenseCostByCategory
            result.append(ReportSection(
                view: AnyView(expenseCategorySection(items[0..<items.count])),
                rowInfo: .init(rowCount: items.count, chromeOnly: AnyView(expenseCategorySection(items[0..<0])))
            ))
        }
        if enabledCards.contains(.yearlyCost), !vehicle.costsByYear.isEmpty {
            let items = vehicle.costsByYear
            result.append(ReportSection(
                view: AnyView(yearlyCostSection(items[0..<items.count])),
                rowInfo: .init(rowCount: items.count, chromeOnly: AnyView(yearlyCostSection(items[0..<0])))
            ))
        }
        if enabledCards.contains(.yearlyDistance), !vehicle.kilometersByYear.isEmpty {
            let items = vehicle.kilometersByYear
            result.append(ReportSection(
                view: AnyView(kilometersByYearSection(items[0..<items.count])),
                rowInfo: .init(rowCount: items.count, chromeOnly: AnyView(kilometersByYearSection(items[0..<0])))
            ))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            ForEach(sections.indices, id: \.self) { sections[$0].view }
        }
        // Nur horizontal – oben/unten übernimmt `VehicleReportPDFGenerator`
        // den Rand einheitlich auf JEDER Seite (siehe dort), nicht nur am
        // Anfang/Ende des Gesamtinhalts.
        .padding(.horizontal, Self.horizontalPadding)
        .frame(width: Self.pageWidth, alignment: .leading)
        .foregroundStyle(.black)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Fahrzeugbericht")
                .font(.title.bold())
            Text("Erstellt am \(FieldValidator.string(from: Date()))")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    private var headerStatsSection: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.licensePlate ?? "")
                    .font(.title2.bold())
                Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                    .foregroundStyle(.gray)
                Text("\(vehicle.odometer) km · \(vehicle.engineType.displayName)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Divider()

            HStack(alignment: .top, spacing: 16) {
                StatTile(
                    title: "km-Stand",
                    value: "\(DisplayFormatter.odometerString(vehicle.highestOdometer)) km",
                    systemImage: "speedometer"
                )
                StatTile(
                    title: "Kosten / km",
                    value: vehicle.costPerKilometer.map { DisplayFormatter.costString($0) } ?? "–",
                    systemImage: "gauge.with.dots.needle.bottom.50percent",
                    subtitle: vehicle.drivenKilometers.map { "\($0) km gefahren" } ?? "keine Fahrleistung erfasst"
                )
                StatTile(
                    title: "Gesamtkosten",
                    value: DisplayFormatter.costString(vehicle.totalCost),
                    systemImage: "sum"
                )
            }
        }
    }

    private var fuelStatsSection: some View {
        ReportCard(title: "\(vehicle.engineType.refuelNounPlural) – Statistik") {
            HStack(alignment: .top, spacing: 16) {
                StatTile(title: "Anzahl", value: "\(vehicle.fuelEntryCount)", systemImage: "number")
                StatTile(
                    title: vehicle.engineType.lastRefuelLabel,
                    value: vehicle.lastFuelDate.map { FieldValidator.string(from: $0) } ?? "–",
                    systemImage: "calendar"
                )
                StatTile(
                    title: vehicle.engineType.totalEnergyLabel,
                    value: "\(DisplayFormatter.string(from: vehicle.totalLiters, formatter: DisplayFormatter.decimal2)) \(vehicle.engineType.energyUnit)",
                    systemImage: "drop.fill"
                )
                StatTile(
                    title: vehicle.engineType.energyCostLabel,
                    value: DisplayFormatter.currencyString(vehicle.totalFuelCost),
                    systemImage: "eurosign"
                )
            }
        }
    }

    private var expenseStatsSection: some View {
        ReportCard(title: "Sonstige Ausgaben – Statistik") {
            HStack(alignment: .top, spacing: 16) {
                StatTile(title: "Anzahl", value: "\(vehicle.expenseCount)", systemImage: "number")
                StatTile(
                    title: "Letzte Buchung",
                    value: vehicle.lastExpenseDate.map { FieldValidator.string(from: $0) } ?? "–",
                    systemImage: "calendar"
                )
                StatTile(
                    title: "Gesamtkosten",
                    value: DisplayFormatter.costString(vehicle.totalExpenseCost),
                    systemImage: "eurosign"
                )
            }
        }
    }

    private var priceSection: some View {
        ReportCard(title: vehicle.engineType.priceTitle) {
            HStack(alignment: .top, spacing: 16) {
                StatTile(title: "Niedrigster", value: pricePerLiterString(vehicle.minPricePerLiter), systemImage: "arrow.down")
                StatTile(title: "Höchster", value: pricePerLiterString(vehicle.maxPricePerLiter), systemImage: "arrow.up")
                StatTile(title: "Durchschnitt", value: pricePerLiterString(vehicle.averagePricePerLiter), systemImage: "chart.bar")
            }
        }
    }

    private var consumptionSection: some View {
        ReportCard(title: "Verbrauch") {
            HStack(alignment: .top, spacing: 16) {
                StatTile(title: "Niedrigster", value: consumptionString(vehicle.minConsumption), systemImage: "arrow.down")
                StatTile(title: "Größter", value: consumptionString(vehicle.maxConsumption), systemImage: "arrow.up")
                StatTile(title: "Durchschnitt", value: consumptionString(vehicle.averageConsumption), systemImage: "chart.bar")
            }
        }
    }

    /// Nimmt bewusst einen Zeilen-Ausschnitt statt immer aller Kategorien
    /// entgegen: `sections` ruft dies zweimal auf (alle Zeilen für die
    /// Anzeige, null Zeilen zur Kopf-/Zeilenhöhen-Messung in
    /// `VehicleReportPDFGenerator`).
    private func expenseCategorySection(_ items: ArraySlice<(category: String, total: Decimal)>) -> some View {
        ReportCard(title: "Gesamtkosten pro Kategorie") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Kategorie")
                    Text("Betrag").gridColumnAlignment(.trailing)
                    Text("Anteil").gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.gray)

                Divider()

                ForEach(items, id: \.category) { item in
                    GridRow {
                        Text(item.category)
                        Text(DisplayFormatter.costString(item.total)).bold()
                        Text(categoryShareString(item.total)).foregroundStyle(.gray)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func yearlyCostSection(_ items: ArraySlice<YearlyCost>) -> some View {
        ReportCard(title: "Kosten pro Jahr") {
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

    private func kilometersByYearSection(_ items: ArraySlice<YearlyDistance>) -> some View {
        ReportCard(title: "Gefahrene km pro Jahr") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Jahr")
                    Text("km").gridColumnAlignment(.trailing)
                    Text("Tachostand").gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.gray)

                Divider()

                ForEach(items) { item in
                    GridRow {
                        Text(String(item.year))
                        Text("\(DisplayFormatter.odometerString(item.kilometers)) km").bold()
                        Text("\(DisplayFormatter.odometerString(item.odometerAtYearEnd)) km").foregroundStyle(.gray)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func pricePerLiterString(_ value: Decimal?) -> String {
        guard let value else { return "–" }
        return "\(DisplayFormatter.pricePerLiterString(value))\(vehicle.engineType.pricePerUnitSuffix)"
    }

    private func consumptionString(_ value: Double?) -> String {
        guard let value else { return "–" }
        return "\(DisplayFormatter.string(from: Decimal(value), formatter: DisplayFormatter.consumption)) \(vehicle.engineType.consumptionUnit)"
    }

    /// Anteil eines Kategorie-Betrags an den Gesamtkosten (Betankungen +
    /// sonstige Ausgaben, siehe `vehicle.totalCost`) – wie in `VehicleDetailView`.
    private func categoryShareString(_ total: Decimal) -> String {
        guard vehicle.totalCost > 0 else { return "–" }
        return DisplayFormatter.percentString(total / vehicle.totalCost)
    }
}

/// Einfacher, gerahmter Abschnitt ohne Liquid Glass – das druckfreundliche
/// Gegenstück zu `GlassCard`.
private struct ReportCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(VehiclePDFReportView.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.35)))
    }
}
