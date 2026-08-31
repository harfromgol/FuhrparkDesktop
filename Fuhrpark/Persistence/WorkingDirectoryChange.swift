import CoreData
import Foundation

/// Bündelt, was beim Setzen/Ändern des Arbeitsverzeichnisses passieren muss:
/// speichern, vorhandene Dokumente migrieren, vor fremden Belegordnern
/// warnen. Gemeinsam genutzt vom Zahnrad-Popover in `DocumentsView` und der
/// Sektion „Dokumente“ im Einstellungsfenster (`SettingsView`), damit beide
/// Stellen exakt dasselbe Verhalten zeigen und nicht auseinanderlaufen
/// können.
///
/// Bewusst nur die reine Logik – keine `.sheet`/`.alert`-Präsentation: Jede
/// aufrufende View bringt dafür ihren eigenen Zustand mit (siehe
/// Doc-Kommentar an `DocumentsView.activeSheet` zum SDK-Quirk, dass von
/// mehreren gleichzeitig deklarierten Präsentations-Modifiern nur der
/// zuletzt deklarierte zuverlässig funktioniert – ein gemeinsames `.sheet`
/// in dieser Hilfsfunktion würde das für Aufrufer mit eigenen Sheets
/// riskieren).
enum WorkingDirectoryChange {
    struct Outcome {
        let migrationFailures: [DocumentMigration.Failure]
        /// Hinweistext, falls im neu gewählten Verzeichnis bereits fremde
        /// Belegordner liegen – `nil`, wenn keine gefunden wurden. Wird nur
        /// geprüft, wenn die Migration ohne Fehlschläge durchlief (siehe
        /// `DocumentsView.warnAboutForeignFolders`, dessen Verhalten hier
        /// identisch nachgebildet ist).
        let foreignFolderWarning: String?
    }

    static func apply(url: URL, in context: NSManagedObjectContext) throws -> Outcome {
        try WorkingDirectoryStore.set(url: url)
        let failures = DocumentMigration.migrateLegacyDocuments(using: PersistenceController.shared)
        guard failures.isEmpty else {
            return Outcome(migrationFailures: failures, foreignFolderWarning: nil)
        }

        let fremde = DocumentCleanup.unknownFolderIDs(in: context).count
        guard fremde > 0 else {
            return Outcome(migrationFailures: [], foreignFolderWarning: nil)
        }
        let warning = fremde == 1
            ? "In diesem Ordner liegt ein Belegordner, der nicht zu diesem Datenbestand gehört. Er wird beim nächsten Löschvorgang entfernt. Wähle ein anderes Verzeichnis, falls er zu einer anderen Installation gehört."
            : "In diesem Ordner liegen \(fremde) Belegordner, die nicht zu diesem Datenbestand gehören. Sie werden beim nächsten Löschvorgang entfernt. Wähle ein anderes Verzeichnis, falls sie zu einer anderen Installation gehören."
        return Outcome(migrationFailures: [], foreignFolderWarning: warning)
    }
}
