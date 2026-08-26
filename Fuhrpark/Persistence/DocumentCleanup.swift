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

    /// Löscht Belege, auf die weder eine Ausgabe noch eine Notiz mehr zeigt.
    /// Nur Core Data.
    ///
    /// Bewusst im Speicher gefiltert statt per Prädikat `expenses.@count == 0`:
    /// Die Löschregeln laufen erst beim Speichern durch, ein Prädikat sähe den
    /// Stand von vorher. Deshalb wird auf **beiden** Seiten `isDeleted`
    /// geprüft – dann ist das Ergebnis unabhängig davon, wann Core Data die
    /// Cascade-Regel von `Vehicle.expenses`/`Vehicle.notizen` tatsächlich
    /// verarbeitet.
    @discardableResult
    static func removeOrphanedDocuments(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<Dokument>(entityName: "Dokument")
        guard let documents = try? context.fetch(request) else { return 0 }

        var entfernt = 0
        for document in documents where !document.isDeleted {
            let lebendeAusgaben = ((document.expense as? Set<Expense>) ?? [])
                .filter { !$0.isDeleted }
            let lebendeNotizen = ((document.notizen as? Set<Notiz>) ?? [])
                .filter { !$0.isDeleted }
            if lebendeAusgaben.isEmpty && lebendeNotizen.isEmpty {
                context.delete(document)
                entfernt += 1
            }
        }
        return entfernt
    }

    /// Belegordner im Arbeitsverzeichnis, zu denen dieser Datenbestand keinen
    /// Beleg kennt – also genau das, was `sweepWorkingDirectory` beim nächsten
    /// Löschvorgang entfernt.
    ///
    /// Dieselbe Quelle für Hinweis und Löschung: Beim Festlegen des
    /// Arbeitsverzeichnisses zeigt `DocumentsView` das Ergebnis an, damit
    /// niemand versehentlich das Belegverzeichnis eines anderen Datenbestands
    /// wählt (Debug- und Release-Ausgabe haben getrennte Datenbanken, siehe
    /// `AppVariant`). Eine eigene Zählung für die Anzeige könnte beruhigen, wo
    /// tatsächlich gelöscht wird.
    ///
    /// Der Fetch muss **erfolgreich** sein: Ein Fehlschlag darf niemals als
    /// „null Belege“ durchgehen, sonst kostet ein beliebiger Störfall den
    /// gesamten Belegbestand. Deshalb liefert er im Fehlerfall die leere
    /// Menge, es wird also nichts entfernt. Ein leeres Ergebnis der Datenbank
    /// ist dagegen legitim – etwa nach „Alle Daten löschen“.
    static func unknownFolderIDs(in context: NSManagedObjectContext) -> Set<UUID> {
        guard
            WorkingDirectoryStore.isConfigured,
            let ordnerIDs = try? DocumentStorage.documentFolderIDs(),
            !ordnerIDs.isEmpty
        else { return [] }

        let request = NSFetchRequest<Dokument>(entityName: "Dokument")
        guard let documents = try? context.fetch(request) else { return [] }

        let bekannteIDs = Set(documents.compactMap { $0.isDeleted ? nil : $0.id })
        return ordnerIDs.subtracting(bekannteIDs)
    }

    /// Fahrzeug-IDs, zu denen im `Fahrzeugbilder`-Ordner eine Bilddatei liegt,
    /// aber kein (mehr) lebendes Fahrzeug existiert. Analog zu
    /// `unknownFolderIDs`, nur für `VehiclePhotoStorage` statt `DocumentStorage`.
    static func unknownPhotoVehicleIDs(in context: NSManagedObjectContext) -> Set<UUID> {
        guard
            WorkingDirectoryStore.isConfigured,
            let fotoIDs = try? VehiclePhotoStorage.photoFileVehicleIDs(),
            !fotoIDs.isEmpty
        else { return [] }

        let request = NSFetchRequest<Vehicle>(entityName: "Vehicle")
        guard let vehicles = try? context.fetch(request) else { return [] }

        let bekannteIDs = Set(vehicles.compactMap { $0.isDeleted ? nil : $0.id })
        return fotoIDs.subtracting(bekannteIDs)
    }

    /// Gleicht das Arbeitsverzeichnis an den Datenbankstand an.
    static func sweepWorkingDirectory(in context: NSManagedObjectContext) {
        DocumentStorage.removeFolders(withIDs: unknownFolderIDs(in: context))
        VehiclePhotoStorage.removeFiles(withIDs: unknownPhotoVehicleIDs(in: context))
    }
}
