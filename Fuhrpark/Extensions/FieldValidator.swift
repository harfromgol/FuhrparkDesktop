import Foundation

/// Beschreibt Art und Grenzen eines Eingabefeldes für Sanitizing & Validierung.
enum FieldKind: Equatable {
    case text(min: Int, max: Int)
    case licensePlate
    case integer(minDigits: Int, maxDigits: Int)
    case decimal(fractionDigits: Int, minLength: Int, maxLength: Int)
    case date
}

enum FieldValidator {

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.isLenient = false
        formatter.locale = Locale(identifier: "de_DE")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    /// Filtert während der Eingabe unerlaubte Zeichen heraus / formatiert live.
    static func sanitize(_ input: String, kind: FieldKind) -> String {
        switch kind {
        case .text(_, let max):
            return String(input.prefix(max))

        case .licensePlate:
            let allowed = input.uppercased().filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
            return String(allowed.prefix(12))

        case .integer(_, let maxDigits):
            let digits = input.filter(\.isNumber)
            return String(digits.prefix(maxDigits))

        case .decimal(let fractionDigits, _, let maxLength):
            var result = ""
            var hasSeparator = false
            var fractionCount = 0
            for char in input {
                if char.isNumber {
                    if hasSeparator {
                        if fractionCount >= fractionDigits { continue }
                        fractionCount += 1
                    }
                    result.append(char)
                } else if (char == "," || char == ".") && !hasSeparator {
                    hasSeparator = true
                    result.append(",")
                }
                if result.count >= maxLength { break }
            }
            return result

        case .date:
            let allowed = input.filter { $0.isNumber || $0 == "." }
            return String(allowed.prefix(10))
        }
    }

    static func isValid(_ input: String, kind: FieldKind) -> Bool {
        switch kind {
        case .text(let min, let max):
            return input.count >= min && input.count <= max

        case .licensePlate:
            guard input.count >= 3, input.count <= 12 else { return false }
            let hasDigit = input.contains { $0.isNumber }
            let hasLetter = input.contains { $0.isLetter }
            return hasDigit && hasLetter

        case .integer(let minDigits, let maxDigits):
            guard !input.isEmpty, input.allSatisfy(\.isNumber) else { return false }
            return input.count >= minDigits && input.count <= maxDigits

        case .decimal(let fractionDigits, let minLength, let maxLength):
            let pattern = "^\\d+,\\d{\(fractionDigits)}$"
            guard input.range(of: pattern, options: .regularExpression) != nil else { return false }
            return input.count >= minLength && input.count <= maxLength

        case .date:
            return dateValue(input) != nil
        }
    }

    static func decimalValue(_ input: String) -> Decimal? {
        Decimal(string: input.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US"))
    }

    static func intValue(_ input: String) -> Int32? {
        Int32(input)
    }

    static func dateValue(_ input: String) -> Date? {
        guard input.count == 10 else { return nil }
        guard let date = dateFormatter.date(from: input) else { return nil }
        // Rundreise-Check gegen Auto-Korrektur ungültiger Daten (z.B. 31.02.)
        guard dateFormatter.string(from: date) == input else { return nil }
        return date
    }

    static func string(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
