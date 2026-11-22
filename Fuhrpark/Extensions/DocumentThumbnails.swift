import AppKit
import QuickLookThumbnailing

/// Erzeugt die Vorschaubilder für die Kacheln im Dokumente-Fenster
/// (`DocumentCard`).
///
/// Die Bilder kommen von QuickLook – demselben System, das auch der Finder
/// benutzt. Es liefert für PDF, Fotos, Text und Office-Dateien eine echte
/// Vorschau der ersten Seite und für alles andere das Symbol des Dateityps.
/// Welche der beiden Arten es war, steht in `Thumbnail.isPreview`, weil die
/// Kachel eine Vorschau füllend und ein Symbol verkleinert zeigt.
///
/// Fertige Bilder bleiben im Speicher (kein Platten-Cache): Eine Vorschau ist
/// schnell erzeugt, und so kann es keine veralteten Bilder zu ersetzten
/// Dateien geben – der Schlüssel enthält das Änderungsdatum der Datei.
@MainActor
enum DocumentThumbnails {
    /// Ein erzeugtes Vorschaubild.
    struct Thumbnail {
        let image: NSImage
        /// `true` bei einer echten Vorschau des Inhalts, `false` beim bloßen
        /// Symbol des Dateityps.
        let isPreview: Bool
    }

    /// Größe, in der QuickLook die Vorschau anfordert: Breite einer Kachel
    /// bei A4-Hochformat. Ein Hochformat-Dokument füllt so die Kachelbreite
    /// und wird oben beschnitten (siehe `DocumentCard`); ein breiteres Bild
    /// wird entsprechend flacher geliefert.
    static let requestSize = CGSize(width: 240, height: 340)

    /// Der Cache hält nur Werte; `NSCache` verlangt Objekte.
    private final class Entry {
        let thumbnail: Thumbnail
        init(_ thumbnail: Thumbnail) { self.thumbnail = thumbnail }
    }

    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 300
        return cache
    }()

    /// Liefert das Vorschaubild zu `document`.
    ///
    /// - Parameter scale: Bildschirmfaktor (`displayScale`), damit die
    ///   Vorschau auf Retina-Displays scharf ist.
    /// - Throws: `DokumentAccessError.workingDirectoryNotConfigured` bzw.
    ///   `.fileNotFound`, wenn die Datei gerade nicht erreichbar ist; sonst
    ///   den Fehler von QuickLook.
    static func thumbnail(for document: Dokument, scale: CGFloat) async throws -> Thumbnail {
        guard let path = document.path else {
            throw DokumentAccessError.fileNotFound(document.filename)
        }
        let filename = document.filename
        do {
            return try await WorkingDirectoryStore.withAccessAsync { workingDirectory in
                let url = workingDirectory.appendingPathComponent(path)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw DokumentAccessError.fileNotFound(filename)
                }

                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate?.timeIntervalSince1970 ?? 0
                let key = "\(path)|\(modified)|\(scale)" as NSString
                if let hit = cache.object(forKey: key) {
                    return hit.thumbnail
                }

                let request = QLThumbnailGenerator.Request(
                    fileAt: url,
                    size: requestSize,
                    scale: scale,
                    representationTypes: .all
                )
                let representation = try await QLThumbnailGenerator.shared
                    .generateBestRepresentation(for: request)
                let result = Thumbnail(
                    image: representation.nsImage,
                    isPreview: representation.type != .icon
                )
                cache.setObject(Entry(result), forKey: key)
                return result
            }
        } catch is WorkingDirectoryStore.WorkingDirectoryError {
            throw DokumentAccessError.workingDirectoryNotConfigured
        }
    }
}
