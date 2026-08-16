import Foundation
import AppleArchive
import System

/// Kopfdaten einer Sicherung. Liegt als `manifest.json` im Archiv und wird
/// beim Einspielen als Erstes gelesen – daran entscheidet sich, ob überhaupt
/// nach einem Ordner für die Belege gefragt werden muss.
struct BackupManifest: Codable {
    /// Aufbau des Archivs. Wird beim Einspielen geprüft; ein Archiv mit
    /// höherer Nummer wird abgelehnt statt halb eingelesen.
    let formatVersion: Int
    /// App-Version, die das Archiv geschrieben hat – nur zur Anzeige.
    let appVersion: String
    let createdAt: Date
    /// Anzahl der mitgesicherten Belegordner. `0` heißt: keine Ordnerabfrage
    /// beim Einspielen nötig.
    let documentFolderCount: Int
    /// Wo die Belege beim Sichern lagen – als Vorschlag beim Einspielen.
    let originalWorkingDirectoryPath: String?

    /// Aktueller Aufbau. Erhöhen, sobald sich die Anordnung im Archiv ändert.
    static let currentFormatVersion = 1
}

enum BackupArchiveError: LocalizedError {
    case streamCreationFailed
    case unreadable
    case unsupportedFormat(found: Int, supported: Int)
    case incomplete(missing: String)

    var errorDescription: String? {
        switch self {
        case .streamCreationFailed:
            return "Das Archiv konnte nicht angelegt werden."
        case .unreadable:
            return "Die Datei ist kein gültiges FuhrparkDesktop-Backup."
        case .unsupportedFormat(let found, let supported):
            return """
                Dieses Backup wurde von einer neueren Version von FuhrparkDesktop \
                erstellt (Format \(found), unterstützt wird \(supported)). \
                Bitte zuerst die App aktualisieren.
                """
        case .incomplete(let missing):
            return "Das Backup ist unvollständig – „\(missing)“ fehlt."
        }
    }
}

/// Packt ein Verzeichnis in ein einzelnes LZFSE-komprimiertes Apple-Archiv
/// und wieder zurück.
///
/// `AppleArchive` und `System` sind Apple-Frameworks – das Projekt bleibt
/// damit ohne externe Abhängigkeiten. Bewusst kein ZIP über
/// `NSFileCoordinator(.forUploading)`: Das liefert zwar auch ein Archiv,
/// aber ohne Kontrolle über Kompressionsverfahren und Metadaten.
enum BackupArchive {
    /// Metadaten, die pro Eintrag ins Archiv geschrieben werden.
    ///
    /// Bewusst **ohne** `UID`/`GID`: Wird eine Sicherung unter einer anderen
    /// Benutzerkennung eingespielt – anderer Mac, anderes Konto –, scheiterte
    /// das Entpacken sonst am Setzen der Eigentümerrechte.
    private static let fieldKeys = "TYP,PAT,LNK,DAT,MOD,MTM"

    /// Packt den **Inhalt** von `stagingDirectory` (nicht den Ordner selbst)
    /// nach `archiveURL`.
    static func encode(stagingDirectory: URL, to archiveURL: URL) throws {
        guard let keySet = ArchiveHeader.FieldKeySet(fieldKeys) else {
            throw BackupArchiveError.streamCreationFailed
        }

        // Die drei Ströme müssen in umgekehrter Reihenfolge geschlossen
        // werden (erst encode, dann compress, zuletzt die Datei) – sonst
        // bleibt der Kompressionspuffer ungeschrieben und das Archiv ist
        // abgeschnitten. Genau das leisten die `defer` in dieser Reihenfolge:
        // sie laufen umgekehrt zur Deklaration ab.
        guard let fileStream = ArchiveByteStream.fileStream(
            path: FilePath(archiveURL.path),
            mode: .writeOnly,
            options: [.create, .truncate],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            throw BackupArchiveError.streamCreationFailed
        }
        defer { try? fileStream.close() }

        guard let compressStream = ArchiveByteStream.compressionStream(
            using: .lzfse,
            writingTo: fileStream
        ) else {
            throw BackupArchiveError.streamCreationFailed
        }
        defer { try? compressStream.close() }

        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
            throw BackupArchiveError.streamCreationFailed
        }
        defer { try? encodeStream.close() }

        try encodeStream.writeDirectoryContents(
            archiveFrom: FilePath(stagingDirectory.path),
            keySet: keySet
        )
    }

    /// Entpackt `archiveURL` nach `destinationDirectory` (muss existieren).
    static func decode(archiveURL: URL, to destinationDirectory: URL) throws {
        guard let fileStream = ArchiveByteStream.fileStream(
            path: FilePath(archiveURL.path),
            mode: .readOnly,
            options: [],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            throw BackupArchiveError.unreadable
        }
        defer { try? fileStream.close() }

        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: fileStream) else {
            throw BackupArchiveError.unreadable
        }
        defer { try? decompressStream.close() }

        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
            throw BackupArchiveError.unreadable
        }
        defer { try? decodeStream.close() }

        // `.ignoreOperationNotPermitted`: Einzelne Metadaten (etwa Zeitstempel
        // auf fremden Volumes) dürfen scheitern, ohne das ganze Entpacken
        // abzubrechen – der Dateiinhalt ist, was zählt.
        guard let extractStream = ArchiveStream.extractStream(
            extractingTo: FilePath(destinationDirectory.path),
            flags: [.ignoreOperationNotPermitted]
        ) else {
            throw BackupArchiveError.unreadable
        }
        defer { try? extractStream.close() }

        do {
            _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
        } catch {
            // Eine fremde Datei mit passender Endung landet genau hier.
            throw BackupArchiveError.unreadable
        }
    }
}
