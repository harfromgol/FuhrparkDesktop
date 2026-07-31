import Foundation
import AppKit

/// Fehler beim Zugriff auf eine Dokument-Datei im Arbeitsverzeichnis.
enum DokumentAccessError: LocalizedError {
    case workingDirectoryNotConfigured
    case fileNotFound(String)
    case openFailed(String)

    var errorDescription: String? {
        switch self {
        case .workingDirectoryNotConfigured:
            return "Es ist noch kein Arbeitsverzeichnis für Dokumente festgelegt."
        case .fileNotFound(let filename):
            return "„\(filename)“ wurde im Arbeitsverzeichnis nicht gefunden."
        case .openFailed(let filename):
            return "„\(filename)“ konnte nicht geöffnet werden."
        }
    }
}

extension Dokument {
    /// Dateiname ohne Pfad, z. B. „Rechnung.pdf" (funktioniert unverändert
    /// mit dem relativen Pfadformat "<uuid>/Rechnung.pdf").
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

    /// Führt `body` mit der aufgelösten Datei-URL aus, während der
    /// Security-Scope auf das Arbeitsverzeichnis aktiv ist. Wichtig: der
    /// eigentliche Zugriff (z. B. `NSWorkspace.shared.open(_:)`) muss
    /// innerhalb dieses Aufrufs passieren – der Scope endet, sobald
    /// `WorkingDirectoryStore.withAccess` zurückkehrt, eine außerhalb davon
    /// weitergereichte URL wäre für andere Prozesse (z. B. die per
    /// `NSWorkspace` gestartete Standard-App) nicht mehr zugreifbar.
    private func withResolvedURL<T>(_ body: (URL) throws -> T) throws -> T {
        guard let path else { throw DokumentAccessError.fileNotFound(filename) }
        do {
            return try WorkingDirectoryStore.withAccess { workingDirURL in
                let url = workingDirURL.appendingPathComponent(path)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw DokumentAccessError.fileNotFound(filename)
                }
                return try body(url)
            }
        } catch let error as WorkingDirectoryStore.WorkingDirectoryError {
            _ = error
            throw DokumentAccessError.workingDirectoryNotConfigured
        } catch let error as DokumentAccessError {
            throw error
        }
    }

    /// Öffnet die Datei mit der zuständigen Standard-App.
    @discardableResult
    func open() throws -> Bool {
        try withResolvedURL { url in
            guard NSWorkspace.shared.open(url) else {
                throw DokumentAccessError.openFailed(filename)
            }
            return true
        }
    }

    /// Zeigt die Datei im Finder an, mit der Datei als Auswahl.
    @discardableResult
    func reveal() throws -> Bool {
        try withResolvedURL { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return true
        }
    }
}
