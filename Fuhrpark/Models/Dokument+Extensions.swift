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

    /// Zugeordnete Ausgaben, neueste zuerst. Ein Beleg kann mehrere Ausgaben
    /// belegen (etwa eine Rechnung, die in zwei Buchungen aufgeteilt wurde).
    ///
    /// Die Beziehung heißt im Datenmodell aus einem handfesten Grund weiterhin
    /// `expense` im Singular: Core Data überträgt beim Umstellen von einer auf
    /// mehrere Ausgaben die vorhandenen Verknüpfungen **nur dann**, wenn dabei
    /// nicht gleichzeitig umbenannt wird — mit Umbenennung läuft die Migration
    /// zwar durch, lässt die Zuordnungen aber stillschweigend fallen (auf einer
    /// Kopie des echten Datenbestands nachgemessen). Ein zweistufiger Weg hilft
    /// nicht, weil Core Data stets direkt vom gespeicherten Modell zur
    /// aktuellen Fassung überträgt und damit wieder beide Änderungen zugleich
    /// sähe. Deshalb: schiefer Name im Modell, sprechender Name hier.
    var sortedExpenses: [Expense] {
        let set = (expense as? Set<Expense>) ?? []
        return set.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Setzt die Zuordnung auf genau diese Ausgaben.
    func setExpenses(_ expenses: Set<Expense>) {
        expense = NSSet(set: expenses)
    }

    /// Ergänzt eine weitere Ausgabe.
    func link(to expenseToAdd: Expense) {
        addToExpense(expenseToAdd)
    }

    /// Fahrzeug des Belegs.
    ///
    /// Eindeutig, weil alle zugeordneten Ausgaben zum selben Fahrzeug gehören
    /// müssen – die Zuordnungsansicht setzt das durch. Die erste Ausgabe
    /// genügt daher als Auskunft.
    var vehicle: Vehicle? {
        sortedExpenses.first?.vehicle
    }

    /// Kategorien aller zugeordneten Ausgaben, ohne Duplikate und alphabetisch
    /// (das Dokument übernimmt die Kategorien der Ausgaben, statt sie doppelt
    /// zu pflegen).
    var categoryNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for expense in sortedExpenses {
            for name in expense.categoryNames where seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var categoriesDisplay: String {
        categoryNames.joined(separator: ", ")
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
