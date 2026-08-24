import SwiftUI

struct VehicleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var vehicle: Vehicle
    /// Wird nach dem Löschen dieses Fahrzeugs aufgerufen, damit der Aufrufer
    /// (`ContentView`) die Auswahl von diesem (jetzt ungültigen) Fahrzeug weg
    /// zurücksetzen kann.
    let onDelete: () -> Void

    @State private var isPresentingNewFuelEntry = false
    @State private var isPresentingNewExpense = false
    @State private var isPresentingCardConfig = false
    @State private var isPresentingEditVehicle = false
    @State private var vehiclePendingDeletion: Vehicle?
    @State private var vehiclePendingDecommission: Vehicle?
    @State private var pdfExportErrorMessage: String?
    /// Spaltensortierung der drei Statistiktabellen, global für alle
    /// Fahrzeuge aus den UserDefaults vorbelegt (siehe `TableSortStore`).
    @State private var expenseCategorySort = TableSort<ExpenseCategorySortColumn>.initial(for: .expenseCategory)
    @State private var yearlyCostSort = TableSort<YearlyCostSortColumn>.initial(for: .yearlyCost)
    @State private var yearlyDistanceSort = TableSort<YearlyDistanceSortColumn>.initial(for: .yearlyDistance)
    /// Anordnung/Größe des Fahrzeugbilds, global aus den UserDefaults
    /// vorbelegt (siehe `VehiclePhotoLayoutStore`), umschaltbar per
    /// Rechtsklick-Kontextmenü auf dem Bild selbst (`VehiclePhotoAvatar`).
    @State private var photoLayout = VehiclePhotoLayoutStore.layout()
    @State private var photoTopSize = VehiclePhotoLayoutStore.topSize()
    /// Welche der optionalen Statistik-Karten sichtbar sind, aus den
    /// UserDefaults vorbelegt (siehe `StatisticsCardVisibilityStore`). Wird
    /// je Fahrzeug separat gespeichert; da diese View pro Fahrzeug neu
    /// erzeugt wird (`.id(vehicle.objectID)` in ContentView), lädt `init`
    /// hier automatisch den richtigen Stand.
    @State private var enabledCards: Set<StatisticsCard>

    init(vehicle: Vehicle, onDelete: @escaping () -> Void) {
        self.vehicle = vehicle
        self.onDelete = onDelete
        _enabledCards = State(initialValue: vehicle.id.map(StatisticsCardVisibilityStore.enabledCards(for:)) ?? Set(StatisticsCard.allCases))
    }

    private var vehicleRef: VehicleRef? {
        guard let id = vehicle.id else { return nil }
        return VehicleRef(id: id, licensePlate: vehicle.licensePlate ?? "", engineType: vehicle.engineType)
    }

    /// Anordnung/Größe des Fahrzeugbilds, sofort persistiert – gebunden an
    /// das Kontextmenü in `VehiclePhotoAvatar`.
    private var photoLayoutBinding: Binding<VehiclePhotoLayout> {
        Binding(
            get: { photoLayout },
            set: { newValue in
                photoLayout = newValue
                VehiclePhotoLayoutStore.setLayout(newValue)
            }
        )
    }

    private var photoTopSizeBinding: Binding<Int> {
        Binding(
            get: { photoTopSize },
            set: { newValue in
                photoTopSize = newValue
                VehiclePhotoLayoutStore.setTopSize(newValue)
            }
        )
    }

    /// Ein-/Ausschalten einer Statistik-Karte, sofort persistiert.
    private func cardBinding(_ card: StatisticsCard) -> Binding<Bool> {
        Binding(
            get: { enabledCards.contains(card) },
            set: { isOn in
                if isOn { enabledCards.insert(card) } else { enabledCards.remove(card) }
                if let id = vehicle.id {
                    StatisticsCardVisibilityStore.setEnabledCards(enabledCards, for: id)
                }
            }
        )
    }

    private func cardTitle(_ card: StatisticsCard) -> String {
        switch card {
        case .consumption: return "Verbrauch"
        case .price: return vehicle.engineType.priceTitle
        case .expenseCategory: return "Gesamtkosten pro Kategorie"
        case .yearlyCost: return "Kosten pro Jahr"
        case .yearlyDistance: return "Gefahrene km pro Jahr"
        }
    }

    private var cardVisibilityPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sichtbare Statistiken")
                .font(.headline)
            ForEach(StatisticsCard.allCases) { card in
                Toggle(cardTitle(card), isOn: cardBinding(card))
                    .toggleStyle(.checkbox)
            }
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 20) {
                    if photoLayout == .top {
                        let size = VehiclePhotoLayoutStore.topSizePoints(photoTopSize)
                        VehiclePhotoAvatar(vehicle: vehicle, layout: photoLayoutBinding, topSize: photoTopSizeBinding)
                            .frame(width: size, height: size)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

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
                        Button("Neue Ausgabe", systemImage: "plus") {
                            isPresentingNewExpense = true
                        }
                        .buttonStyle(.glass)
                        .pointerStyle(.link)
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

                    sectionHeader(title: "Statistik", systemImage: "chart.bar.xaxis") {
                        Button {
                            isPresentingCardConfig = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(.borderless)
                        .pointerStyle(.link)
                        .help("Sichtbare Statistiken konfigurieren")
                        .popover(isPresented: $isPresentingCardConfig) {
                            cardVisibilityPopover
                        }
                    }

                    if vehicle.sortedFuelEntries.isEmpty && vehicle.sortedExpenses.isEmpty {
                        Text("Noch keine \(vehicle.engineType.refuelNounPlural) oder sonstigen Ausgaben erfasst.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if enabledCards.isEmpty {
                        Text("Alle Statistik-Karten sind ausgeblendet. Über das Zahnrad-Symbol oben können sie wieder eingeblendet werden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        if !vehicle.sortedFuelEntries.isEmpty {
                            if enabledCards.contains(.consumption) {
                                consumptionStatistics
                            }
                            if enabledCards.contains(.price) {
                                priceStatistics
                            }
                        }

                        if !vehicle.sortedExpenses.isEmpty && enabledCards.contains(.expenseCategory) {
                            expenseCategoryStatistics
                        }

                        if !vehicle.costsByYear.isEmpty && enabledCards.contains(.yearlyCost) {
                            yearlyCostStatistics
                        }

                        if !vehicle.kilometersByYear.isEmpty && enabledCards.contains(.yearlyDistance) {
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
        .sheet(isPresented: $isPresentingEditVehicle) {
            VehicleFormView(vehicleToEdit: vehicle)
        }
        .alert(
            "PDF-Erstellung fehlgeschlagen",
            isPresented: Binding(
                get: { pdfExportErrorMessage != nil },
                set: { if !$0 { pdfExportErrorMessage = nil } }
            ),
            presenting: pdfExportErrorMessage
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .modifier(VehicleConfirmationModifier(
            pending: $vehiclePendingDeletion,
            title: "Fahrzeug wirklich löschen?",
            actionLabel: "Löschen",
            actionRole: .destructive,
            message: { "„\($0.licensePlate ?? "")“ und alle zugehörigen \($0.engineType.refuelNounPlural), Ausgaben und Erinnerungen werden unwiderruflich gelöscht." },
            action: delete
        ))
        .modifier(VehicleConfirmationModifier(
            pending: $vehiclePendingDecommission,
            title: "Fahrzeug wirklich stilllegen?",
            actionLabel: "Stilllegen",
            actionRole: nil,
            message: { "„\($0.licensePlate ?? "")“ wird als stillgelegt (verschrottet oder verkauft) markiert. Danach können keine \($0.engineType.refuelNounPlural) mehr erfasst werden. Dieser Schritt ist endgültig, eine Reaktivierung ist nicht möglich." },
            action: decommission
        ))
    }

    private func exportPDF() {
        do {
            let reportView = VehiclePDFReportView(vehicle: vehicle, enabledCards: enabledCards)
            let url = try ReportPDFGenerator.generate(
                reportView,
                sections: reportView.sections,
                filenamePrefix: vehicle.licensePlate ?? "Fahrzeug"
            )
            Task {
                do {
                    try await ReportPDFGenerator.openInPreview(url)
                } catch {
                    pdfExportErrorMessage = error.localizedDescription
                }
            }
        } catch {
            pdfExportErrorMessage = error.localizedDescription
        }
    }

    private func delete(_ vehicle: Vehicle) {
        onDelete()
        vehicle.delete(in: viewContext)
    }

    private func decommission(_ vehicle: Vehicle) {
        vehicle.decommission(in: viewContext)
    }

    private var header: some View {
        GlassCard {
            HStack(alignment: .top) {
                if photoLayout == .side {
                    VehiclePhotoAvatar(vehicle: vehicle, layout: photoLayoutBinding, topSize: photoTopSizeBinding)
                        .frame(width: 60, height: 60)
                }
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
                Menu {
                    Button("Stilllegen") { vehiclePendingDecommission = vehicle }
                        .disabled(vehicle.decommissioned)
                    Divider()
                    Button("Bearbeiten") { isPresentingEditVehicle = true }
                    Button("Löschen", role: .destructive) { vehiclePendingDeletion = vehicle }
                    Divider()
                    Button("PDF-Export") { exportPDF() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .pointerStyle(.link)
                .help("Weitere Aktionen")
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
        GlassCard {
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
        GlassCard {
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

    /// `vehicle.expenseCostByCategory`, umsortiert nach der vom Nutzer
    /// gewählten Spalte (`expenseCategorySort`). „Anteil" nutzt denselben
    /// Vergleich wie „Betrag", da er monoton daraus abgeleitet ist.
    private var sortedExpenseCategoryStatistics: [(category: String, total: Decimal)] {
        let items = vehicle.expenseCostByCategory
        let ascending = expenseCategorySort.ascending
        switch expenseCategorySort.column {
        case .category:
            return items.sorted { ascending ? $0.category < $1.category : $0.category > $1.category }
        case .total, .share:
            return items.sorted { ascending ? $0.total < $1.total : $0.total > $1.total }
        }
    }

    private var expenseCategoryStatistics: some View {
        let isSortable = vehicle.expenseCostByCategory.count >= 2
        return GlassCard {
            HStack {
                Text("Gesamtkosten pro Kategorie")
                    .font(.headline)
                Spacer()
                if isSortable, let vehicleRef {
                    Button {
                        openWindow(id: "category-chart", value: vehicleRef)
                    } label: {
                        Image(systemName: "chart.pie")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .pointerStyle(.link)
                    .help("Gesamtkosten pro Kategorie – Diagramm anzeigen")
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    SortHeaderCell(
                        title: "Kategorie",
                        isActive: expenseCategorySort.isActive(.category),
                        ascending: expenseCategorySort.ascending,
                        isEnabled: isSortable
                    ) { expenseCategorySort.select(.category) }
                    SortHeaderCell(
                        title: "Betrag",
                        isActive: expenseCategorySort.isActive(.total),
                        ascending: expenseCategorySort.ascending,
                        isEnabled: isSortable
                    ) { expenseCategorySort.select(.total) }
                    .gridColumnAlignment(.trailing)
                    SortHeaderCell(
                        title: "Anteil",
                        isActive: expenseCategorySort.isActive(.share),
                        ascending: expenseCategorySort.ascending,
                        isEnabled: isSortable
                    ) { expenseCategorySort.select(.share) }
                    .gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                ForEach(sortedExpenseCategoryStatistics, id: \.category) { item in
                    GridRow {
                        Text(item.category)
                        Text(DisplayFormatter.costString(item.total))
                            .bold()
                        Text(categoryShareString(item.total))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    /// Anteil eines Kategorie-Betrags an den Gesamtkosten des Fahrzeugs
    /// (Betankungen + sonstige Ausgaben, siehe `header`/`vehicle.totalCost`).
    private func categoryShareString(_ total: Decimal) -> String {
        guard vehicle.totalCost > 0 else { return "–" }
        return DisplayFormatter.percentString(total / vehicle.totalCost)
    }

    private var sortedYearlyCostStatistics: [YearlyCost] {
        let items = vehicle.costsByYear
        let ascending = yearlyCostSort.ascending
        switch yearlyCostSort.column {
        case .year:
            return items.sorted { ascending ? $0.year < $1.year : $0.year > $1.year }
        case .fuel:
            return items.sorted { ascending ? $0.fuel < $1.fuel : $0.fuel > $1.fuel }
        case .expense:
            return items.sorted { ascending ? $0.expense < $1.expense : $0.expense > $1.expense }
        case .total:
            return items.sorted { ascending ? $0.total < $1.total : $0.total > $1.total }
        }
    }

    private var yearlyCostStatistics: some View {
        let isSortable = vehicle.costsByYear.count >= 2
        return GlassCard {
            HStack {
                Text("Kosten pro Jahr")
                    .font(.headline)
                Spacer()
                if isSortable, let vehicleRef {
                    Button {
                        openWindow(id: "yearly-cost-chart", value: vehicleRef)
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .pointerStyle(.link)
                    .help("Kosten pro Jahr – Diagramm anzeigen")
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    SortHeaderCell(
                        title: "Jahr",
                        isActive: yearlyCostSort.isActive(.year),
                        ascending: yearlyCostSort.ascending,
                        isEnabled: isSortable
                    ) { yearlyCostSort.select(.year) }
                    SortHeaderCell(
                        title: "Betankungen",
                        isActive: yearlyCostSort.isActive(.fuel),
                        ascending: yearlyCostSort.ascending,
                        isEnabled: isSortable
                    ) { yearlyCostSort.select(.fuel) }
                    .gridColumnAlignment(.trailing)
                    SortHeaderCell(
                        title: "Sonstige",
                        isActive: yearlyCostSort.isActive(.expense),
                        ascending: yearlyCostSort.ascending,
                        isEnabled: isSortable
                    ) { yearlyCostSort.select(.expense) }
                    .gridColumnAlignment(.trailing)
                    SortHeaderCell(
                        title: "Gesamt",
                        isActive: yearlyCostSort.isActive(.total),
                        ascending: yearlyCostSort.ascending,
                        isEnabled: isSortable
                    ) { yearlyCostSort.select(.total) }
                    .gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                ForEach(sortedYearlyCostStatistics) { item in
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
    private var sortedKilometersByYearStatistics: [YearlyDistance] {
        let items = vehicle.kilometersByYear
        let ascending = yearlyDistanceSort.ascending
        switch yearlyDistanceSort.column {
        case .year:
            return items.sorted { ascending ? $0.year < $1.year : $0.year > $1.year }
        case .kilometers:
            return items.sorted { ascending ? $0.kilometers < $1.kilometers : $0.kilometers > $1.kilometers }
        case .odometer:
            return items.sorted { ascending ? $0.odometerAtYearEnd < $1.odometerAtYearEnd : $0.odometerAtYearEnd > $1.odometerAtYearEnd }
        }
    }

    private var kilometersByYearStatistics: some View {
        let isSortable = vehicle.kilometersByYear.count >= 2
        return GlassCard {
            HStack {
                Text("Gefahrene km pro Jahr")
                    .font(.headline)
                Spacer()
                if isSortable, let vehicleRef {
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
                    SortHeaderCell(
                        title: "Jahr",
                        isActive: yearlyDistanceSort.isActive(.year),
                        ascending: yearlyDistanceSort.ascending,
                        isEnabled: isSortable
                    ) { yearlyDistanceSort.select(.year) }
                    SortHeaderCell(
                        title: "km",
                        isActive: yearlyDistanceSort.isActive(.kilometers),
                        ascending: yearlyDistanceSort.ascending,
                        isEnabled: isSortable
                    ) { yearlyDistanceSort.select(.kilometers) }
                    .gridColumnAlignment(.trailing)
                    SortHeaderCell(
                        title: "Tachostand",
                        isActive: yearlyDistanceSort.isActive(.odometer),
                        ascending: yearlyDistanceSort.ascending,
                        isEnabled: isSortable
                    ) { yearlyDistanceSort.select(.odometer) }
                    .gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                ForEach(sortedKilometersByYearStatistics) { item in
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
    return VehicleDetailView(vehicle: vehicle, onDelete: {})
        .environment(\.managedObjectContext, context)
}
