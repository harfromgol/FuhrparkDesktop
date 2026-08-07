import CoreData
import Foundation

/// Minimaler, ausschließlich lesender Core-Data-Zugang für den MCP-Modus.
///
/// Bewusst **nicht** `PersistenceController`: dessen `init` bricht bei einem
/// Store-Fehler mit `fatalError` ab und führt beim Start zwei schreibende
/// Wartungsschritte aus (Zeitstempel-Backfill, Dokument-Migration). Beides ist
/// in einem Nur-Lese-Prozess unerwünscht – und ein Absturz würde den
/// Protokollstrom abreißen lassen, ohne dass der Client eine verwertbare
/// Meldung bekommt.
enum MCPPersistence {

    enum StoreError: LocalizedError {
        case loadFailed(String)

        var errorDescription: String? {
            switch self {
            case .loadFailed(let reason):
                "Die Datenbank konnte nicht geöffnet werden: \(reason)"
            }
        }
    }

    /// Pfad des SQLite-Stores – derselbe Default-Pfad, den auch die App nutzt,
    /// also innerhalb des Sandbox-Containers der App.
    static var storeURL: URL {
        NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("Fuhrpark.sqlite")
    }

    /// Lädt einen frischen Core-Data-Stack.
    ///
    /// Das Ergebnis wird bewusst nicht dauerhaft gehalten: Ein neu geladener
    /// Stack sieht garantiert auch die Änderungen, die eine parallel laufende
    /// GUI-Instanz zwischenzeitlich gespeichert hat. Ein langlebiger
    /// Coordinator würde stattdessen aus seinem Zeilen-Zwischenspeicher
    /// bedienen und veraltete Werte liefern.
    ///
    /// Der Store wird absichtlich **ohne** `NSReadOnlyPersistentStoreOption`
    /// geöffnet: SQLite braucht zum Lesen des Write-Ahead-Logs Schreibrecht auf
    /// die zugehörige `-shm`-Datei. Nur-Lesen würde bedeuten, noch nicht
    /// eingecheckpointete Änderungen der App zu übersehen. Geschrieben wird
    /// hier dennoch nie – im MCP-Modus existiert kein `save()`-Pfad.
    static func loadContainer() throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "Fuhrpark")

        // Migration hier ausdrücklich abschalten.
        //
        // Der MCP-Server wird vom Client als Kindprozess gestartet – ohne
        // Fenster und ohne Fehlerdialog. Mit den Voreinstellungen könnte
        // eine beiläufige KI-Anfrage eine Modellmigration der echten Daten
        // anstoßen, die niemand sieht und niemand bestätigt hat. Eine
        // Migration gehört in die sichtbare App; hier wird stattdessen ein
        // verständlicher Fehler gemeldet.
        for description in container.persistentStoreDescriptions {
            description.shouldMigrateStoreAutomatically = false
            description.shouldInferMappingModelAutomatically = false
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw StoreError.loadFailed(loadError.localizedDescription)
        }

        return container
    }
}
