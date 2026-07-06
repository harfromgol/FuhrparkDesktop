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
}
