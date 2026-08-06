import CoreData
import Foundation

/// Einstiegspunkte des MCP-Modus. Werden aus `main.swift` aufgerufen, bevor
/// AppKit initialisiert wird – im Serverbetrieb entsteht daher weder ein
/// Fenster noch ein Dock-Symbol.
enum MCPMain {

    /// Alle Entitäten des Modells, in der Reihenfolge, in der sie in der
    /// Diagnose ausgegeben werden.
    static let entityNames = ["Vehicle", "FuelEntry", "Expense", "Category", "Dokument", "Erinnerung"]

    /// Diagnose-Durchstich (`--mcp-probe`): prüft, ob das direkt gestartete,
    /// sandboxed App-Binary seinen eigenen Container erreicht und die Datenbank
    /// lesen kann. Schreibt ausschließlich nach stderr und beendet den Prozess.
    static func runProbe() -> Never {
        func log(_ text: String) {
            FileHandle.standardError.write(Data((text + "\n").utf8))
        }

        log("── FuhrparkDesktop MCP-Probe ──")
        log("Bundle-ID:  \(Bundle.main.bundleIdentifier ?? "—")")
        log("Store-Pfad: \(MCPPersistence.storeURL.path)")
        log("Vorhanden:  \(FileManager.default.fileExists(atPath: MCPPersistence.storeURL.path))")
        log("Lesbar:     \(FileManager.default.isReadableFile(atPath: MCPPersistence.storeURL.path))")

        do {
            let context = try MCPPersistence.loadContainer().viewContext

            log("Datensätze:")
            for name in entityNames {
                let count = try context.count(for: NSFetchRequest<NSManagedObject>(entityName: name))
                log("  \(name): \(count)")
            }

            let vehicles = try context.fetch(NSFetchRequest<Vehicle>(entityName: "Vehicle"))
            log("Fahrzeuge:")
            for vehicle in vehicles {
                log("  \(vehicle.licensePlate ?? "—") – Gesamtkosten \(vehicle.totalCost)")
            }

            log("ERGEBNIS: Zugriff erfolgreich.")
            exit(0)
        } catch {
            log("ERGEBNIS: FEHLGESCHLAGEN – \(error.localizedDescription)")
            exit(1)
        }
    }

    /// Der eigentliche MCP-Server (`--mcp-stdio`).
    ///
    /// Läuft, bis der Client den Eingabestrom schließt. Ein fehlender oder
    /// unlesbarer Datenbestand ist bewusst kein Startfehler: Der Server läuft
    /// trotzdem an und meldet das Problem erst beim Werkzeugaufruf – über
    /// `diagnostics` bekommt der Nutzer dann eine verwertbare Meldung statt
    /// eines wortlos abbrechenden Prozesses.
    static func runServer() -> Never {
        let transport = MCPTransport()
        transport.log("bereit")
        MCPServer(transport: transport).run()
        exit(0)
    }
}
