import CoreData

/// Migriert Dokumente aus der alten Speicherform (Security-Scoped Bookmark
/// auf die Originaldatei am ursprünglichen Speicherort) in eine Kopie im
/// aktuell konfigurierten Arbeitsverzeichnis.
///
/// `bookmarkData != nil` dient als implizites Migrations-Flag: Das Attribut
/// war früher ein Pflichtfeld, jedes Altbestand-Dokument hat also garantiert
/// eines; migrierte/neu angelegte Dokumente setzen es auf `nil`. Dadurch ist
/// die Migration idempotent und kann gefahrlos mehrfach aufgerufen werden
/// (z. B. bei jeder (Neu-)Wahl des Arbeitsverzeichnisses und bei jedem
/// App-Start, falls ein vorheriger Lauf unterbrochen wurde).
enum DocumentMigration {
    struct Failure {
        let documentID: UUID
        let filename: String
        let reason: String
    }

    /// Nimmt den `PersistenceController` explizit entgegen (statt über
    /// `PersistenceController.shared` zuzugreifen), damit dieser Aufruf auch
    /// aus `PersistenceController.init` selbst heraus funktioniert – ein
    /// Zugriff auf `.shared` während der eigenen Initialisierung würde dort
    /// in einen Deadlock laufen (rekursiver `static let`-Zugriff).
    @discardableResult
    static func migrateLegacyDocuments(using controller: PersistenceController) -> [Failure] {
        guard WorkingDirectoryStore.isConfigured else { return [] }

        let context = controller.container.viewContext
        let request = NSFetchRequest<Dokument>(entityName: "Dokument")
        request.predicate = NSPredicate(format: "bookmarkData != nil")
        guard let legacyDocuments = try? context.fetch(request), !legacyDocuments.isEmpty else { return [] }

        var failures: [Failure] = []
        for document in legacyDocuments {
            guard let id = document.id, let bookmark = document.bookmarkData else { continue }
            let filename = document.filename

            var isStale = false
            guard let sourceURL = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), sourceURL.startAccessingSecurityScopedResource() else {
                failures.append(Failure(documentID: id, filename: filename, reason: "Ursprungsdatei nicht mehr auffindbar."))
                continue
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            do {
                document.path = try DocumentStorage.copyIntoWorkingDirectory(from: sourceURL, documentID: id)
                document.bookmarkData = nil
                controller.save(context: context)
            } catch {
                failures.append(Failure(documentID: id, filename: filename, reason: error.localizedDescription))
            }
        }
        return failures
    }
}
