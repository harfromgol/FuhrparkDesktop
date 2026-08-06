import Foundation

/// Aufbereitung einzelner Werte für die JSON-Antworten.
///
/// Grundsatz: Für die KI zählen Rohwerte, keine formatierten Zeichenketten –
/// mit „1.234,56 €" kann sie nicht rechnen. Beträge gehen deshalb als Zahl
/// hinaus; die Einheit steckt im Feldnamen bzw. in der Werkzeugbeschreibung.
enum MCPValue {

    /// Kalendertag in der Zeitzone des Nutzers.
    ///
    /// Unverzichtbar neben dem UTC-Zeitstempel: Eine Betankung am 1. Januar um
    /// 00:30 Uhr Ortszeit ist in UTC noch der 31. Dezember. Ohne dieses Feld
    /// würde die KI sie einem anderen Jahr zuordnen als die App, die überall
    /// mit `Calendar.current` rechnet.
    static let localDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar.current
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Rundet einen Dezimalwert und gibt ihn als JSON-taugliche Zahl zurück.
    /// Das Runden verhindert, dass Binär-Gleitkommaartefakte bis in die Ausgabe
    /// durchschlagen (etwa `69.26000000000001`).
    static func number(_ value: Decimal?, places: Int = 2) -> Any {
        guard let value else { return NSNull() }
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, places, .plain)
        return NSDecimalNumber(decimal: rounded)
    }

    static func number(_ value: Double?, places: Int = 2) -> Any {
        guard let value else { return NSNull() }
        return number(Decimal(value), places: places)
    }

    /// ISO-8601-Zeitstempel in UTC, ohne Sekundenbruchteile.
    static func timestamp(_ date: Date?) -> Any {
        guard let date else { return NSNull() }
        return date.ISO8601Format()
    }

    static func localDay(_ date: Date?) -> Any {
        guard let date else { return NSNull() }
        return localDayFormatter.string(from: date)
    }

    static func text(_ value: String?) -> Any {
        guard let value, !value.isEmpty else { return NSNull() }
        return value
    }

    /// Wandelt „YYYY-MM-DD" in den Beginn dieses Tages in lokaler Zeit.
    static func day(fromArgument value: String) -> Date? {
        localDayFormatter.date(from: value)
    }
}
