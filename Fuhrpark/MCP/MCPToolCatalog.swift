import CoreData
import Foundation

enum MCPToolError: LocalizedError {
    case unknownTool(String)
    case missingArgument(String)
    case invalidArgument(name: String, reason: String)
    case vehicleNotFound(query: String, available: [String])

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            "Unbekanntes Werkzeug „\(name)“."
        case .missingArgument(let name):
            "Der Parameter „\(name)“ fehlt."
        case .invalidArgument(let name, let reason):
            "Der Parameter „\(name)“ ist ungültig: \(reason)"
        case .vehicleNotFound(let query, let available):
            "Kein Fahrzeug zu „\(query)“ gefunden. Vorhanden: \(available.joined(separator: ", "))."
        }
    }
}

/// Definition und Verteilung der Werkzeuge, die der MCP-Server anbietet.
/// Sämtliche Werkzeuge sind ausschließlich lesend – in diesem Modus existiert
/// kein Pfad, der Daten verändert.
enum MCPToolCatalog {

    struct Tool {
        let name: String
        let description: String
        let inputSchema: [String: Any]
        let run: ([String: Any]) throws -> [String: Any]
    }

    /// Hinweis zur Kategoriesumme. Steht in der Antwort jedes Werkzeugs, das
    /// nach Kategorie aufschlüsselt – ohne ihn liest das Modell die Zahlen als
    /// Aufteilung und addiert sie fälschlich auf.
    static let categoryWarning = """
        Eine Ausgabe mit mehreren Kategorien zählt mit ihrem vollen Betrag in \
        jede dieser Kategorien. Die Summe über alle Kategorien kann deshalb \
        größer sein als die Gesamtsumme – dies ist keine Aufteilung.
        """

    /// Wird dem Modell beim Verbindungsaufbau mitgegeben. Enthält die
    /// Eigenheiten der Datenlogik, die man kennen muss, um die Zahlen richtig
    /// zu deuten – ohne sie zieht das Modell falsche Schlüsse.
    static let serverInstructions = """
        Zugriff auf die Fuhrparkdaten der App FuhrparkDesktop (nur lesend).

        Fünf Eigenheiten der Datenlogik, die für die Auswertung wichtig sind:

        1. Einnahmen zählen in allen Kostensummen NEGATIV. Das Feld „betrag“ ist
           stets positiv, „signedAmount“ trägt das Vorzeichen. Eine negative
           Gesamtsumme bedeutet also einen Überschuss.
        2. Bei den Kosten je Kategorie zählt eine Ausgabe mit mehreren
           Kategorien mit ihrem VOLLEN Betrag in JEDE dieser Kategorien. Die
           Summe über alle Kategorien kann deshalb größer sein als die
           Gesamtsumme. Das ist keine Aufteilung und darf nicht aufaddiert
           werden.
        3. Der Durchschnittspreis „averageUnweighted“ ist das arithmetische
           Mittel der Einzelpreise – so zeigt die App ihn an. Der tatsächlich
           gezahlte Durchschnitt steht als „averageWeighted“ daneben.
        4. Betankungen sind nach KILOMETERSTAND sortiert, nicht nach Datum. Die
           gefahrenen Kilometer je Jahr beruhen auf Interpolation; Jahre ohne
           ermittelbaren Stand fehlen in der Liste.

        5. Ein Beleg kann MEHRERE Ausgaben belegen (etwa eine Rechnung, die in
           zwei Buchungen aufgeteilt wurde). „anzahlBelege“ einer Ausgabe darf
           deshalb nicht über Ausgaben aufsummiert werden – derselbe Beleg
           zählte sonst mehrfach. Alle Ausgaben eines Belegs gehören stets zum
           selben Fahrzeug.

        Für Jahres- und Monatszuordnungen immer die Felder mit der Endung
        „Local“ verwenden (Kalendertag in der Zeitzone des Nutzers), nicht die
        UTC-Zeitstempel. Beträge sind Euro, Strecken Kilometer.

        Einstiegspunkt ist „fleet_overview“.
        """

    static var all: [Tool] {
        [
            fleetOverview,
            vehicleDetails,
            listFuelEntries,
            listExpenses,
            listReminders,
            costReport,
            search,
            listDocuments,
            diagnostics
        ]
    }

    static var definitions: [[String: Any]] {
        all.map {
            ["name": $0.name, "description": $0.description, "inputSchema": $0.inputSchema]
        }
    }

    static func run(name: String, arguments: [String: Any]) throws -> [String: Any] {
        guard let tool = all.first(where: { $0.name == name }) else {
            throw MCPToolError.unknownTool(name)
        }
        return try tool.run(arguments)
    }

    /// Führt einen Block mit einem frisch geladenen Core-Data-Stack aus.
    ///
    /// Bewusst pro Aufruf neu: Nur so sind auch die Änderungen sichtbar, die
    /// eine parallel laufende GUI-Instanz zwischenzeitlich gespeichert hat. Bei
    /// dieser Datenmenge kostet das Laden kaum messbare Zeit.
    static func withContext<T>(_ body: (NSManagedObjectContext) throws -> T) throws -> T {
        try body(try MCPPersistence.loadContainer().viewContext)
    }

    // MARK: - Schema-Bausteine

    static var noArguments: [String: Any] {
        ["type": "object", "properties": [String: Any](), "additionalProperties": false]
    }

    static func schema(_ properties: [String: Any], required: [String] = []) -> [String: Any] {
        var result: [String: Any] = [
            "type": "object",
            "properties": properties,
            "additionalProperties": false
        ]
        if !required.isEmpty { result["required"] = required }
        return result
    }

    static var vehicleProperty: [String: Any] {
        ["type": "string", "description": "Kennzeichen oder UUID des Fahrzeugs. Weglassen = alle Fahrzeuge."]
    }
    static var fromProperty: [String: Any] {
        ["type": "string", "description": "Frühestes Datum, einschließlich, Format YYYY-MM-DD (Ortszeit)."]
    }
    static var toProperty: [String: Any] {
        ["type": "string", "description": "Spätestes Datum, einschließlich, Format YYYY-MM-DD (Ortszeit)."]
    }
    static func limitProperty(fallback: Int, maximum: Int) -> [String: Any] {
        [
            "type": "integer",
            "minimum": 1,
            "maximum": maximum,
            "default": fallback,
            "description": "Höchstzahl gelieferter Einträge (Standard \(fallback), Maximum \(maximum))."
        ]
    }
    static var offsetProperty: [String: Any] {
        ["type": "integer", "minimum": 0, "default": 0, "description": "Zum Blättern: Zahl der zu überspringenden Einträge."]
    }

    // MARK: - fleet_overview

    static var fleetOverview: Tool {
        Tool(
            name: "fleet_overview",
            description: """
                Überblick über den gesamten Fuhrpark: Gesamtkosten, Kosten je \
                Fahrzeug und je Jahr, Bestandszahlen sowie eine kompakte Liste \
                aller Fahrzeuge. Der übliche Einstiegspunkt – von hier aus mit \
                „vehicle_details“ oder den Listen-Werkzeugen weiterarbeiten.
                """,
            inputSchema: noArguments
        ) { _ in
            try withContext { context in
                let vehicles = try MCPQueries.allVehicles(in: context)

                let fuelCost = vehicles.reduce(Decimal.zero) { $0 + $1.totalFuelCost }
                let expenseCost = vehicles.reduce(Decimal.zero) { $0 + $1.totalExpenseCost }
                let reminders = vehicles.flatMap(\.sortedReminders)

                // Jahreskosten über alle Fahrzeuge zusammenfassen.
                var fuelByYear: [Int: Decimal] = [:]
                var expenseByYear: [Int: Decimal] = [:]
                for vehicle in vehicles {
                    for yearly in vehicle.costsByYear {
                        fuelByYear[yearly.year, default: 0] += yearly.fuel
                        expenseByYear[yearly.year, default: 0] += yearly.expense
                    }
                }
                let years = Set(fuelByYear.keys).union(expenseByYear.keys).sorted(by: >)

                // Kategorien flottenweit über den Namen zusammenfassen – die
                // Kategorie-Datensätze selbst hängen je Fahrzeug.
                var categoryTotals: [String: Decimal] = [:]
                for vehicle in vehicles {
                    for entry in vehicle.expenseCostByCategory {
                        categoryTotals[entry.category, default: 0] += entry.total
                    }
                }

                return [
                    "bestand": [
                        "fahrzeuge": vehicles.count,
                        "aktiv": vehicles.filter { !$0.decommissioned }.count,
                        "stillgelegt": vehicles.filter(\.decommissioned).count,
                        "betankungen": vehicles.reduce(0) { $0 + $1.fuelEntryCount },
                        "ausgaben": vehicles.reduce(0) { $0 + $1.expenseCount },
                        "erinnerungen": reminders.count
                    ],
                    "summen": [
                        "energiekosten": MCPValue.number(fuelCost),
                        "sonstigeKosten": MCPValue.number(expenseCost),
                        "gesamtkosten": MCPValue.number(fuelCost + expenseCost)
                    ],
                    "erinnerungen": [
                        "offen": reminders.filter { !$0.isDone }.count,
                        "faellig": reminders.filter(\.isDue).count,
                        "ueberfaellig": reminders.filter(\.isOverdue).count
                    ],
                    "kostenProJahr": years.map { year in
                        [
                            "jahr": year,
                            "betankungen": MCPValue.number(fuelByYear[year, default: 0]),
                            "sonstige": MCPValue.number(expenseByYear[year, default: 0]),
                            "gesamt": MCPValue.number(fuelByYear[year, default: 0] + expenseByYear[year, default: 0])
                        ]
                    },
                    "kostenJeFahrzeug": vehicles.map {
                        [
                            "kennzeichen": MCPValue.text($0.licensePlate),
                            "energiekosten": MCPValue.number($0.totalFuelCost),
                            "sonstigeKosten": MCPValue.number($0.totalExpenseCost),
                            "gesamtkosten": MCPValue.number($0.totalCost),
                            "stillgelegt": $0.decommissioned
                        ]
                    },
                    "kostenJeKategorie": categoryTotals
                        .sorted { $0.value > $1.value }
                        .map { ["kategorie": $0.key, "gesamt": MCPValue.number($0.value)] },
                    "hinweisKategorien": categoryWarning,
                    "fahrzeuge": vehicles.map(MCPQueries.vehicleSummary)
                ]
            }
        }
    }

    // MARK: - vehicle_details

    static var vehicleDetails: Tool {
        Tool(
            name: "vehicle_details",
            description: """
                Vollständiges Profil eines Fahrzeugs: Stammdaten, Kostensummen, \
                Preis- und Verbrauchsstatistik, Kosten pro Jahr, gefahrene \
                Kilometer pro Jahr, Kosten je Kategorie und Erinnerungszähler. \
                Ohne die Einzelbuchungen – die liefern „list_fuel_entries“ und \
                „list_expenses“.
                """,
            inputSchema: schema(
                ["vehicle": ["type": "string", "description": "Kennzeichen oder UUID des Fahrzeugs."]],
                required: ["vehicle"]
            )
        ) { arguments in
            guard let query = MCPQueries.string(arguments, "vehicle") else {
                throw MCPToolError.missingArgument("vehicle")
            }
            return try withContext { context in
                var result = MCPQueries.vehicleDetails(try MCPQueries.resolveVehicle(query, in: context))
                result["hinweisKategorien"] = categoryWarning
                return result
            }
        }
    }

    // MARK: - list_fuel_entries

    static var listFuelEntries: Tool {
        Tool(
            name: "list_fuel_entries",
            description: """
                Listet einzelne Betankungen bzw. Ladevorgänge mit Kilometerstand, \
                Menge, Preis und ermitteltem Verbrauch. Ergebnis ist paginiert. \
                Für Summen und Durchschnitte besser „vehicle_details“ oder \
                „cost_report“ verwenden.
                """,
            inputSchema: schema([
                "vehicle": vehicleProperty,
                "from": fromProperty,
                "to": toProperty,
                "station": ["type": "string", "description": "Teilstring der Tankstelle bzw. Ladestation."],
                "limit": limitProperty(fallback: 50, maximum: 200),
                "offset": offsetProperty,
                "sort": [
                    "type": "string",
                    "enum": ["datum_desc", "datum_asc", "kilometerstand_desc", "kilometerstand_asc"],
                    "default": "datum_desc"
                ]
            ])
        ) { arguments in
            let range = try MCPQueries.dateRange(arguments)
            let station = MCPQueries.string(arguments, "station")
            let limit = MCPQueries.integer(arguments, "limit", fallback: 50, maximum: 200)
            let offset = MCPQueries.integer(arguments, "offset", fallback: 0, maximum: 100_000)
            let sort = MCPQueries.string(arguments, "sort") ?? "datum_desc"

            return try withContext { context in
                var rows: [(entry: FuelEntry, previous: FuelEntry?, vehicle: Vehicle)] = []
                for vehicle in try MCPQueries.targetVehicles(arguments, in: context) {
                    let sorted = vehicle.sortedFuelEntries
                    for (index, entry) in sorted.enumerated() {
                        rows.append((entry, index > 0 ? sorted[index - 1] : nil, vehicle))
                    }
                }

                rows = rows.filter { range.contains($0.entry.date) }
                if let station {
                    rows = rows.filter { MCPQueries.matches($0.entry.station, station) }
                }

                switch sort {
                case "datum_asc":
                    rows.sort { ($0.entry.date ?? .distantPast) < ($1.entry.date ?? .distantPast) }
                case "kilometerstand_asc":
                    rows.sort { $0.entry.odometer < $1.entry.odometer }
                case "kilometerstand_desc":
                    rows.sort { $0.entry.odometer > $1.entry.odometer }
                default:
                    rows.sort { ($0.entry.date ?? .distantPast) > ($1.entry.date ?? .distantPast) }
                }

                let total = rows.count
                let items = rows.dropFirst(offset).prefix(limit).map {
                    MCPQueries.fuelEntry($0.entry, previous: $0.previous, vehicle: $0.vehicle)
                }

                let amount = rows.reduce(Decimal.zero) { $0 + ($1.entry.amount?.decimalValue ?? 0) }
                let quantity = rows.reduce(Decimal.zero) { $0 + ($1.entry.liters?.decimalValue ?? 0) }

                return MCPQueries.page(
                    items: Array(items),
                    total: total,
                    offset: offset,
                    extra: [
                        "summeGefiltert": [
                            "betrag": MCPValue.number(amount),
                            "menge": MCPValue.number(quantity, places: 3),
                            "durchschnittspreisGewichtet": MCPValue.number(
                                quantity > 0 ? amount / quantity : nil, places: 4
                            )
                        ]
                    ]
                )
            }
        }
    }

    // MARK: - list_expenses

    static var listExpenses: Tool {
        Tool(
            name: "list_expenses",
            description: """
                Listet sonstige Ausgaben und Einnahmen (keine Betankungen). \
                Einnahmen zählen in den Summen negativ – siehe „signedAmount“. \
                Ergebnis ist paginiert; „summeGefiltert“ bezieht sich auf die \
                gesamte gefilterte Menge, nicht nur auf die gelieferte Seite.
                """,
            inputSchema: schema([
                "vehicle": vehicleProperty,
                "from": fromProperty,
                "to": toProperty,
                "category": ["type": "string", "description": "Kategoriename (ohne Rücksicht auf Groß-/Kleinschreibung)."],
                "recipient": ["type": "string", "description": "Teilstring im Empfänger bzw. Zahler."],
                "type": [
                    "type": "string",
                    "enum": ["alle", "ausgabe", "einnahme"],
                    "default": "alle"
                ],
                "limit": limitProperty(fallback: 50, maximum: 200),
                "offset": offsetProperty,
                "sort": [
                    "type": "string",
                    "enum": ["datum_desc", "datum_asc", "betrag_desc", "betrag_asc"],
                    "default": "datum_desc"
                ]
            ])
        ) { arguments in
            let range = try MCPQueries.dateRange(arguments)
            let category = MCPQueries.string(arguments, "category")
            let recipient = MCPQueries.string(arguments, "recipient")
            let type = MCPQueries.string(arguments, "type") ?? "alle"
            let limit = MCPQueries.integer(arguments, "limit", fallback: 50, maximum: 200)
            let offset = MCPQueries.integer(arguments, "offset", fallback: 0, maximum: 100_000)
            let sort = MCPQueries.string(arguments, "sort") ?? "datum_desc"

            return try withContext { context in
                var rows = try MCPQueries.targetVehicles(arguments, in: context).flatMap(\.sortedExpenses)

                rows = rows.filter { range.contains($0.date) }
                if let category {
                    rows = rows.filter { expense in
                        expense.categoryNames.contains { $0.localizedCaseInsensitiveCompare(category) == .orderedSame }
                    }
                }
                if let recipient {
                    rows = rows.filter { MCPQueries.matches($0.recipient, recipient) }
                }
                switch type {
                case "ausgabe": rows = rows.filter { !$0.isIncome }
                case "einnahme": rows = rows.filter(\.isIncome)
                default: break
                }

                switch sort {
                case "datum_asc":
                    rows.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                case "betrag_desc":
                    rows.sort { ($0.amount?.decimalValue ?? 0) > ($1.amount?.decimalValue ?? 0) }
                case "betrag_asc":
                    rows.sort { ($0.amount?.decimalValue ?? 0) < ($1.amount?.decimalValue ?? 0) }
                default:
                    rows.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                }

                let total = rows.count
                let items = rows.dropFirst(offset).prefix(limit).map(MCPQueries.expense)

                return MCPQueries.page(
                    items: Array(items),
                    total: total,
                    offset: offset,
                    extra: [
                        "summeGefiltert": [
                            "bruttoSumme": MCPValue.number(rows.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? 0) }),
                            "nettoSumme": MCPValue.number(rows.reduce(Decimal.zero) { $0 + $1.signedAmount }),
                            "anzahlAusgaben": rows.filter { !$0.isIncome }.count,
                            "anzahlEinnahmen": rows.filter(\.isIncome).count
                        ]
                    ]
                )
            }
        }
    }

    // MARK: - list_reminders

    static var listReminders: Tool {
        Tool(
            name: "list_reminders",
            description: """
                Listet Erinnerungen (TÜV, Versicherung, Wartung und Ähnliches) \
                mit Fälligkeit, Vorlaufzeit und Wiederholung. Der Status wird \
                zum Zeitpunkt der Abfrage bestimmt: „faellig“ heißt, die \
                Vorlaufzeit hat begonnen; „ueberfaellig“ heißt, das \
                Fälligkeitsdatum ist überschritten.
                """,
            inputSchema: schema([
                "vehicle": vehicleProperty,
                "status": [
                    "type": "string",
                    "enum": ["offen", "faellig", "ueberfaellig", "erledigt", "alle"],
                    "default": "offen"
                ],
                "limit": limitProperty(fallback: 50, maximum: 200)
            ])
        ) { arguments in
            let status = MCPQueries.string(arguments, "status") ?? "offen"
            let limit = MCPQueries.integer(arguments, "limit", fallback: 50, maximum: 200)

            return try withContext { context in
                var rows = try MCPQueries.targetVehicles(arguments, in: context).flatMap(\.sortedReminders)

                switch status {
                case "faellig": rows = rows.filter(\.isDue)
                case "ueberfaellig": rows = rows.filter(\.isOverdue)
                case "erledigt": rows = rows.filter(\.isDone)
                case "alle": break
                default: rows = rows.filter { !$0.isDone }
                }

                rows.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                let total = rows.count
                let items = rows.prefix(limit).map(MCPQueries.reminder)

                return MCPQueries.page(
                    items: Array(items),
                    total: total,
                    offset: 0,
                    extra: ["status": status, "stichtag": MCPValue.localDay(Date())]
                )
            }
        }
    }

    // MARK: - cost_report

    static var costReport: Tool {
        Tool(
            name: "cost_report",
            description: """
                Aggregierte Kostenauswertung, wahlweise nach Jahr, Monat, \
                Kategorie oder Fahrzeug gruppiert. Ohne „vehicle“ über den \
                gesamten Fuhrpark. Einnahmen mindern die Summen. Kategorien \
                gelten nur für sonstige Ausgaben – Betankungen haben keine \
                Kategorie und werden dort separat ausgewiesen.
                """,
            inputSchema: schema(
                [
                    "groupBy": [
                        "type": "string",
                        "enum": ["jahr", "monat", "kategorie", "fahrzeug"],
                        "description": "Gruppierungsmerkmal."
                    ],
                    "vehicle": vehicleProperty,
                    "from": fromProperty,
                    "to": toProperty
                ],
                required: ["groupBy"]
            )
        ) { arguments in
            guard let groupBy = MCPQueries.string(arguments, "groupBy") else {
                throw MCPToolError.missingArgument("groupBy")
            }
            guard ["jahr", "monat", "kategorie", "fahrzeug"].contains(groupBy) else {
                throw MCPToolError.invalidArgument(
                    name: "groupBy",
                    reason: "erlaubt sind jahr, monat, kategorie oder fahrzeug"
                )
            }
            let range = try MCPQueries.dateRange(arguments)

            return try withContext { context in
                let vehicles = try MCPQueries.targetVehicles(arguments, in: context)
                let calendar = Calendar.current

                var fuelByKey: [String: Decimal] = [:]
                var expenseByKey: [String: Decimal] = [:]
                var fuelCount: [String: Int] = [:]
                var expenseCount: [String: Int] = [:]
                var fuelTotalOutsideGroups = Decimal.zero

                for vehicle in vehicles {
                    for entry in vehicle.sortedFuelEntries where range.contains(entry.date) {
                        let amount = entry.amount?.decimalValue ?? 0
                        guard let date = entry.date else { continue }
                        switch groupBy {
                        case "jahr":
                            let key = String(calendar.component(.year, from: date))
                            fuelByKey[key, default: 0] += amount
                            fuelCount[key, default: 0] += 1
                        case "monat":
                            let key = String(format: "%04d-%02d",
                                             calendar.component(.year, from: date),
                                             calendar.component(.month, from: date))
                            fuelByKey[key, default: 0] += amount
                            fuelCount[key, default: 0] += 1
                        case "fahrzeug":
                            let key = vehicle.licensePlate ?? "—"
                            fuelByKey[key, default: 0] += amount
                            fuelCount[key, default: 0] += 1
                        default:
                            // Betankungen haben keine Kategorie.
                            fuelTotalOutsideGroups += amount
                        }
                    }

                    for expense in vehicle.sortedExpenses where range.contains(expense.date) {
                        let amount = expense.signedAmount
                        guard let date = expense.date else { continue }
                        switch groupBy {
                        case "jahr":
                            let key = String(calendar.component(.year, from: date))
                            expenseByKey[key, default: 0] += amount
                            expenseCount[key, default: 0] += 1
                        case "monat":
                            let key = String(format: "%04d-%02d",
                                             calendar.component(.year, from: date),
                                             calendar.component(.month, from: date))
                            expenseByKey[key, default: 0] += amount
                            expenseCount[key, default: 0] += 1
                        case "fahrzeug":
                            let key = vehicle.licensePlate ?? "—"
                            expenseByKey[key, default: 0] += amount
                            expenseCount[key, default: 0] += 1
                        default:
                            let names = expense.categoryNames.isEmpty ? ["Ohne Kategorie"] : expense.categoryNames
                            for name in names {
                                expenseByKey[name, default: 0] += amount
                                expenseCount[name, default: 0] += 1
                            }
                        }
                    }
                }

                let keys = Set(fuelByKey.keys).union(expenseByKey.keys)
                let ordered: [String]
                if groupBy == "jahr" || groupBy == "monat" {
                    ordered = keys.sorted(by: >)
                } else {
                    ordered = keys.sorted {
                        (fuelByKey[$0, default: 0] + expenseByKey[$0, default: 0])
                            > (fuelByKey[$1, default: 0] + expenseByKey[$1, default: 0])
                    }
                }

                var result: [String: Any] = [
                    "gruppierung": groupBy,
                    "fahrzeug": vehicles.count == 1
                        ? MCPValue.text(vehicles[0].licensePlate)
                        : "alle Fahrzeuge (\(vehicles.count))",
                    "zeitraum": [
                        "von": MCPQueries.string(arguments, "from").map { $0 as Any } ?? NSNull(),
                        "bis": MCPQueries.string(arguments, "to").map { $0 as Any } ?? NSNull()
                    ],
                    "gruppen": ordered.map { key in
                        [
                            "schluessel": key,
                            "betankungen": MCPValue.number(fuelByKey[key, default: 0]),
                            "sonstige": MCPValue.number(expenseByKey[key, default: 0]),
                            "gesamt": MCPValue.number(fuelByKey[key, default: 0] + expenseByKey[key, default: 0]),
                            "anzahlBetankungen": fuelCount[key, default: 0],
                            "anzahlAusgaben": expenseCount[key, default: 0]
                        ]
                    },
                    "summe": MCPValue.number(
                        fuelByKey.values.reduce(Decimal.zero, +)
                            + expenseByKey.values.reduce(Decimal.zero, +)
                            + fuelTotalOutsideGroups
                    )
                ]

                if groupBy == "kategorie" {
                    result["hinweis"] = categoryWarning
                    result["betankungenOhneKategorie"] = MCPValue.number(fuelTotalOutsideGroups)
                }

                return result
            }
        }
    }

    // MARK: - search

    static var search: Tool {
        Tool(
            name: "search",
            description: """
                Volltextsuche über Fahrzeuge, Tankstellen, Empfänger, \
                Verwendungszwecke, Kategorien, Erinnerungstitel und \
                Belegdateinamen. Ohne Rücksicht auf Groß-/Kleinschreibung und \
                Umlaute. Nützlich, wenn die genaue Schreibweise unklar ist.
                """,
            inputSchema: schema(
                [
                    "query": ["type": "string", "description": "Suchbegriff (Teilstring)."],
                    "scope": [
                        "type": "string",
                        "enum": ["alle", "fahrzeuge", "betankungen", "ausgaben", "erinnerungen", "belege"],
                        "default": "alle"
                    ],
                    "limit": limitProperty(fallback: 25, maximum: 100)
                ],
                required: ["query"]
            )
        ) { arguments in
            guard let query = MCPQueries.string(arguments, "query") else {
                throw MCPToolError.missingArgument("query")
            }
            let scope = MCPQueries.string(arguments, "scope") ?? "alle"
            let limit = MCPQueries.integer(arguments, "limit", fallback: 25, maximum: 100)

            return try withContext { context in
                let vehicles = try MCPQueries.allVehicles(in: context)
                var hits: [[String: Any]] = []

                func wants(_ candidate: String) -> Bool { scope == "alle" || scope == candidate }

                if wants("fahrzeuge") {
                    for vehicle in vehicles where
                        MCPQueries.matches(vehicle.licensePlate, query)
                        || MCPQueries.matches(vehicle.manufacturer, query)
                        || MCPQueries.matches(vehicle.model, query) {
                        hits.append([
                            "typ": "fahrzeug",
                            "kennzeichen": MCPValue.text(vehicle.licensePlate),
                            "beschreibung": "\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")"
                                .trimmingCharacters(in: .whitespaces),
                            "gesamtkosten": MCPValue.number(vehicle.totalCost)
                        ])
                    }
                }

                if wants("betankungen") {
                    for vehicle in vehicles {
                        for entry in vehicle.sortedFuelEntries where MCPQueries.matches(entry.station, query) {
                            hits.append([
                                "typ": "betankung",
                                "kennzeichen": MCPValue.text(vehicle.licensePlate),
                                "datumLocal": MCPValue.localDay(entry.date),
                                "beschreibung": MCPValue.text(entry.station),
                                "betrag": MCPValue.number(entry.amount?.decimalValue)
                            ])
                        }
                    }
                }

                if wants("ausgaben") {
                    for vehicle in vehicles {
                        for expense in vehicle.sortedExpenses where
                            MCPQueries.matches(expense.recipient, query)
                            || MCPQueries.matches(expense.purpose, query)
                            || expense.categoryNames.contains(where: { MCPQueries.matches($0, query) }) {
                            hits.append([
                                "typ": "ausgabe",
                                "kennzeichen": MCPValue.text(vehicle.licensePlate),
                                "datumLocal": MCPValue.localDay(expense.date),
                                "beschreibung": "\(expense.recipient ?? "") – \(expense.purpose ?? "")",
                                "betrag": MCPValue.number(expense.amount?.decimalValue),
                                "istEinnahme": expense.isIncome,
                                "kategorien": expense.categoryNames
                            ])
                        }
                    }
                }

                if wants("erinnerungen") {
                    for vehicle in vehicles {
                        for reminder in vehicle.sortedReminders where MCPQueries.matches(reminder.title, query) {
                            hits.append([
                                "typ": "erinnerung",
                                "kennzeichen": MCPValue.text(vehicle.licensePlate),
                                "datumLocal": MCPValue.localDay(reminder.dueDate),
                                "beschreibung": MCPValue.text(reminder.title),
                                "faellig": reminder.isDue
                            ])
                        }
                    }
                }

                if wants("belege") {
                    let request = NSFetchRequest<Dokument>(entityName: "Dokument")
                    for document in try context.fetch(request) where MCPQueries.matches(document.filename, query) {
                        hits.append([
                            "typ": "beleg",
                            "kennzeichen": MCPValue.text(document.vehicle?.licensePlate),
                            "datumLocal": MCPValue.localDay(document.createdAt),
                            "beschreibung": document.filename
                        ])
                    }
                }

                let total = hits.count
                return MCPQueries.page(
                    items: Array(hits.prefix(limit)),
                    total: total,
                    offset: 0,
                    extra: ["suchbegriff": query, "bereich": scope]
                )
            }
        }
    }

    // MARK: - list_documents

    static var listDocuments: Tool {
        Tool(
            name: "list_documents",
            description: """
                Listet hinterlegte Belege und Rechnungen mit Dateiname, \
                zugehörigen Ausgaben und Ablagepfad. Ein Beleg kann mehrere \
                Ausgaben belegen – das Feld „ausgaben“ ist deshalb eine Liste. \
                Die Dateien selbst liegen \
                im Arbeitsverzeichnis, das in der App eingestellt ist; ist \
                keines gesetzt, bleibt der absolute Pfad leer.
                """,
            inputSchema: schema([
                "vehicle": vehicleProperty,
                "category": ["type": "string", "description": "Kategoriename der zugehörigen Ausgabe."],
                "from": fromProperty,
                "to": toProperty,
                "limit": limitProperty(fallback: 50, maximum: 200)
            ])
        ) { arguments in
            let range = try MCPQueries.dateRange(arguments)
            let category = MCPQueries.string(arguments, "category")
            let limit = MCPQueries.integer(arguments, "limit", fallback: 50, maximum: 200)
            let vehicleQuery = MCPQueries.string(arguments, "vehicle")

            return try withContext { context in
                let plate = try vehicleQuery.map { try MCPQueries.resolveVehicle($0, in: context).licensePlate }

                let request = NSFetchRequest<Dokument>(entityName: "Dokument")
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Dokument.createdAt, ascending: false)]
                var rows = try context.fetch(request)

                if let plate {
                    rows = rows.filter { $0.vehicle?.licensePlate == plate }
                }
                rows = rows.filter { range.contains($0.createdAt) }
                if let category {
                    rows = rows.filter { document in
                        document.categoryNames.contains { $0.localizedCaseInsensitiveCompare(category) == .orderedSame }
                    }
                }

                let total = rows.count
                return MCPQueries.page(
                    items: rows.prefix(limit).map(MCPQueries.document),
                    total: total,
                    offset: 0,
                    extra: [
                        "arbeitsverzeichnis": WorkingDirectoryStore.displayPath.map { $0 as Any } ?? NSNull()
                    ]
                )
            }
        }
    }

    // MARK: - diagnostics

    /// Selbstauskunft. Muss auch dann antworten, wenn die Datenbank nicht
    /// geöffnet werden kann – sonst stünde der Nutzer im Fehlerfall ohne
    /// jeden Anhaltspunkt da.
    static var diagnostics: Tool {
        Tool(
            name: "diagnostics",
            description: """
                Prüft die Verbindung zur Fuhrpark-Datenbank und liefert Pfad, \
                App-Version und Datensatzzahlen. Bei Problemen mit den anderen \
                Werkzeugen hiermit anfangen.
                """,
            inputSchema: noArguments
        ) { _ in
            let storePath = MCPPersistence.storeURL.path
            var report: [String: Any] = [
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
                "storePfad": storePath,
                "storeVorhanden": FileManager.default.fileExists(atPath: storePath),
                "zugriff": "nur lesend",
                "arbeitsverzeichnisBelege": WorkingDirectoryStore.displayPath.map { $0 as Any } ?? NSNull()
            ]

            do {
                let counts = try withContext { context -> [String: Int] in
                    var counts: [String: Int] = [:]
                    for name in MCPMain.entityNames {
                        counts[name] = try context.count(for: NSFetchRequest<NSManagedObject>(entityName: name))
                    }
                    return counts
                }
                report["datenbankGeoeffnet"] = true
                report["datensaetze"] = [
                    "fahrzeuge": counts["Vehicle"] ?? 0,
                    "betankungen": counts["FuelEntry"] ?? 0,
                    "ausgaben": counts["Expense"] ?? 0,
                    "kategorien": counts["Category"] ?? 0,
                    "dokumente": counts["Dokument"] ?? 0,
                    "erinnerungen": counts["Erinnerung"] ?? 0
                ]
            } catch {
                report["datenbankGeoeffnet"] = false
                report["fehler"] = error.localizedDescription
            }

            return report
        }
    }
}
