import Foundation

/// Kopiert Dokument-Dateien in einen Unterordner je Dokument-ID innerhalb
/// des `WorkingDirectoryStore`-Arbeitsverzeichnisses und löst sie dort
/// wieder auf. Ein Unterordner pro Dokument-ID macht Namenskollisionen
/// strukturell unmöglich und macht Löschen trivial (ganzer Ordner weg).
enum DocumentStorage {
    enum StorageError: LocalizedError {
        case copyFailed(filename: String)
        case fileNotFound(filename: String)

        var errorDescription: String? {
            switch self {
            case .copyFailed(let filename):
                return "„\(filename)“ konnte nicht ins Arbeitsverzeichnis kopiert werden."
            case .fileNotFound(let filename):
                return "„\(filename)“ wurde im Arbeitsverzeichnis nicht gefunden."
            }
        }
    }

    /// Kopiert `sourceURL` (bereits Security-Scope-zugreifbar) ins aktuelle
    /// Arbeitsverzeichnis, in einen Unterordner `documentID`. Liefert den
    /// relativen Pfad ("<uuid>/<Dateiname>") zurück, der in `Dokument.path`
    /// gespeichert wird. Ein evtl. bereits vorhandener Zielordner wird vorher
    /// entfernt (idempotent, wichtig für Migrations-Retries).
    @discardableResult
    static func copyIntoWorkingDirectory(from sourceURL: URL, documentID: UUID) throws -> String {
        try WorkingDirectoryStore.withAccess { workingDirURL in
            let folder = workingDirURL.appendingPathComponent(documentID.uuidString, isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent(sourceURL.lastPathComponent)
                try FileManager.default.copyItem(at: sourceURL, to: destination)
            } catch {
                throw StorageError.copyFailed(filename: sourceURL.lastPathComponent)
            }
            return "\(documentID.uuidString)/\(sourceURL.lastPathComponent)"
        }
    }

    /// Löst den relativen Pfad zu einer absoluten URL im aktuellen
    /// Arbeitsverzeichnis auf und prüft, dass die Datei existiert.
    static func resolvedURL(forRelativePath path: String) throws -> URL {
        try WorkingDirectoryStore.withAccess { workingDirURL in
            let url = workingDirURL.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw StorageError.fileNotFound(filename: url.lastPathComponent)
            }
            return url
        }
    }

    /// Löscht den Ablageordner eines Belegs. Best-effort – Fehler werden
    /// ignoriert, damit sie nie das Löschen des Core-Data-Eintrags blockieren.
    ///
    /// Nimmt bewusst die Dokument-ID und nicht mehr den relativen Pfad: Die
    /// frühere Fassung leitete den Ordner per `deletingLastPathComponent()`
    /// aus dem Pfad ab. Enthielt der keinen Schrägstrich – über eine
    /// importierte JSON-Datei erreichbar –, zeigte das Ergebnis auf das
    /// Arbeitsverzeichnis selbst und hätte dessen kompletten Inhalt gelöscht.
    static func delete(documentID: UUID) {
        try? WorkingDirectoryStore.withAccess { workingDirURL in
            let folder = workingDirURL.appendingPathComponent(documentID.uuidString, isDirectory: true)
            try FileManager.default.removeItem(at: folder)
        }
    }

    /// IDs aller Belegordner, die im Arbeitsverzeichnis liegen.
    ///
    /// Hier sitzen die Schutzgitter, weil das Arbeitsverzeichnis ein ganz
    /// normaler Nutzerordner ist: Aufgenommen wird nur, was ein Verzeichnis
    /// ist **und** dessen Name sich als UUID lesen lässt. Alles andere –
    /// `.DS_Store`, eigene Unterordner, versehentlich dort abgelegte Dateien –
    /// kommt gar nicht erst in die Menge und kann damit auch nicht gelöscht
    /// werden.
    static func documentFolderIDs() throws -> Set<UUID> {
        try WorkingDirectoryStore.withAccess { workingDirURL in
            let inhalt = try FileManager.default.contentsOfDirectory(
                at: workingDirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return Set(inhalt.compactMap { eintrag -> UUID? in
                guard (try? eintrag.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                else { return nil }
                return UUID(uuidString: eintrag.lastPathComponent)
            })
        }
    }

    /// Entfernt genau die angegebenen Belegordner.
    ///
    /// Nimmt bewusst die zu **löschende** Menge entgegen und nicht die zu
    /// behaltende: So ist derselbe Satz IDs, den `DocumentCleanup` ermittelt
    /// und den der Nutzer beim Festlegen des Arbeitsverzeichnisses als Hinweis
    /// zu sehen bekommt, auch wirklich der gelöschte. Eine zweite,
    /// eigenständige Auswahllogik könnte davon abweichen – und ein Hinweis,
    /// der nicht zur Tat passt, ist schlimmer als keiner.
    static func removeFolders(withIDs ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        try? WorkingDirectoryStore.withAccess { workingDirURL in
            for id in ids {
                let folder = workingDirURL.appendingPathComponent(id.uuidString, isDirectory: true)
                try? FileManager.default.removeItem(at: folder)
            }
        }
    }
}
