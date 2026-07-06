import Foundation

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case insurance = "Versicherung"
    case tax = "Steuer"
    case maintenance = "Wartung/Reparatur"
    case tires = "Reifen"
    case toll = "Maut"
    case parking = "Parkgebühren"
    case carWash = "Autowäsche"
    case accessories = "Zubehör"
    case other = "Sonstiges"

    var id: String { rawValue }
}

extension Expense {
    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw ?? "") ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
