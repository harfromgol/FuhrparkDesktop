import Foundation
import Observation

/// Verbindet Menübefehle (Scene `commands`) mit der Haupt-GUI.
///
/// Menü-Aktionen liegen außerhalb der View-Hierarchie und können daher keine
/// SwiftUI-Dialoge direkt präsentieren. Der Menüpunkt setzt stattdessen ein
/// Flag auf diesem gemeinsamen Objekt; `ContentView` beobachtet es und zeigt
/// die zugehörige Sicherheitsabfrage an.
@MainActor
@Observable
final class AppCommands {
    /// Löst im `ContentView` die Sicherheitsabfrage zum Löschen aller Daten aus.
    var showDeleteAllDataConfirmation = false

    /// Öffnet den Datei-Dialog zum Exportieren aller Daten als JSON.
    var showExportDialog = false

    /// Öffnet den Datei-Dialog zum Importieren von Daten aus einer JSON-Datei.
    var showImportDialog = false

    /// Fehlermeldung eines fehlgeschlagenen Export-/Import-Vorgangs (für Alert).
    var transferError: String?

    /// Ob das Hauptfenster gerade geöffnet ist. Steuert die Aktivierung der
    /// Menüpunkte „Neues Fenster“ / „Fenster schließen“. Wird von `ContentView`
    /// über `onAppear`/`onDisappear` gepflegt.
    var isMainWindowOpen = false

    /// Ändert sich einmal täglich um Mitternacht (siehe `scheduleDailyDueCheck`).
    /// `Erinnerung.isDue`/`isOverdue` sind reine Momentaufnahmen ohne eigene
    /// Änderungsbenachrichtigung; Views, die davon abhängen (Sidebar-Badge,
    /// Fälligkeits-Farbe in der Erinnerungsliste), lesen diesen Wert mit, damit
    /// SwiftUI sie auch ohne Klick oder Datenänderung neu zeichnet.
    var dailyDueCheckTick = Date()

    /// Läuft für die Lebensdauer des Hauptfensters und aktualisiert
    /// `dailyDueCheckTick` jede Mitternacht neu.
    func scheduleDailyDueCheck() async {
        while !Task.isCancelled {
            let next = Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(86_400)
            try? await Task.sleep(for: .seconds(next.timeIntervalSinceNow))
            dailyDueCheckTick = Date()
        }
    }
}
