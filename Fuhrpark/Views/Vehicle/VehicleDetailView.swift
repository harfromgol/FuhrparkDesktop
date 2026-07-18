import SwiftUI

struct VehicleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var vehicle: Vehicle

    @State private var isPresentingNewFuelEntry = false
    @State private var isPresentingNewExpense = false

    private var vehicleRef: VehicleRef? {
        guard let id = vehicle.id else { return nil }
        return VehicleRef(id: id, licensePlate: vehicle.licensePlate ?? "", engineType: vehicle.engineType)
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    sectionHeader(title: vehicle.engineType.refuelNounPlural, systemImage: "fuelpump.fill") {
                        if !vehicle.decommissioned {
                            Button(vehicle.engineType.newRefuelTitle, systemImage: "plus") {
                                isPresentingNewFuelEntry = true
                            }
                            .buttonStyle(.glass)
                            .pointerStyle(.link)
                        }
                        if !vehicle.sortedFuelEntries.isEmpty {
                            Button("Liste anzeigen", systemImage: "list.bullet") {
                                if let vehicleRef {
                                    openWindow(id: "fuel-list", value: vehicleRef)
                                }
                            }
                            .buttonStyle(.glass)
                            .pointerStyle(.link)
                        }
                    }

                    if vehicle.sortedFuelEntries.isEmpty {
                        Text("Noch keine \(vehicle.engineType.refuelNounPlural) erfasst.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        fuelStatistics
                    }

                    sectionHeader(title: "Sonstige Ausgaben", systemImage: "eurosign.circle.fill") {
                        if !vehicle.decommissioned {
                            Button("Neue Ausgabe", systemImage: "plus") {
                                isPresentingNewExpense = true
                            }
                            .buttonStyle(.glass)
                            .pointerStyle(.link)
                        }
                        if !vehicle.sortedExpenses.isEmpty {
                            Button("Liste anzeigen", systemImage: "list.bullet") {
                                if let vehicleRef {
                                    openWindow(id: "expense-list", value: vehicleRef)
                                }
                            }
                            .buttonStyle(.glass)
                            .pointerStyle(.link)
                        }
                    }

                    if vehicle.sortedExpenses.isEmpty {
                        Text("Noch keine Ausgaben erfasst.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        expenseStatistics
                    }

                    sectionHeader(title: "Statistik", systemImage: "chart.bar.xaxis") { }

                    if vehicle.sortedFuelEntries.isEmpty && vehicle.sortedExpenses.isEmpty {
                        Text("Noch keine \(vehicle.engineType.refuelNounPlural) oder sonstigen Ausgaben erfasst.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        if !vehicle.sortedFuelEntries.isEmpty {
                            consumptionStatistics
                            priceStatistics
                        }

                        if !vehicle.sortedExpenses.isEmpty {
                            expenseCategoryStatistics
                        }

                        if !vehicle.costsByYear.isEmpty {
                            yearlyCostStatistics
                        }

                        if !vehicle.kilometersByYear.isEmpty {
                            kilometersByYearStatistics
                        }
                    }
                }
                .padding(20)
            }
        }
        // Generischer Fenstertitel statt des Kennzeichens: Das Kennzeichen steht
        // bereits in der Header-Karte, so wird die Dopplung vermieden.
        .navigationTitle("Fahrzeugdetails")
        .sheet(isPresented: $isPresentingNewFuelEntry) {
            FuelEntryFormView(vehicle: vehicle)
        }
        .sheet(isPresented: $isPresentingNewExpense) {
            ExpenseFormView(vehicle: vehicle)
        }
    }

    private var header: some View {
        GlassCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.licensePlate ?? "")
                        .font(.title2.bold())
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .foregroundStyle(.secondary)
                    Text("\(vehicle.odometer) km · \(vehicle.engineType.displayName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if vehicle.decommissioned {
                    DecommissionedBadge(showsIcon: true)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 16) {
                StatTile(
                    title: "km-Stand",
                    value: "\(DisplayFormatter.odometerString(vehicle.highestOdometer)) km",
                    systemImage: "speedometer"
                )
                Divider()
                StatTile(
                    title: "Kosten / km",
                    value: vehicle.costPerKilometer.map { DisplayFormatter.costString($0) } ?? "–",
                    systemImage: "gauge.with.dots.needle.bottom.50percent",
                    subtitle: vehicle.drivenKilometers.map { "\($0) km gefahren" } ?? "keine Fahrleistung erfasst"
                )
                Divider()
                StatTile(
                    title: "Gesamtkosten",
                    value: DisplayFormatter.costString(vehicle.totalCost),
                    systemImage: "sum"
                )
            }
        }
    }

    private var fuelStatistics: some View {
        GlassCard(title: "\(vehicle.engineType.refuelNounPlural) – Statistik") {
            HStack(alignment: .top, spacing: 16) {
                StatTile(
                    title: "Anzahl",
                    value: "\(vehicle.fuelEntryCount)",
                    systemImage: "number"
                )
                Divider()
                StatTile(
                    title: vehicle.engineType.lastRefuelLabel,
                    value: vehicle.lastFuelDate.map { FieldValidator.string(from: $0) } ?? "–",
                    systemImage: "calendar"
                )
                Divider()
                StatTile(
                    title: vehicle.engineType.totalEnergyLabel,
                    value: "\(DisplayFormatter.string(from: vehicle.totalLiters, formatter: DisplayFormatter.decimal2)) \(vehicle.engineType.energyUnit)",
                    systemImage: "drop.fill"
                )
                Divider()
                StatTile(
                    title: vehicle.engineType.energyCostLabel,
                    value: DisplayFormatter.currencyString(vehicle.totalFuelCost),
                    systemImage: "eurosign"
                )
            }
        }
    }

    private var priceStatistics: some View {
        GlassCard {
            HStack {
                Text(vehicle.engineType.priceTitle)
                    .font(.headline)
                Spacer()
                if vehicle.fuelEntryCount >= 2, let vehicleRef {
                    Button {
                        openWindow(id: "price-chart", value: vehicleRef)
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .pointerStyle(.link)
                    .help("\(vehicle.engineType.priceTitle)-Verlauf anzeigen")
                }
            }
            HStack(alignment: .top, spacing: 16) {
                StatTile(
                    title: "Niedrigster",
                    value: pricePerLiterString(vehicle.minPricePerLiter),
                    systemImage: "arrow.down"
                )
                Divider()
                StatTile(
                    title: "Höchster",
                    value: pricePerLiterString(vehicle.maxPricePerLiter),
                    systemImage: "arrow.up"
                )
                Divider()
                StatTile(
                    title: "Durchschnitt",
                    value: pricePerLiterString(vehicle.averagePricePerLiter),
                    systemImage: "chart.bar"
                )
            }
        }
    }

    private var consumptionStatistics: some View {
        GlassCard {
            HStack {
                Text("Verbrauch")
                    .font(.headline)
                Spacer()
                if vehicle.consumptionCount >= 2, let vehicleRef {
                    Button {
                        openWindow(id: "consumption-chart", value: vehicleRef)
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .pointerStyle(.link)
                    .help("Verbrauch-Verlauf anzeigen")
                }
            }
            HStack(alignment: .top, spacing: 16) {
                StatTile(
                    title: "Niedrigster",
                    value: consumptionString(vehicle.minConsumption),
                    systemImage: "arrow.down"
                )
                Divider()
                StatTile(
                    title: "Größter",
                    value: consumptionString(vehicle.maxConsumption),
                    systemImage: "arrow.up"
                )
                Divider()
                StatTile(
                    title: "Durchschnitt",
                    value: consumptionString(vehicle.averageConsumption),
                    systemImage: "chart.bar"
                )
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

    private var expenseStatistics: some View {
        GlassCard(title: "Sonstige Ausgaben – Statistik") {
            HStack(alignment: .top, spacing: 16) {
                StatTile(
                    title: "Anzahl",
                    value: "\(vehicle.expenseCount)",
                    systemImage: "number"
                )
                Divider()
                StatTile(
                    title: "Letzte Buchung",
                    value: vehicle.lastExpenseDate.map { FieldValidator.string(from: $0) } ?? "–",
                    systemImage: "calendar"
                )
                Divider()
                StatTile(
                    title: "Gesamtkosten",
                    value: DisplayFormatter.costString(vehicle.totalExpenseCost),
                    systemImage: "eurosign"
                )
            }
        }
    }

    private var expenseCategoryStatistics: some View {
        GlassCard(title: "Gesamtkosten pro Kategorie") {
            VStack(spacing: 8) {
                ForEach(vehicle.expenseCostByCategory, id: \.category) { item in
                    HStack {
                        Text(item.category)
                        Spacer()
                        Text(DisplayFormatter.costString(item.total))
                            .bold()
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var yearlyCostStatistics: some View {
        GlassCard(title: "Kosten pro Jahr") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Jahr")
                    Text("Betankungen").gridColumnAlignment(.trailing)
                    Text("Sonstige").gridColumnAlignment(.trailing)
                    Text("Gesamt").gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                ForEach(vehicle.costsByYear) { item in
                    GridRow {
                        Text(String(item.year))
                        Text(DisplayFormatter.currencyString(item.fuel))
                        Text(DisplayFormatter.costString(item.expense))
                        Text(DisplayFormatter.costString(item.total))
                            .bold()
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    /// Gefahrene Kilometer je Kalenderjahr, aus den umgebenden Betankungen
    /// zum jeweiligen Jahreswechsel interpoliert (siehe
    /// `Vehicle.kilometersByYear`). Jahre ohne ermittelbaren Start- oder
    /// End-Kilometerstand (z. B. ein zukünftiges Jahr ohne jede Betankung)
    /// fehlen dort bereits, statt mit einem Platzhalter angezeigt zu werden.
    private var kilometersByYearStatistics: some View {
        GlassCard {
            HStack {
                Text("Gefahrene km pro Jahr")
                    .font(.headline)
                Spacer()
                if vehicle.kilometersByYear.count >= 2, let vehicleRef {
                    Button {
                        openWindow(id: "distance-chart", value: vehicleRef)
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .pointerStyle(.link)
                    .help("Gefahrene km pro Jahr – Verlauf anzeigen")
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Jahr")
                    Text("km").gridColumnAlignment(.trailing)
                    Text("Tachostand").gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                ForEach(vehicle.kilometersByYear) { item in
                    GridRow {
                        Text(String(item.year))
                        Text("\(DisplayFormatter.odometerString(item.kilometers)) km")
                            .bold()
                        Text("\(DisplayFormatter.odometerString(item.odometerAtYearEnd)) km")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func sectionHeader<Buttons: View>(
        title: String,
        systemImage: String,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Self.sectionHeaderColor)
            Spacer()
            buttons()
        }
    }

    /// Akzentfarbe der Abschnitts-Überschriften (Icon + Titel). Licht-/dunkeladaptiv.
    private static let sectionHeaderColor = Color.orange
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let vehicle = (try! context.fetch(Vehicle.fetchRequest()) as! [Vehicle]).first!
    return VehicleDetailView(vehicle: vehicle)
        .environment(\.managedObjectContext, context)
}
