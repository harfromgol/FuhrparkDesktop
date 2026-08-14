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

    private static let pageWidth: CGFloat = 595.28 // A4 bei 72dpi

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportHeader
            headerStatsSection

            if !vehicle.sortedFuelEntries.isEmpty {
                fuelStatsSection
            }
            if !vehicle.sortedExpenses.isEmpty {
                expenseStatsSection
            }
            if enabledCards.contains(.consumption), !vehicle.sortedFuelEntries.isEmpty {
                consumptionSection
            }
            if enabledCards.contains(.price), !vehicle.sortedFuelEntries.isEmpty {
                priceSection
            }
            if enabledCards.contains(.expenseCategory), !vehicle.sortedExpenses.isEmpty {
                expenseCategorySection
            }
            if enabledCards.contains(.yearlyCost), !vehicle.costsByYear.isEmpty {
                yearlyCostSection
            }
            if enabledCards.contains(.yearlyDistance), !vehicle.kilometersByYear.isEmpty {
                kilometersByYearSection
            }
        }
        // Nur horizontal – oben/unten übernimmt `VehicleReportPDFGenerator`
        // den Rand einheitlich auf JEDER Seite (siehe dort), nicht nur am
        // Anfang/Ende des Gesamtinhalts.
        .padding(.horizontal, 24)
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
        ReportSection {
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
        ReportSection(title: "\(vehicle.engineType.refuelNounPlural) – Statistik") {
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
        ReportSection(title: "Sonstige Ausgaben – Statistik") {
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
        ReportSection(title: vehicle.engineType.priceTitle) {
            HStack(alignment: .top, spacing: 16) {
                StatTile(title: "Niedrigster", value: pricePerLiterString(vehicle.minPricePerLiter), systemImage: "arrow.down")
                StatTile(title: "Höchster", value: pricePerLiterString(vehicle.maxPricePerLiter), systemImage: "arrow.up")
                StatTile(title: "Durchschnitt", value: pricePerLiterString(vehicle.averagePricePerLiter), systemImage: "chart.bar")
            }
        }
    }

    private var consumptionSection: some View {
        ReportSection(title: "Verbrauch") {
            HStack(alignment: .top, spacing: 16) {
                StatTile(title: "Niedrigster", value: consumptionString(vehicle.minConsumption), systemImage: "arrow.down")
                StatTile(title: "Größter", value: consumptionString(vehicle.maxConsumption), systemImage: "arrow.up")
                StatTile(title: "Durchschnitt", value: consumptionString(vehicle.averageConsumption), systemImage: "chart.bar")
            }
        }
    }

    private var expenseCategorySection: some View {
        ReportSection(title: "Gesamtkosten pro Kategorie") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Kategorie")
                    Text("Betrag").gridColumnAlignment(.trailing)
                    Text("Anteil").gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.gray)

                Divider()

                ForEach(vehicle.expenseCostByCategory, id: \.category) { item in
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

    private var yearlyCostSection: some View {
        ReportSection(title: "Kosten pro Jahr") {
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

                ForEach(vehicle.costsByYear) { item in
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

    private var kilometersByYearSection: some View {
        ReportSection(title: "Gefahrene km pro Jahr") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Jahr")
                    Text("km").gridColumnAlignment(.trailing)
                    Text("Tachostand").gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.gray)

                Divider()

                ForEach(vehicle.kilometersByYear) { item in
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
private struct ReportSection<Content: View>: View {
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.35)))
    }
}
