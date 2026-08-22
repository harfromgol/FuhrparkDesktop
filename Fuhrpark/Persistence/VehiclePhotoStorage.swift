import AppKit
import Foundation

/// Speichert Fahrzeugbilder als eine Datei pro Fahrzeug in einem eigenen
/// Unterordner des Arbeitsverzeichnisses – bewusst **nicht** nach demselben
/// Muster wie `DocumentStorage` (Unterordner benannt nach der jeweiligen
/// UUID direkt im Arbeitsverzeichnis): `DocumentCleanup` betrachtet jeden
/// UUID-benannten Top-Level-Ordner als Belegordner und würde ein so
/// abgelegtes Fahrzeugbild beim nächsten Aufräumen als „verwaist“ löschen.
/// Der feste, nicht-UUID-benannte Ordnername `Fahrzeugbilder` hält
/// Fahrzeugbilder strukturell außerhalb dieser Prüfung.
enum VehiclePhotoStorage {
    static let folderName = "Fahrzeugbilder"

    enum StorageError: LocalizedError {
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .saveFailed:
                return "Das Fahrzeugbild konnte nicht gespeichert werden."
            }
        }
    }

    /// Schreibt `data` (bereits zugeschnittenes JPEG) als `<vehicleID>.jpg`
    /// im `Fahrzeugbilder`-Unterordner. Ein evtl. vorhandenes älteres Bild
    /// desselben Fahrzeugs wird überschrieben – es gibt je Fahrzeug immer
    /// nur ein aktuelles Foto, anders als bei Belegen keinen Ordner pro Foto.
    @discardableResult
    static func save(_ data: Data, vehicleID: UUID) throws -> String {
        try WorkingDirectoryStore.withAccess { workingDirURL in
            let folder = workingDirURL.appendingPathComponent(folderName, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent("\(vehicleID.uuidString).jpg")
            do {
                try data.write(to: destination, options: .atomic)
            } catch {
                throw StorageError.saveFailed
            }
            return "\(folderName)/\(vehicleID.uuidString).jpg"
        }
    }

    /// Lädt das Bild zu `path` und liefert es als `NSImage`, oder `nil` bei
    /// jedem Fehler (Datei fehlt, kein Arbeitsverzeichnis, ungültige Bilddaten).
    ///
    /// Liest die Datei bewusst **innerhalb** von `withAccess`: Der
    /// Security-Scope gilt nur für die Dauer des Closures – eine URL, die
    /// erst danach gelesen wird (etwa über eine separate „resolvedURL“-
    /// Funktion), verliert den Zugriff wieder, bevor `NSImage` sie öffnen
    /// kann, und liefert dann lautlos `nil`.
    static func loadImage(forRelativePath path: String) -> NSImage? {
        (try? WorkingDirectoryStore.withAccess { workingDirURL -> NSImage? in
            let url = workingDirURL.appendingPathComponent(path)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return NSImage(data: data)
        }) ?? nil
    }

    /// Löscht die Bilddatei eines Fahrzeugs. Best-effort.
    static func delete(vehicleID: UUID) {
        try? WorkingDirectoryStore.withAccess { workingDirURL in
            let file = workingDirURL
                .appendingPathComponent(folderName, isDirectory: true)
                .appendingPathComponent("\(vehicleID.uuidString).jpg")
            try FileManager.default.removeItem(at: file)
        }
    }

    /// Fahrzeug-IDs aller vorhandenen Bilddateien im `Fahrzeugbilder`-Ordner,
    /// aus dem Dateinamen ohne Endung geparst. Fehlt der Ordner (noch nie
    /// ein Bild gespeichert), liefert dies die leere Menge statt eines Fehlers.
    static func photoFileVehicleIDs() throws -> Set<UUID> {
        try WorkingDirectoryStore.withAccess { workingDirURL in
            let folder = workingDirURL.appendingPathComponent(folderName, isDirectory: true)
            guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
            let inhalt = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return Set(inhalt.compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) })
        }
    }

    /// Entfernt genau die angegebenen Bilddateien (Begründung wie
    /// `DocumentStorage.removeFolders(withIDs:)`).
    static func removeFiles(withIDs ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        try? WorkingDirectoryStore.withAccess { workingDirURL in
            let folder = workingDirURL.appendingPathComponent(folderName, isDirectory: true)
            for id in ids {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent("\(id.uuidString).jpg"))
            }
        }
    }
}
