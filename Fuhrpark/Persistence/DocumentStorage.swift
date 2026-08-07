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

    /// Entfernt aus dem Arbeitsverzeichnis alle Belegordner, die nicht in
    /// `keeping` stehen – gleicht den Ordner also an den Datenbankstand an.
    ///
    /// Drei Schutzgitter, weil das Arbeitsverzeichnis ein ganz normaler
    /// Nutzerordner ist und hier als einziger Code Nutzerdateien löscht:
    /// Es wird nur angefasst, was ein Verzeichnis ist, dessen Name sich als
    /// UUID lesen lässt. Alles andere – `.DS_Store`, eigene Unterordner,
    /// versehentlich dort abgelegte Dateien – bleibt unberührt.
    static func removeFolders(keeping ids: Set<UUID>) {
        try? WorkingDirectoryStore.withAccess { workingDirURL in
            let inhalt = try FileManager.default.contentsOfDirectory(
                at: workingDirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for eintrag in inhalt {
                guard
                    (try? eintrag.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                    let id = UUID(uuidString: eintrag.lastPathComponent),
                    !ids.contains(id)
                else { continue }
                try? FileManager.default.removeItem(at: eintrag)
            }
        }
    }
}
