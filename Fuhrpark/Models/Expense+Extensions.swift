import Foundation

extension Expense {
    /// Vorzeichenbehafteter Betrag: Einnahmen zählen negativ, damit sie sich in
    /// allen Kostensummen automatisch mit den Ausgaben verrechnen.
    var signedAmount: Decimal {
        let value = amount?.decimalValue ?? 0
        return isIncome ? -value : value
    }

    /// Zugeordnete Kategorien, nach Name sortiert.
    var sortedCategories: [Category] {
        let set = (categories as? Set<Category>) ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    /// Namen der zugeordneten Kategorien, nach Name sortiert.
    var categoryNames: [String] {
        sortedCategories.compactMap { $0.name }
    }

    /// Anzeigetext der Kategorien (kommagetrennt), leer wenn keine zugeordnet.
    var categoriesDisplay: String {
        categoryNames.joined(separator: ", ")
    }
}
