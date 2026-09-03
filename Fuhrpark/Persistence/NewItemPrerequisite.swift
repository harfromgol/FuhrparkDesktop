import Foundation

/// Prüft, ob „Neues Dokument“/„Neue Notiz“/„Neue Erinnerung“ überhaupt
/// geöffnet werden dürfen: alle drei brauchen ein Arbeitsverzeichnis (für
/// Belege/Dokumente) und mindestens ein angelegtes Fahrzeug (zum Zuordnen).
/// Geteilt von `DocumentsView`, `NotesView` und `RemindersView`, damit alle
/// drei „Neu …“-Buttons exakt dieselbe Meldung zeigen, was genau fehlt.
///
/// Läuft diese Prüfung vor dem Öffnen des jeweiligen Erstellungsfensters
/// durch, ist das Arbeitsverzeichnis dort garantiert konfiguriert – die
/// entsprechenden Prüfungen in den Fenstern selbst können deshalb entfallen
/// (siehe die entfernte `WorkingDirectoryStore.isConfigured`-Prüfung in
/// `NoteFormView.addDocumentTapped()`).
enum NewItemPrerequisite {
    /// `nil`, wenn beide Voraussetzungen erfüllt sind – sonst ein Text, der
    /// benennt, was fehlt (eines oder beides). `hasVehicles` kommt bewusst
    /// als `Bool` statt eines `FetchedResults<Vehicle>`/Core-Data-Typs herein,
    /// damit diese Datei ohne CoreData/SwiftUI-Importe auskommt – jeder
    /// Aufrufer hat sein eigenes `@FetchRequest<Vehicle>` ohnehin schon.
    static func missingMessage(hasVehicles: Bool) -> String? {
        let missingWorkingDirectory = !WorkingDirectoryStore.isConfigured
        let missingVehicle = !hasVehicles

        switch (missingWorkingDirectory, missingVehicle) {
        case (false, false):
            return nil
        case (true, false):
            return "Bevor du fortfahren kannst, lege in den Einstellungen unter „Dokumente“ ein Arbeitsverzeichnis fest."
        case (false, true):
            return "Bevor du fortfahren kannst, lege mindestens ein Fahrzeug an."
        case (true, true):
            return "Bevor du fortfahren kannst, lege in den Einstellungen unter „Dokumente“ ein Arbeitsverzeichnis fest und mindestens ein Fahrzeug an."
        }
    }
}
