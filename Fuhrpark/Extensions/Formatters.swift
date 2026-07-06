import Foundation

enum DisplayFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        formatter.currencyCode = "EUR"
        return formatter
    }()

    static let decimal2: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let consumption: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Währung mit 3 Nachkommastellen, z. B. für den Preis pro Liter.
    static let pricePerLiter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    static func string(from decimal: Decimal, formatter: NumberFormatter) -> String {
        formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "\(decimal)"
    }

    static func currencyString(_ decimal: Decimal) -> String {
        string(from: decimal, formatter: currency)
    }

    static func pricePerLiterString(_ decimal: Decimal) -> String {
        string(from: decimal, formatter: pricePerLiter)
    }
}
