import CoreData
import Foundation

/// Auskunft darüber, welche Ausgabe der App gerade läuft – die produktive
/// oder der Testbau.
///
/// Debug- und Release-Build tragen unterschiedliche Bundle-IDs (siehe
/// `project.yml`). Da die App sandboxed ist, hängt daran der gesamte
/// Container: eigene Datenbank, eigene UserDefaults, eigene Berechtigungen.
/// Beide Ausgaben lassen sich deshalb gefahrlos nebeneinander betreiben.
///
/// Die Unterscheidung wird bewusst aus der **Bundle-ID** abgeleitet und nicht
/// aus `#if DEBUG`: Dasselbe Binary läuft auch als MCP-Server. Ein
/// Compiler-Flag könnte mit dem tatsächlich geöffneten Container
/// auseinanderlaufen, die Bundle-ID kann es nicht – sie *ist* der Container.
enum AppVariant {

    /// Läuft gerade der Testbau (eigener Container, nicht die echten Daten)?
    static var isTestContainer: Bool {
        Bundle.main.bundleIdentifier?.hasSuffix(".debug") == true
    }

    /// Titel des Hauptfensters, zugleich der Eintrag im „Fenster“-Menü.
    static var windowTitle: String {
        isTestContainer ? "FuhrparkDesktop Debug" : "FuhrparkDesktop"
    }

    /// Kurzbezeichnung für Anzeigen, in denen der Datenbestand zählt.
    static var containerLabel: String {
        isTestContainer ? "Testdaten (Debug-Container)" : "Echte Daten"
    }

    /// Name, unter dem sich der MCP-Server bei einem Client meldet und
    /// eingetragen wird. Ohne die Unterscheidung überschriebe die
    /// Einrichtung des Testbaus die Registrierung der produktiven App.
    static var mcpServerName: String {
        isTestContainer ? "fuhrpark-debug" : "fuhrpark"
    }

    /// Verzeichnis, in dem `Fuhrpark.sqlite` liegt – derselbe Standardpfad,
    /// den `PersistenceController` und `MCPPersistence` verwenden. Nur zur
    /// Anzeige, damit im Zweifel ablesbar ist, welcher Bestand bedient wird.
    static var storeDirectory: URL {
        NSPersistentContainer.defaultDirectoryURL()
    }
}
