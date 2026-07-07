import Foundation
import CoreData

enum EngineType: Int16, CaseIterable, Identifiable {
    case combustion = 0
    case bev = 1

    var id: Int16 { rawValue }

    var displayName: String {
        switch self {
        case .combustion: return "Verbrenner"
        case .bev: return "BEV"
        }
    }
}

extension Vehicle {
    var engineType: EngineType {
        get { EngineType(rawValue: engineTypeRaw) ?? .combustion }
        set { engineTypeRaw = newValue.rawValue }
    }

    /// Setzt den Zeitstempel der letzten Änderung auf jetzt. Wird beim Hinzufügen
    /// einer Betankung oder sonstigen Ausgabe aufgerufen.
    func touch() {
        lastChangedDts = Date()
    }

    var sortedFuelEntries: [FuelEntry] {
        let entries = (fuelEntries as? Set<FuelEntry>) ?? []
        return entries.sorted { $0.odometer < $1.odometer }
    }

    var sortedExpenses: [Expense] {
        let items = (expenses as? Set<Expense>) ?? []
        return items.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Letzte (vom Kilometerstand her höchste) Betankung, exklusive der übergebenen.
    func previousFuelEntry(before entry: FuelEntry?) -> FuelEntry? {
        let entries = sortedFuelEntries.filter { $0 !== entry }
        guard let entry else { return entries.last }
        return entries.filter { $0.odometer < entry.odometer }.max { $0.odometer < $1.odometer }
    }

    // MARK: - Statistik

    /// Summe aller Betankungskosten.
    var totalFuelCost: Decimal {
        sortedFuelEntries.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? 0) }
    }

    /// Summe aller sonstigen Ausgaben.
    var totalExpenseCost: Decimal {
        sortedExpenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? 0) }
    }

    /// Gesamtkosten je Kategorie, nach Betrag absteigend sortiert.
    var expenseCostByCategory: [(category: String, total: Decimal)] {
        let grouped = Dictionary(grouping: sortedExpenses) { expense in
            expense.categoryName.isEmpty ? "Ohne Kategorie" : expense.categoryName
        }
        return grouped
            .map { key, expenses in
                (category: key, total: expenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? 0) })
            }
            .sorted { $0.total > $1.total }
    }

    /// Gesamtkosten (Betankungen + sonstige Ausgaben).
    var totalCost: Decimal {
        totalFuelCost + totalExpenseCost
    }

    /// Höchster bekannter Kilometerstand: der Anlagestand oder – falls höher –
    /// der höchste Kilometerstand aus den erfassten Betankungen.
    var highestOdometer: Int32 {
        max(odometer, sortedFuelEntries.map(\.odometer).max() ?? odometer)
    }

    /// Gefahrene Kilometer seit Anlage des Fahrzeugs (höchster Betankungs-Kilometerstand
    /// minus anfänglicher Tachostand). Nil, wenn nicht ermittelbar.
    var drivenKilometers: Int32? {
        guard let maxOdometer = sortedFuelEntries.map(\.odometer).max(), maxOdometer > odometer else {
            return nil
        }
        return maxOdometer - odometer
    }

    /// Kosten pro Kilometer. Nil, wenn keine gefahrenen Kilometer bekannt sind.
    var costPerKilometer: Decimal? {
        guard let km = drivenKilometers, km > 0 else { return nil }
        return totalCost / Decimal(km)
    }

    // MARK: - Betankungs-Statistik

    /// Anzahl der erfassten Betankungen.
    var fuelEntryCount: Int {
        sortedFuelEntries.count
    }

    /// Datum der letzten (jüngsten) Betankung.
    var lastFuelDate: Date? {
        sortedFuelEntries.compactMap(\.date).max()
    }

    /// Summe aller getankten Liter.
    var totalLiters: Decimal {
        sortedFuelEntries.reduce(Decimal.zero) { $0 + ($1.liters?.decimalValue ?? 0) }
    }

    // MARK: - Spritpreis

    private var pricesPerLiter: [Decimal] {
        sortedFuelEntries.compactMap { $0.pricePerLiter?.decimalValue }
    }

    var minPricePerLiter: Decimal? { pricesPerLiter.min() }
    var maxPricePerLiter: Decimal? { pricesPerLiter.max() }
    var averagePricePerLiter: Decimal? {
        let prices = pricesPerLiter
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +) / Decimal(prices.count)
    }

    // MARK: - Verbrauch

    /// Effektiver Verbrauch einer Betankung: gespeicherter Wert, sonst live berechnet.
    func effectiveConsumption(for entry: FuelEntry) -> Double? {
        if let stored = entry.consumption?.doubleValue {
            return stored
        }
        return FuelConsumptionCalculator.automaticConsumption(
            currentOdometer: entry.odometer,
            currentLiters: entry.liters?.decimalValue ?? 0,
            previousEntryExists: entry.previousEntryExists,
            currentFullTank: entry.fullTank,
            previousEntry: previousFuelEntry(before: entry)
        )
    }

    private var consumptions: [Double] {
        sortedFuelEntries.compactMap { effectiveConsumption(for: $0) }
    }

    var minConsumption: Double? { consumptions.min() }
    var maxConsumption: Double? { consumptions.max() }
    var averageConsumption: Double? {
        let values = consumptions
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
