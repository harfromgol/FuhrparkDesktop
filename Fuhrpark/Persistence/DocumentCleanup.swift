import CoreData
import Foundation

/// Hält nach jedem Löschvorgang die Belege in Ordnung.
///
/// Leitidee: **Das Arbeitsverzeichnis enthält genau die Ordner, die die
/// Datenbank kennt.** Statt an vier Löschpfaden je einzeln zu entscheiden,
/// welche Datei mit weg darf, stellt jeder Pfad am Ende diese eine Invariante
/// wieder her. Nötig wurde das, seit ein Beleg mehrere Ausgaben belegen kann:
/// Er darf erst verschwinden, wenn die letzte davon weg ist.
enum DocumentCleanup {

    /// Nach jedem Löschen aufzurufen: verwaiste Belege entfernen, speichern,
    /// danach das Arbeitsverzeichnis angleichen.
    static func finishDeletion(in context: NSManagedObjectContext) {
        removeOrphanedDocuments(in: context)
        PersistenceController.shared.save(context: context)
        sweepWorkingDirectory(in: context)
    }

    /// Löscht Belege, auf die keine Ausgabe mehr zeigt. Nur Core Data.
    ///
    /// Bewusst im Speicher gefiltert statt per Prädikat `expenses.@count == 0`:
    /// Die Löschregeln laufen erst beim Speichern durch, ein Prädikat sähe den
    /// Stand von vorher. Deshalb wird auf **beiden** Seiten `isDeleted`
    /// geprüft – dann ist das Ergebnis unabhängig davon, wann Core Data die
    /// Cascade-Regel von `Vehicle.expenses` tatsächlich verarbeitet.
    @discardableResult
    static func removeOrphanedDocuments(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<Dokument>(entityName: "Dokument")
        guard let documents = try? context.fetch(request) else { return 0 }

        var entfernt = 0
        for document in documents where !document.isDeleted {
            let lebendeAusgaben = ((document.expense as? Set<Expense>) ?? [])
                .filter { !$0.isDeleted }
            if lebendeAusgaben.isEmpty {
                context.delete(document)
                entfernt += 1
            }
        }
        return entfernt
    }

    /// Gleicht das Arbeitsverzeichnis an den Datenbankstand an.
    ///
    /// Der Fetch muss **erfolgreich** sein: Ein Fehlschlag darf niemals als
    /// „null Belege“ durchgehen, sonst kostet ein beliebiger Störfall den
    /// gesamten Belegbestand. Ein leeres Ergebnis ist dagegen legitim – etwa
    /// nach „Alle Daten löschen“.
    static func sweepWorkingDirectory(in context: NSManagedObjectContext) {
        guard WorkingDirectoryStore.isConfigured else { return }

        let request = NSFetchRequest<Dokument>(entityName: "Dokument")
        guard let documents = try? context.fetch(request) else { return }

        let bekannteIDs = Set(documents.compactMap { $0.isDeleted ? nil : $0.id })
        DocumentStorage.removeFolders(keeping: bekannteIDs)
    }
}
