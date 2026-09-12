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
    @State private var isPresentingNewNote = false
    @State private var isPresentingNewReminder = false
    @State private var isPresentingCardConfig = false
    @State private var isPresentingSectionVisibility = false
    @State private var isPresentingEditVehicle = false
    @State private var vehiclePendingDeletion: Vehicle?
    @State private var vehiclePendingDecommission: Vehicle?
    @State private var pdfExportErrorMessage: String?
    @State private var noteErrorMessage: String?
    @State private var reminderErrorMessage: String?
    /// Gemessene Breite der `noteSummary`-Karte – siehe dort für die
    /// 30:70-Spaltenaufteilung, für die diese Breite gebraucht wird.
    @State private var noteSummaryWidth: CGFloat = 0
    /// Anteil der linken Spalte („Anzahl") in `noteSummary`. Nicht `private`,
    /// da `VehiclePDFReportView.notesSection` dieselbe Aufteilung für die
    /// entsprechende Karte im PDF-Export übernimmt.
    static let noteCountColumnRatio: CGFloat = 0.2
    /// Gemessene Breite der `reminderSummary`-Karte – gleiches Muster wie
    /// `noteSummaryWidth`.
    @State private var reminderSummaryWidth: CGFloat = 0
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
    /// Welche Abschnitte (Betankungen/Sonstige Ausgaben/Notizen/Erinnerungen/
    /// Statistik – jeweils Überschrift + Karte) sichtbar sind, umschaltbar
    /// über „Sichtbare Elemente" im Kopfzeilen-Menü (öffnet
    /// `sectionVisibilityPopover`). Effektiver Stand aus
    /// `VehicleDetailSectionVisibilityStore` – globale Einstellung, sofern
    /// dieses Fahrzeug keinen eigenen Override hat (siehe
    /// `hasCustomSectionVisibility`).
    @State private var visibleSections: Set<VehicleDetailSection>
    /// Ob dieses Fahrzeug einen eigenen Override der Abschnitts-Sichtbarkeit
    /// hat (an) oder der globalen Einstellung folgt (aus). Umschaltbar über
    /// den Kippschalter oben in `sectionVisibilityPopover`.
    @State private var hasCustomSectionVisibility: Bool

    /// Eigener `@FetchRequest` statt `vehicle.sortedReminders`: Core Data
    /// löst `objectWillChange` für `vehicle` nur aus, wenn sich dessen EIGENE
    /// Relationship-Mitgliedschaft ändert (neue/gelöschte Erinnerung) – nicht
    /// wenn nur ein Attribut einer bereits verknüpften Erinnerung geändert
    /// wird (z. B. `isDone` beim Erledigt-Toggle im `ReminderListWindow`).
    /// `reminderSummary` bliebe damit veraltet stehen, solange dieses
    /// Fenster offen bleibt. `FetchedResults` beobachtet dagegen jede
    /// passende Objektänderung im Kontext direkt und aktualisiert sich immer.
    @FetchRequest private var reminders: FetchedResults<Erinnerung>

    init(vehicle: Vehicle, onDelete: @escaping () -> Void) {
        self.vehicle = vehicle
        self.onDelete = onDelete
        _enabledCards = State(initialValue: vehicle.id.map(StatisticsCardVisibilityStore.enabledCards(for:)) ?? Set(StatisticsCard.allCases))
        _visibleSections = State(initialValue: vehicle.id.map(VehicleDetailSectionVisibilityStore.visibleSections(for:)) ?? Set(VehicleDetailSection.allCases))
        _hasCustomSectionVisibility = State(initialValue: vehicle.id.flatMap(VehicleDetailSectionVisibilityStore.vehicleOverride(for:)) != nil)
        _reminders = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Erinnerung.dueDate, ascending: true)],
            predicate: vehicle.id.map { NSPredicate(format: "vehicle.id == %@", $0 as NSUUID) } ?? NSPredicate(value: false)
        )
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

    /// Ein-/Ausschalten eines Abschnitts, sofort persistiert – abhängig vom
    /// Zustand des Kippschalters entweder als globale Einstellung (wirkt auf
    /// alle Fahrzeuge ohne eigenen Override) oder als Override nur für
    /// dieses Fahrzeug.
    private func sectionBinding(_ section: VehicleDetailSection) -> Binding<Bool> {
        Binding(
            get: { visibleSections.contains(section) },
            set: { isOn in
                if isOn { visibleSections.insert(section) } else { visibleSections.remove(section) }
                if hasCustomSectionVisibility {
                    if let id = vehicle.id {
                        VehicleDetailSectionVisibilityStore.setVehicleOverride(visibleSections, for: id)
                    }
                } else {
                    VehicleDetailSectionVisibilityStore.setGlobalVisibleSections(visibleSections)
                }
            }
        )
    }

    /// Kippschalter „Eigene Einstellung für dieses Fahrzeug" oben in
    /// `sectionVisibilityPopover`. Beim Einschalten wird der aktuell
    /// sichtbare Stand als Override für dieses Fahrzeug übernommen; beim
    /// Ausschalten wird der Override gelöscht und die Anzeige fällt auf die
    /// globale Einstellung zurück.
    private var sectionVisibilityScopeBinding: Binding<Bool> {
        Binding(
            get: { hasCustomSectionVisibility },
            set: { isOn in
                guard let id = vehicle.id else { return }
                if isOn {
                    VehicleDetailSectionVisibilityStore.setVehicleOverride(visibleSections, for: id)
                } else {
                    VehicleDetailSectionVisibilityStore.setVehicleOverride(nil, for: id)
                    visibleSections = VehicleDetailSectionVisibilityStore.globalVisibleSections()
                }
                hasCustomSectionVisibility = isOn
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

    /// Popover statt Untermenü: ein `Menu`/Untermenü schließt sich auf macOS
    /// bei jedem Klick auf einen Eintrag – auch bei einem toggelnden mit
    /// Häkchen –, was mehrere Auswahlen umständlich macht. Ein Popover mit
    /// Checkbox-Togglen bleibt dagegen offen, bis man daneben klickt –
    /// dasselbe Muster wie `cardVisibilityPopover`. Die Einstellung gilt per
    /// Default global für alle Fahrzeuge; der Kippschalter oben erlaubt
    /// einen Override nur für dieses Fahrzeug (siehe
    /// `sectionVisibilityScopeBinding`).
    private var sectionVisibilityPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sichtbare Elemente")
                .font(.headline)

            Toggle("Eigene Einstellung für dieses Fahrzeug", isOn: sectionVisibilityScopeBinding)
                .toggleStyle(.checkbox)

            Divider()

            ForEach(VehicleDetailSection.allCases) { section in
                Toggle(section.title, isOn: sectionBinding(section))
                    .toggleStyle(.checkbox)
            }

            if !hasCustomSectionVisibility {
                Text("Gilt global für alle Fahrzeuge ohne eigene Einstellung.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

                    if visibleSections.contains(.fuelEntries) {
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
                    }

                    if visibleSections.contains(.expenses) {
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
                    }

                    if visibleSections.contains(.notes) {
                        sectionHeader(title: "Notizen", systemImage: "note.text") {
                            Button("Neue Notiz", systemImage: "plus") {
                                addNoteTapped()
                            }
                            .buttonStyle(.glass)
                            .pointerStyle(.link)
                            if vehicle.sortedNotizen.count > 1 {
                                Button("Liste anzeigen", systemImage: "list.bullet") {
                                    if let vehicleRef {
                                        openWindow(id: "notes-list", value: vehicleRef)
                                    }
                                }
                                .buttonStyle(.glass)
                                .pointerStyle(.link)
                            }
                        }

                        if vehicle.sortedNotizen.isEmpty {
                            Text("Noch keine Notizen erfasst.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            noteSummary
                        }
                    }

                    if visibleSections.contains(.reminders) {
                        sectionHeader(title: "Erinnerungen", systemImage: "bell") {
                            Button("Neue Erinnerung", systemImage: "plus") {
                                addReminderTapped()
                            }
                            .buttonStyle(.glass)
                            .pointerStyle(.link)
                            if reminders.count > 1 {
                                Button("Liste anzeigen", systemImage: "list.bullet") {
                                    if let vehicleRef {
                                        openWindow(id: "reminders-list", value: vehicleRef)
                                    }
                                }
                                .buttonStyle(.glass)
                                .pointerStyle(.link)
                            }
                        }

                        if reminders.isEmpty {
                            Text("Noch keine Erinnerungen erfasst.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            reminderSummary
                        }
                    }

                    if visibleSections.contains(.statistics) {
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
        .sheet(isPresented: $isPresentingNewNote) {
            NoteFormView(fixedVehicle: vehicle)
        }
        .sheet(isPresented: $isPresentingNewReminder) {
            ReminderFormView(fixedVehicle: vehicle)
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
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { noteErrorMessage != nil },
                set: { if !$0 { noteErrorMessage = nil } }
            ),
            presenting: noteErrorMessage
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { reminderErrorMessage != nil },
                set: { if !$0 { reminderErrorMessage = nil } }
            ),
            presenting: reminderErrorMessage
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
            message: { "„\($0.licensePlate ?? "")“ und alle zugehörigen \($0.engineType.refuelNounPlural), Ausgaben, Erinnerungen und Notizen werden unwiderruflich gelöscht." },
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

    /// Öffnet das Formular für eine neue Notiz zu diesem Fahrzeug – vorher
    /// dieselbe Voraussetzungsprüfung wie beim „Neue Notiz"-Button unter
    /// „Allgemein → Notizen" (siehe `NotesView.addNoteTapped`). `hasVehicles`
    /// ist hier immer erfüllt, in der Praxis prüft der Aufruf also nur das
    /// Arbeitsverzeichnis.
    private func addNoteTapped() {
        if let message = NewItemPrerequisite.missingMessage(hasVehicles: true) {
            noteErrorMessage = message
            return
        }
        isPresentingNewNote = true
    }

    /// Öffnet das Formular für eine neue Erinnerung zu diesem Fahrzeug –
    /// vorher dieselbe Voraussetzungsprüfung wie beim „Neue Erinnerung"-Button
    /// unter „Allgemein → Erinnerungen" (siehe `RemindersView.addReminderTapped`).
    /// `hasVehicles` ist hier immer erfüllt, in der Praxis prüft der Aufruf
    /// also nur das Arbeitsverzeichnis.
    private func addReminderTapped() {
        if let message = NewItemPrerequisite.missingMessage(hasVehicles: true) {
            reminderErrorMessage = message
            return
        }
        isPresentingNewReminder = true
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
                    Divider()
                    Button("Sichtbare Elemente") { isPresentingSectionVisibility = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .pointerStyle(.link)
                .help("Weitere Aktionen")
                .popover(isPresented: $isPresentingSectionVisibility) {
                    sectionVisibilityPopover
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

    /// Zwei Spalten im Verhältnis `noteCountColumnRatio` (20:80): links die
    /// Anzahl der Notizen dieses Fahrzeugs, rechts die aktuellste (neueste
    /// zuerst, siehe `Vehicle.sortedNotizen`). Wird nur gezeigt, wenn
    /// mindestens eine Notiz vorhanden ist.
    ///
    /// `StatTile` selbst verlangt intern `maxWidth: .infinity` – ohne feste
    /// Breite würden sich beide Spalten in einer `HStack` den verfügbaren
    /// Platz automatisch 50:50 teilen. Die tatsächliche Kartenbreite wird
    /// deshalb wie bei `ValidatedField`s Vorschlags-Popup per
    /// Hintergrund-`GeometryReader` gemessen (`NoteSummaryWidthKey`) und die
    /// linke Spalte darauf auf `noteCountColumnRatio` fixiert – im allerersten
    /// Layout-Durchgang (Breite noch 0) fällt sie auf die intrinsische Breite
    /// zurück.
    private var noteSummary: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                StatTile(
                    title: "Anzahl",
                    value: "\(vehicle.sortedNotizen.count)",
                    systemImage: "number"
                )
                .frame(width: noteSummaryColumnWidth, alignment: .leading)
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Label("Aktuellste Notiz", systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let newest = vehicle.sortedNotizen.first {
                        Text(FieldValidator.string(from: newest.date ?? Date()))
                            .font(.title3.bold())
                        Text(newest.text ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: NoteSummaryWidthKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(NoteSummaryWidthKey.self) { noteSummaryWidth = $0 }
        }
    }

    private var noteSummaryColumnWidth: CGFloat? {
        guard noteSummaryWidth > 0 else { return nil }
        return (noteSummaryWidth - 16 - 1) * Self.noteCountColumnRatio
    }

    /// Erledigte Erinnerungen sind für `reminderSummary` uninteressant –
    /// weder in „Fällige / Offen" noch als „nächste fällige" sollen sie
    /// mitzählen.
    private var openReminders: [Erinnerung] {
        reminders.filter { !$0.isDone }
    }

    /// Zwei Spalten im selben Verhältnis wie `noteSummary` (`noteCountColumnRatio`,
    /// 20:80): links „Fällige / Offen" (`Erinnerung.isDue`, gegen
    /// `openReminders` statt aller Erinnerungen), rechts die nächste fällige
    /// unter den offenen – `reminders` ist nach Fälligkeitsdatum aufsteigend
    /// sortiert, `openReminders` behält diese Reihenfolge bei, `first` also
    /// die nächste (nicht zwingend die zuletzt angelegte). Wird nur gezeigt,
    /// wenn mindestens eine Erinnerung vorhanden ist – auch wenn alle
    /// erledigt sind (dann zeigt die Karte 0/0 und keine „nächste fällige").
    private var reminderSummary: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                StatTile(
                    title: "Anzahl",
                    value: "\(openReminders.filter(\.isDue).count) / \(openReminders.count)",
                    systemImage: "number"
                )
                .frame(width: reminderSummaryColumnWidth, alignment: .leading)
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Label("Nächste fällige Erinnerung", systemImage: "bell")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let next = openReminders.first {
                        Text(next.title ?? "")
                            .font(.title3.bold())
                        if let due = next.dueDate {
                            Text(FieldValidator.string(from: due))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ReminderSummaryWidthKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(ReminderSummaryWidthKey.self) { reminderSummaryWidth = $0 }
        }
    }

    private var reminderSummaryColumnWidth: CGFloat? {
        guard reminderSummaryWidth > 0 else { return nil }
        return (reminderSummaryWidth - 16 - 1) * Self.noteCountColumnRatio
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

/// Misst die Breite der `noteSummary`-Karte für deren 30:70-Spaltenaufteilung
/// – gleiches Muster wie `FieldWidthKey` in `ValidatedField.swift`.
private struct NoteSummaryWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Misst die Breite der `reminderSummary`-Karte für deren 20:80-Spaltenaufteilung.
private struct ReminderSummaryWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let vehicle = (try! context.fetch(Vehicle.fetchRequest()) as! [Vehicle]).first!
    return VehicleDetailView(vehicle: vehicle, onDelete: {})
        .environment(\.managedObjectContext, context)
}
