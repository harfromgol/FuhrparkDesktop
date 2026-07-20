import Foundation
import AppKit

extension Dokument {
    /// Dateiname ohne Pfad, z. B. „Rechnung.pdf".
    var filename: String {
        (path as NSString?)?.lastPathComponent ?? ""
    }

    /// Fahrzeug, zu dem die verknüpfte Ausgabe gehört.
    var vehicle: Vehicle? {
        expense?.vehicle
    }

    /// Kategorien der verknüpften Ausgabe, nach Name sortiert (das Dokument
    /// übernimmt die Kategorie(n) der Ausgabe, statt sie doppelt zu pflegen).
    var categoryNames: [String] {
        expense?.categoryNames ?? []
    }

    var categoriesDisplay: String {
        expense?.categoriesDisplay ?? ""
    }

    /// Löst das gespeicherte Security-Scoped Bookmark auf. Nötig, da die App
    /// sandboxed läuft: ein reiner Pfad-String verliert nach einem Neustart
    /// den Dateizugriff, das Bookmark stellt ihn wieder her.
    private func resolveURL() -> URL? {
        guard let bookmarkData else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    /// Öffnet die Datei mit der zuständigen Standard-App.
    @discardableResult
    func open() -> Bool {
        guard let url = resolveURL(), url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        return NSWorkspace.shared.open(url)
    }

    /// Zeigt die Datei im Finder an, mit der Datei als Auswahl.
    @discardableResult
    func reveal() -> Bool {
        guard let url = resolveURL(), url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }
}
