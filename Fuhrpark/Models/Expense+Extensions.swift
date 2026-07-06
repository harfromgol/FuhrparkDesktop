import Foundation

extension Expense {
    /// Angezeigter Kategoriename (leer, falls keine Kategorie zugeordnet).
    var categoryName: String {
        categoryRaw ?? ""
    }
}
