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
/// Sämtliche Werkzeuge sind ausschließlich lesend – es gibt in diesem Modus
/// keinen Pfad, der Daten verändert.
enum MCPToolCatalog {

    struct Tool {
        let name: String
        let description: String
        let inputSchema: [String: Any]
        let run: ([String: Any]) throws -> [String: Any]
    }

    /// Wird dem Modell beim Verbindungsaufbau mitgegeben. Enthält die
    /// Eigenheiten der Datenlogik, die man kennen muss, um die Zahlen richtig
    /// zu deuten – ohne sie zieht das Modell falsche Schlüsse.
    static let serverInstructions = """
        Zugriff auf die Fuhrparkdaten der App FuhrparkDesktop (nur lesend).

        Vier Eigenheiten der Datenlogik, die für die Auswertung wichtig sind:

        1. Einnahmen zählen in allen Kostensummen NEGATIV. Das Feld „amount“ ist
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

        Für Jahres- und Monatszuordnungen immer die Felder mit der Endung
        „Local“ verwenden (Kalendertag in der Zeitzone des Nutzers), nicht die
        UTC-Zeitstempel.

        Einstiegspunkt ist „fleet_overview“.
        """

    static var all: [Tool] {
        [diagnostics]
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

    /// Schema für Werkzeuge ohne Parameter.
    static var noArguments: [String: Any] {
        ["type": "object", "properties": [String: Any](), "additionalProperties": false]
    }

    /// Führt einen Block mit einem frisch geladenen Core-Data-Stack aus.
    ///
    /// Bewusst pro Aufruf neu: Nur so sind auch die Änderungen sichtbar, die
    /// eine parallel laufende GUI-Instanz zwischenzeitlich gespeichert hat. Bei
    /// dieser Datenmenge kostet das Laden kaum messbare Zeit.
    static func withContext<T>(_ body: (NSManagedObjectContext) throws -> T) throws -> T {
        try body(try MCPPersistence.loadContainer().viewContext)
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
                "zugriff": "nur lesend"
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
