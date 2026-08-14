import SwiftUI
import CoreData

/// Flottenweite Statistik über alle Fahrzeuge.
struct StatisticsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)],
        animation: .default
    )
    private var vehicles: FetchedResults<Vehicle>

    @State private var visibleVehicleGroups: Set<VehicleVisibility> = VehicleCostFilterStore.get() ?? Set(VehicleVisibility.allCases)
    @State private var isPresentingVehicleCostFilter = false
    @State private var yearlyCostCountOverride = YearlyCostCountStore.get()
    @State private var isPresentingYearlyCostConfig = false
    @State private var pdfExportErrorMessage: String?

    private var totalCost: Decimal { vehicles.reduce(.zero) { $0 + $1.totalCost } }
    private var totalFuelCost: Decimal { vehicles.reduce(.zero) { $0 + $1.totalFuelCost } }
    private var totalExpenseCost: Decimal { vehicles.reduce(.zero) { $0 + $1.totalExpenseCost } }

    /// Fahrzeuge für die „Kosten je Fahrzeug“-Tabelle: nach `visibleVehicleGroups`
    /// gefiltert, aktive Fahrzeuge immer vor stillgelegten (siehe dort für die
    /// gleiche Reihenfolge in der Sidebar).
    private var costPerVehicleList: [Vehicle] {
        vehicles
            .filter { visibleVehicleGroups.contains($0.decommissioned ? .decommissioned : .active) }
            .sorted { lhs, rhs in
                if lhs.decommissioned != rhs.decommissioned {
                    return !lhs.decommissioned
                }
                return (lhs.licensePlate ?? "") < (rhs.licensePlate ?? "")
            }
    }

    /// Ein-/Ausschalten einer Fahrzeuggruppe, sofort persistiert.
    private func vehicleGroupBinding(_ group: VehicleVisibility) -> Binding<Bool> {
        Binding(
            get: { visibleVehicleGroups.contains(group) },
            set: { isOn in
                if isOn { visibleVehicleGroups.insert(group) } else { visibleVehicleGroups.remove(group) }
                VehicleCostFilterStore.set(visibleVehicleGroups)
            }
        )
    }

    private var vehicleCostFilterPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fahrzeuge anzeigen")
                .font(.headline)
            ForEach(VehicleVisibility.allCases) { group in
                Toggle(group.displayName, isOn: vehicleGroupBinding(group))
                    .toggleStyle(.checkbox)
            }
        }
        .padding(16)
        .frame(width: 220, alignment: .leading)
    }

    /// Aggregierte Kosten pro Kalenderjahr über alle Fahrzeuge, neuestes Jahr zuerst.
    private var costsByYear: [YearlyCost] {
        let calendar = Calendar.current
        var fuelByYear: [Int: Decimal] = [:]
        var expenseByYear: [Int: Decimal] = [:]

        for vehicle in vehicles {
            for entry in vehicle.sortedFuelEntries {
                guard let date = entry.date else { continue }
                let year = calendar.component(.year, from: date)
                fuelByYear[year, default: 0] += entry.amount?.decimalValue ?? 0
            }
            for expense in vehicle.sortedExpenses {
                guard let date = expense.date else { continue }
                let year = calendar.component(.year, from: date)
                expenseByYear[year, default: 0] += expense.signedAmount
            }
        }

        let years = Set(fuelByYear.keys).union(expenseByYear.keys)
        return years
            .map { YearlyCost(year: $0, fuel: fuelByYear[$0, default: 0], expense: expenseByYear[$0, default: 0]) }
            .sorted { $0.year > $1.year }
    }

    /// Höchstmögliche Anzahl Jahre – die tatsächlich vorhandenen Jahre mit
    /// Kosten (mindestens 1, damit der Stepper-Bereich immer gültig ist).
    private var maxYearlyCostCount: Int {
        max(costsByYear.count, 1)
    }

    /// Anzahl anzuzeigender Jahre: nutzerdefiniert (siehe
    /// `yearlyCostCountOverride`), sonst alle verfügbaren Jahre. Auf die
    /// tatsächlich vorhandene Anzahl begrenzt, falls sich die Datenlage seit
    /// der letzten Auswahl verringert hat.
    private var yearlyCostCount: Int {
        min(yearlyCostCountOverride ?? costsByYear.count, maxYearlyCostCount)
    }

    private var yearlyCostCountBinding: Binding<Int> {
        Binding(
            get: { yearlyCostCount },
            set: { newValue in
                yearlyCostCountOverride = newValue
                YearlyCostCountStore.set(newValue)
            }
        )
    }

    /// Auf `yearlyCostCount` begrenzte, neueste Jahre aus `costsByYear`.
    private var limitedCostsByYear: [YearlyCost] {
        Array(costsByYear.prefix(yearlyCostCount))
    }

    private var yearlyCostConfigPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anzahl Jahre")
                .font(.headline)
            Stepper(value: yearlyCostCountBinding, in: 1...maxYearlyCostCount) {
                Text("\(yearlyCostCount) Jahre")
            }
        }
        .padding(16)
        .frame(width: 220, alignment: .leading)
    }

    private func exportPDF() {
        do {
            let reportView = StatisticsPDFReportView(
                vehicleCount: vehicles.count,
                totalCost: totalCost,
                costPerVehicleList: costPerVehicleList,
                costsByYear: limitedCostsByYear
            )
            let url = try ReportPDFGenerator.generate(
                reportView,
                sections: reportView.sections,
                filenamePrefix: "Statistik"
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

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 20) {
                    if vehicles.isEmpty {
                        ContentUnavailableView(
                            "Keine Daten",
                            systemImage: "chart.bar",
                            description: Text("Lege ein Fahrzeug an, um Statistiken zu sehen.")
                        )
                        .padding(.top, 60)
                    } else {
                        GlassCard {
                            HStack {
                                Text("Übersicht")
                                    .font(.headline)
                                Spacer()
                                Menu {
                                    Button("PDF") { exportPDF() }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                                .fixedSize()
                                .pointerStyle(.link)
                                .help("Weitere Aktionen")
                            }

                            HStack(alignment: .top, spacing: 16) {
                                StatTile(
                                    title: "Fahrzeuge",
                                    value: "\(vehicles.count)",
                                    systemImage: "car.2.fill"
                                )
                                Divider()
                                StatTile(
                                    title: "Gesamtkosten",
                                    value: DisplayFormatter.costString(totalCost),
                                    systemImage: "sum"
                                )
                            }
                        }

                        GlassCard {
                            HStack {
                                Text("Kosten je Fahrzeug")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    isPresentingVehicleCostFilter = true
                                } label: {
                                    Image(systemName: "gearshape")
                                }
                                .buttonStyle(.borderless)
                                .pointerStyle(.link)
                                .help("Anzeige konfigurieren")
                                .popover(isPresented: $isPresentingVehicleCostFilter) {
                                    vehicleCostFilterPopover
                                }
                            }

                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                GridRow {
                                    Text("Fahrzeug")
                                    Text("Betankungen").gridColumnAlignment(.trailing)
                                    Text("Sonstige").gridColumnAlignment(.trailing)
                                    Text("Gesamt").gridColumnAlignment(.trailing)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Divider()

                                ForEach(costPerVehicleList) { vehicle in
                                    GridRow {
                                        Text(vehicle.licensePlate ?? "")
                                        Text(DisplayFormatter.currencyString(vehicle.totalFuelCost))
                                        Text(DisplayFormatter.costString(vehicle.totalExpenseCost))
                                        Text(DisplayFormatter.costString(vehicle.totalCost))
                                            .bold()
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }

                        GlassCard {
                            HStack {
                                Text("Kosten pro Jahr")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    isPresentingYearlyCostConfig = true
                                } label: {
                                    Image(systemName: "gearshape")
                                }
                                .buttonStyle(.borderless)
                                .pointerStyle(.link)
                                .help("Anzeige konfigurieren")
                                .popover(isPresented: $isPresentingYearlyCostConfig) {
                                    yearlyCostConfigPopover
                                }
                            }

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

                                ForEach(limitedCostsByYear) { item in
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
                }
                .padding(20)
            }
        }
        .navigationTitle("Statistik")
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
    }
}
