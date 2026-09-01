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

    /// Ganzzahliger Kilometerstand mit Tausendertrennung, z. B. „42.000".
    static let odometer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 0
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

    /// Kostenbetrag: ein negativer Wert bedeutet einen Überschuss (Einnahmen
    /// übersteigen die Ausgaben) und wird mit führendem „+" dargestellt; sonst
    /// normale Währungsdarstellung.
    static func costString(_ decimal: Decimal) -> String {
        decimal < 0 ? "+" + currencyString(-decimal) : currencyString(decimal)
    }

    static func pricePerLiterString(_ decimal: Decimal) -> String {
        string(from: decimal, formatter: pricePerLiter)
    }

    static func odometerString(_ value: Int32) -> String {
        odometer.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Prozentanteil, z. B. „12,3 %". Erwartet den Anteil als Bruch (0,123),
    /// nicht bereits mit 100 multipliziert.
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static func percentString(_ fraction: Decimal) -> String {
        string(from: fraction, formatter: percent)
    }

    /// Verbleibende Sekunden eines Cooldowns als „m:ss", z. B. 9:47.
    static func countdownString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Distanz mit einer Nachkommastelle, z. B. „5,5 km" – für den
    /// einstellbaren Suchradius der Spritpreise-Umkreissuche.
    static let radiusKm: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static func radiusKmString(_ value: Double) -> String {
        (radiusKm.string(from: NSNumber(value: value)) ?? "\(value)") + " km"
    }
}
