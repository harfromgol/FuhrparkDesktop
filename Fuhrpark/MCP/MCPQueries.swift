import CoreData
import Foundation

/// Datenzugriff, Filterung und Aufbereitung für die MCP-Werkzeuge.
///
/// Alle Kennzahlen stammen aus den vorhandenen Extensions der Modelltypen
/// (`Vehicle+Extensions` und Verwandte) – hier wird nichts nachgerechnet, damit
/// die Antworten zwangsläufig dieselben Werte liefern wie die App-Oberfläche.
enum MCPQueries {

    /// Obergrenze der serialisierten Antwort. Darüber wird die Ergebnisliste
    /// gekürzt: Ein einzelner Werkzeugaufruf soll das Kontextfenster des
    /// Modells nicht sprengen.
    static let maximumResponseCharacters = 60_000

    // MARK: - Argumente

    static func string(_ arguments: [String: Any], _ key: String) -> String? {
        guard let value = (arguments[key] as? String)?.trimmingCharacters(in: .whitespaces),
              !value.isEmpty
        else { return nil }
        return value
    }

    static func integer(_ arguments: [String: Any], _ key: String, fallback: Int, maximum: Int) -> Int {
        let raw = (arguments[key] as? NSNumber)?.intValue ?? fallback
        return min(max(raw, 0), maximum)
    }

    /// Liest ein Datumsargument im Format „YYYY-MM-DD“ als lokalen Kalendertag.
    static func day(_ arguments: [String: Any], _ key: String) throws -> Date? {
        guard let raw = string(arguments, key) else { return nil }
        guard let date = MCPValue.day(fromArgument: raw) else {
            throw MCPToolError.invalidArgument(name: key, reason: "erwartet wird das Format YYYY-MM-DD, erhalten „\(raw)“")
        }
        return date
    }

    /// Zeitraumfilter aus `from`/`to`. Beide Grenzen sind einschließlich; das
    /// Ende wird deshalb auf den Beginn des Folgetags gelegt.
    struct DateRange {
        let start: Date?
        let end: Date?

        func contains(_ date: Date?) -> Bool {
            guard let date else { return start == nil && end == nil }
            if let start, date < start { return false }
            if let end, date >= end { return false }
            return true
        }

        var isEmpty: Bool { start == nil && end == nil }
    }

    static func dateRange(_ arguments: [String: Any]) throws -> DateRange {
        let from = try day(arguments, "from")
        let toDay = try day(arguments, "to")
        let end = toDay.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
        return DateRange(start: from, end: end)
    }

    // MARK: - Fahrzeuge

    static func allVehicles(in context: NSManagedObjectContext) throws -> [Vehicle] {
        let request = NSFetchRequest<Vehicle>(entityName: "Vehicle")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)]
        return try context.fetch(request)
    }

    /// Löst ein Fahrzeug über UUID oder Kennzeichen auf. Kennzeichen werden
    /// ohne Rücksicht auf Groß-/Kleinschreibung, Leerzeichen und Bindestriche
    /// verglichen, damit „dlggk20“ genauso funktioniert wie „DLG-GK 20“.
    static func resolveVehicle(_ query: String, in context: NSManagedObjectContext) throws -> Vehicle {
        let vehicles = try allVehicles(in: context)

        if let uuid = UUID(uuidString: query), let match = vehicles.first(where: { $0.id == uuid }) {
            return match
        }

        let normalizedQuery = normalizePlate(query)
        if let match = vehicles.first(where: { normalizePlate($0.licensePlate ?? "") == normalizedQuery }) {
            return match
        }

        throw MCPToolError.vehicleNotFound(
            query: query,
            available: vehicles.compactMap(\.licensePlate)
        )
    }

    /// Fahrzeuge, auf die sich ein Werkzeugaufruf bezieht: entweder das eine
    /// angeforderte oder – ohne Angabe – alle.
    static func targetVehicles(_ arguments: [String: Any], in context: NSManagedObjectContext) throws -> [Vehicle] {
        guard let query = string(arguments, "vehicle") else {
            return try allVehicles(in: context)
        }
        return [try resolveVehicle(query, in: context)]
    }

    private static func normalizePlate(_ value: String) -> String {
        value.lowercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    /// Vergleich für die Volltextsuche: ohne Rücksicht auf Groß-/Kleinschreibung
    /// und Diakritika, damit „muller“ auch „Müller“ findet.
    static func matches(_ haystack: String?, _ needle: String) -> Bool {
        guard let haystack, !haystack.isEmpty else { return false }
        return haystack.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .contains(needle.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
    }

    // MARK: - Seitenweise Ausgabe

    /// Baut eine Listenantwort und kürzt sie, falls sie zu groß würde.
    static func page(
        items: [[String: Any]],
        total: Int,
        offset: Int,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        var visible = items
        var truncated = false

        while !visible.isEmpty, serializedSize(visible) > maximumResponseCharacters {
            visible.removeLast()
            truncated = true
        }

        var result: [String: Any] = [
            "gesamt": total,
            "geliefert": visible.count,
            "offset": offset,
            "eintraege": visible
        ]
        if truncated {
            result["gekuerzt"] = true
            result["hinweis"] = "Die Antwort wurde gekürzt. Mit „limit“ und „offset“ blättern oder enger filtern."
        }
        result.merge(extra) { current, _ in current }
        return result
    }

    private static func serializedSize(_ items: [[String: Any]]) -> Int {
        (try? JSONSerialization.data(withJSONObject: items).count) ?? 0
    }

    // MARK: - Aufbereitung: Fahrzeug

    /// Kompakte Fahrzeugzeile für Übersichten.
    static func vehicleSummary(_ vehicle: Vehicle) -> [String: Any] {
        [
            "id": vehicle.id?.uuidString ?? "",
            "kennzeichen": MCPValue.text(vehicle.licensePlate),
            "hersteller": MCPValue.text(vehicle.manufacturer),
            "modell": MCPValue.text(vehicle.model),
            "antrieb": vehicle.engineType == .bev ? "bev" : "combustion",
            "antriebLabel": vehicle.engineType.displayName,
            "stillgelegt": vehicle.decommissioned,
            "kilometerstand": Int(vehicle.highestOdometer),
            "gesamtkosten": MCPValue.number(vehicle.totalCost),
            "anzahlBetankungen": vehicle.fuelEntryCount,
            "anzahlAusgaben": vehicle.expenseCount
        ]
    }

    /// Vollständiges Fahrzeugprofil ohne die Rohlisten (die holen die
    /// jeweiligen Listen-Werkzeuge).
    static func vehicleDetails(_ vehicle: Vehicle) -> [String: Any] {
        let engine = vehicle.engineType
        let reminders = vehicle.sortedReminders

        var details = vehicleSummary(vehicle)
        details["anfangsKilometerstand"] = Int(vehicle.odometer)
        details["gefahreneKilometer"] = vehicle.drivenKilometers.map { Int($0) } ?? NSNull()
        details["angelegtAm"] = MCPValue.localDay(vehicle.createdAt)
        details["zuletztGeaendertAm"] = MCPValue.localDay(vehicle.lastChangedDts)
        details["einheiten"] = [
            "menge": engine.energyUnit,
            "verbrauch": engine.consumptionUnit,
            "preis": "EUR\(engine.pricePerUnitSuffix)",
            "waehrung": "EUR",
            "strecke": "km"
        ]

        details["summen"] = [
            "energiekosten": MCPValue.number(vehicle.totalFuelCost),
            "sonstigeKosten": MCPValue.number(vehicle.totalExpenseCost),
            "gesamtkosten": MCPValue.number(vehicle.totalCost),
            "kostenProKilometer": MCPValue.number(vehicle.costPerKilometer, places: 4),
            "getankteMenge": MCPValue.number(vehicle.totalLiters),
            "letzteBetankung": MCPValue.localDay(vehicle.lastFuelDate),
            "letzteAusgabe": MCPValue.localDay(vehicle.lastExpenseDate)
        ]

        // Der mengengewichtete Preis steht bewusst neben dem ungewichteten:
        // Die App zeigt den ungewichteten an, der tatsächlich gezahlte
        // Durchschnitt ist aber der gewichtete.
        let liters = vehicle.totalLiters
        let weighted: Decimal? = liters > 0 ? vehicle.totalFuelCost / liters : nil
        details["preisstatistik"] = [
            "minimum": MCPValue.number(vehicle.minPricePerLiter, places: 3),
            "maximum": MCPValue.number(vehicle.maxPricePerLiter, places: 3),
            "averageUnweighted": MCPValue.number(vehicle.averagePricePerLiter, places: 3),
            "averageWeighted": MCPValue.number(weighted, places: 4)
        ]

        details["verbrauchsstatistik"] = [
            "anzahlWerte": vehicle.consumptionCount,
            "minimum": MCPValue.number(vehicle.minConsumption),
            "maximum": MCPValue.number(vehicle.maxConsumption),
            "durchschnitt": MCPValue.number(vehicle.averageConsumption)
        ]

        details["kostenProJahr"] = vehicle.costsByYear.map {
            [
                "jahr": $0.year,
                "betankungen": MCPValue.number($0.fuel),
                "sonstige": MCPValue.number($0.expense),
                "gesamt": MCPValue.number($0.total)
            ]
        }

        details["kilometerProJahr"] = vehicle.kilometersByYear.map {
            [
                "jahr": $0.year,
                "kilometer": Int($0.kilometers),
                "kilometerstandJahresende": Int($0.odometerAtYearEnd)
            ]
        }

        details["kostenJeKategorie"] = vehicle.expenseCostByCategory.map {
            ["kategorie": $0.category, "gesamt": MCPValue.number($0.total)]
        }

        details["kategorien"] = ((vehicle.categories as? Set<Category>) ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
            .map { ["id": $0.id?.uuidString ?? "", "name": MCPValue.text($0.name)] }

        details["erinnerungen"] = [
            "gesamt": reminders.count,
            "offen": reminders.filter { !$0.isDone }.count,
            "faellig": reminders.filter(\.isDue).count,
            "ueberfaellig": reminders.filter(\.isOverdue).count
        ]

        return details
    }

    // MARK: - Aufbereitung: Betankung

    /// Betankungen eines Fahrzeugs samt Vorgänger. Da `sortedFuelEntries` nach
    /// Kilometerstand sortiert ist, ist der Vorgänger genau das vorherige
    /// Element – dieselbe Definition, die auch die Verbrauchsberechnung nutzt.
    static func fuelEntry(_ entry: FuelEntry, previous: FuelEntry?, vehicle: Vehicle) -> [String: Any] {
        let consumption = vehicle.effectiveConsumption(for: entry)
        let source: Any
        if entry.manualConsumption {
            source = "manuell"
        } else if entry.consumption != nil {
            source = "gespeichert"
        } else if consumption != nil {
            source = "berechnet"
        } else {
            source = NSNull()
        }

        let distance = previous.map { Int(entry.odometer - $0.odometer) }

        return [
            "id": entry.id?.uuidString ?? "",
            "kennzeichen": MCPValue.text(vehicle.licensePlate),
            "datum": MCPValue.timestamp(entry.date),
            "datumLocal": MCPValue.localDay(entry.date),
            "kilometerstand": Int(entry.odometer),
            "ort": MCPValue.text(entry.station),
            "menge": MCPValue.number(entry.liters?.decimalValue, places: 3),
            "preisProEinheit": MCPValue.number(entry.pricePerLiter?.decimalValue, places: 3),
            "betrag": MCPValue.number(entry.amount?.decimalValue),
            "vollgetankt": entry.fullTank,
            "verbrauch": MCPValue.number(consumption),
            "verbrauchsquelle": source,
            "kilometerSeitVorgaenger": distance.map { $0 as Any } ?? NSNull()
        ]
    }

    // MARK: - Aufbereitung: Ausgabe

    static func expense(_ expense: Expense) -> [String: Any] {
        [
            "id": expense.id?.uuidString ?? "",
            "kennzeichen": MCPValue.text(expense.vehicle?.licensePlate),
            "datum": MCPValue.timestamp(expense.date),
            "datumLocal": MCPValue.localDay(expense.date),
            "istEinnahme": expense.isIncome,
            "betrag": MCPValue.number(expense.amount?.decimalValue),
            "signedAmount": MCPValue.number(expense.signedAmount),
            "empfaenger": MCPValue.text(expense.recipient),
            "verwendungszweck": MCPValue.text(expense.purpose),
            "kategorien": expense.categoryNames,
            "anzahlBelege": expense.sortedDocuments.count
        ]
    }

    // MARK: - Aufbereitung: Erinnerung

    static func reminder(_ reminder: Erinnerung) -> [String: Any] {
        let daysUntilDue = reminder.dueDate.map {
            Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: $0)
            ).day ?? 0
        }

        return [
            "id": reminder.id?.uuidString ?? "",
            "kennzeichen": MCPValue.text(reminder.vehicle?.licensePlate),
            "titel": MCPValue.text(reminder.title),
            "faelligAm": MCPValue.localDay(reminder.dueDate),
            "tageBisFaelligkeit": daysUntilDue.map { $0 as Any } ?? NSNull(),
            "erledigt": reminder.isDone,
            "faellig": reminder.isDue,
            "ueberfaellig": reminder.isOverdue,
            "vorlaufWochen": reminder.advanceNotice.weeks,
            "erinnerungAb": MCPValue.localDay(reminder.earliestNoticeDate),
            "wiederholung": reminder.repeatDescription.map { $0 as Any } ?? NSNull()
        ]
    }

    // MARK: - Aufbereitung: Beleg

    static func document(_ document: Dokument) -> [String: Any] {
        let base = WorkingDirectoryStore.displayPath
        let absolute = base.flatMap { root in
            document.path.map { (root as NSString).appendingPathComponent($0) }
        }

        return [
            "id": document.id?.uuidString ?? "",
            "dateiname": document.filename,
            "relativerPfad": MCPValue.text(document.path),
            "absoluterPfad": absolute.map { $0 as Any } ?? NSNull(),
            "abgelegtAm": MCPValue.localDay(document.createdAt),
            "kennzeichen": MCPValue.text(document.vehicle?.licensePlate),
            // Ein Beleg kann mehrere Ausgaben belegen – deshalb eine Liste.
            // Alle gehören zum selben Fahrzeug, „kennzeichen“ bleibt eindeutig.
            "anzahlAusgaben": document.sortedExpenses.count,
            "ausgaben": document.sortedExpenses.map { expense in
                [
                    "id": expense.id?.uuidString ?? "",
                    "empfaenger": MCPValue.text(expense.recipient),
                    "verwendungszweck": MCPValue.text(expense.purpose),
                    "betrag": MCPValue.number(expense.amount?.decimalValue),
                    "datumLocal": MCPValue.localDay(expense.date)
                ]
            },
            "kategorien": document.categoryNames
        ]
    }
}
