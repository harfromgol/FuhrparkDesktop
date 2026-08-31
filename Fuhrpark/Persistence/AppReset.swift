import AppKit
import Foundation

/// Setzt die App vollständig zurück: löscht Core Data, die zugehörigen
/// Belege/Fahrzeugbilder im Arbeitsverzeichnis und **alle** UserDefaults
/// dieses Containers – Fenstergrößen, Filter, Sortierungen, API-Schlüssel,
/// die Arbeitsverzeichnis-Zuordnung, angepinnte Spritpreise, Update-
/// Einstellungen usw. Ausgelöst über „Tools → App zurücksetzen“.
///
/// Statt die App danach neu zu starten, wird sie beendet: Aus der Sandbox
/// heraus (`com.apple.security.app-sandbox`, siehe
/// `FuhrparkDesktop.entitlements`) lässt sich kein eigener Prozess für einen
/// Neustart aufrufen, und nur ein echter Neustart durch den Nutzer räumt
/// zuverlässig auch jeden bereits geladenen In-Memory-Zustand (offene
/// Fenstergrößen, gecachte Einstellungen in den ViewModels) mit auf – genau
/// der Zustand einer frisch installierten App.
enum AppReset {
    @MainActor
    static func performFactoryReset() {
        // Erst Core Data + Beleg-/Fotosweep, solange das Arbeitsverzeichnis
        // noch bekannt ist (siehe DocumentCleanup.sweepWorkingDirectory) –
        // danach erst die UserDefaults löschen, sonst fände der Sweep gar
        // kein Arbeitsverzeichnis mehr vor und ließe die Dateien liegen.
        PersistenceController.shared.deleteAllData()

        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        NSApp.terminate(nil)
    }
}
