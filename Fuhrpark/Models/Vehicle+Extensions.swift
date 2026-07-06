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

    /// Gesamtkosten (Betankungen + sonstige Ausgaben).
    var totalCost: Decimal {
        totalFuelCost + totalExpenseCost
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
}
