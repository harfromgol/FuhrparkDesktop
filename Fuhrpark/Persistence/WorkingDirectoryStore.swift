import Foundation

/// Speichert das vom Nutzer gewählte Arbeitsverzeichnis für Dokumente
/// (Pfad zur Anzeige + Security-Scoped Bookmark für den Zugriff) in den
/// UserDefaults. Analog zu `TankerkoenigKeyStore` bewusst NICHT in
/// `DataTransfer` (JSON-Export/-Import) eingebunden, da der Ordner an
/// diesen Mac gebunden ist.
enum WorkingDirectoryStore {
    private static let pathKey = "documentsWorkingDirectoryPath"
    private static let bookmarkKey = "documentsWorkingDirectoryBookmark"

    enum WorkingDirectoryError: LocalizedError {
        case notConfigured
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Es ist noch kein Arbeitsverzeichnis für Dokumente festgelegt."
            case .accessDenied:
                return "Auf das Arbeitsverzeichnis konnte nicht zugegriffen werden."
            }
        }
    }

    /// Nur zur Anzeige (z. B. im Konfigurations-Popover), keine Zugriffsgarantie.
    static var displayPath: String? {
        UserDefaults.standard.string(forKey: pathKey)
    }

    static var isConfigured: Bool { displayPath != nil }

    /// Speichert ein neu gewähltes Arbeitsverzeichnis (URL aus einem
    /// `.fileImporter(allowedContentTypes: [.folder])`-Callback).
    static func set(url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw WorkingDirectoryError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(url.path, forKey: pathKey)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }

    private static func resolveURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale, let refreshed = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
        }
        return url
    }

    /// Zentraler Zugriffspunkt: startet/stoppt den Security-Scope rund um
    /// `body`. Alle Stellen, die Dateien im Arbeitsverzeichnis lesen/
    /// schreiben, sollen ausschließlich hierüber gehen.
    static func withAccess<T>(_ body: (URL) throws -> T) throws -> T {
        guard let url = resolveURL() else { throw WorkingDirectoryError.notConfigured }
        guard url.startAccessingSecurityScopedResource() else { throw WorkingDirectoryError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }
        return try body(url)
    }
}
