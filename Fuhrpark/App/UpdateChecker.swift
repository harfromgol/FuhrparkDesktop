import Foundation
import Observation

/// Prüft, ob auf der Produktseite eine neuere Version steht, und hält das
/// Ergebnis für `ContentView` bereit.
///
/// Bewusst nur ein *Hinweis*, keine Installation: Die App ist ad-hoc signiert
/// (kein Developer-ID-Zertifikat). Ein Selbst-Update änderte bei jedem
/// Durchlauf den cdhash, und da TCC die erteilten Rechte daran festmacht,
/// würde nach jedem Update die Standortfreigabe für die Spritpreis-
/// Umkreissuche neu abgefragt. Ein Auto-Updater wäre damit schlechter als
/// keiner.
@MainActor
@Observable
final class UpdateChecker {
    /// Gesetzt, sobald eine neuere Version vorliegt – `ContentView` zeigt
    /// daraufhin `UpdateAvailableSheet`.
    var availableRelease: AppRelease?

    /// Läuft gerade eine Abfrage? Deaktiviert den Menüpunkt.
    var isChecking = false

    /// Fehlermeldung einer **manuellen** Prüfung. Der automatische Lauf
    /// bleibt bei Problemen absichtlich still – wer die App startet, will
    /// nicht wegen eines fehlenden WLANs einen Dialog wegklicken.
    var manualCheckError: String?

    /// „Du hast bereits die neueste Version" nach manueller Prüfung.
    var showsUpToDateConfirmation = false

    /// Version dieser Installation, für die Gegenüberstellung im Hinweis.
    let currentVersion = UpdateCheckService.currentVersion

    /// Spiegelt die Einstellung aus `UpdateCheckStore` als beobachtbare
    /// Eigenschaft, damit die Checkbox in den Einstellungen (Abschnitt
    /// „Updates”, siehe `SettingsView.swift`) und der Schalter im Hinweis
    /// dieselbe Quelle haben und sofort umspringen. Schreibt jede Änderung
    /// durch. `false` als Ausgangswert gilt nur, bevor der
    /// Einrichtungsassistent (`SetupWizardView`) oder die Einstellungen sie
    /// zum ersten Mal setzen; `checkAutomatically` behandelt `nil` und
    /// `false` inzwischen gleich.
    var automaticChecksEnabled: Bool = UpdateCheckStore.automaticCheckPreference() ?? false {
        didSet { UpdateCheckStore.setAutomaticCheckPreference(automaticChecksEnabled) }
    }

    /// Stiller Lauf beim App-Start.
    ///
    /// Läuft bewusst auch im Testbau: Der Debug-Container bringt eigene
    /// UserDefaults mit, ein einmaliges „Nein" im Einrichtungsassistenten
    /// stellt ihn dort dauerhaft ruhig. Ein Riegel über
    /// `AppVariant.isTestContainer` wäre bequemer, machte die Funktion aber
    /// in genau dem Build unsichtbar, in dem sie geprüft wird.
    func checkAutomatically() async {
        guard UpdateCheckStore.automaticCheckPreference() == true else { return }

        if let last = UpdateCheckStore.lastCheckDate(), Calendar.current.isDateInToday(last) {
            return
        }

        guard let release = try? await UpdateCheckService.latestRelease() else { return }

        // Erst nach erfolgreichem Abruf stempeln: Wer die App morgens ohne
        // Netz startet, soll nach dem Verbinden beim nächsten Start noch eine
        // Chance auf die Prüfung haben.
        UpdateCheckStore.setLastCheckDate(Date())

        guard release.version != UpdateCheckStore.skippedVersion() else { return }
        guard isRelevant(release) else { return }
        availableRelease = release
    }

    /// Prüfung über den Menüpunkt „Nach Updates suchen …".
    func checkManually() async {
        isChecking = true
        defer { isChecking = false }

        do {
            let release = try await UpdateCheckService.latestRelease()
            UpdateCheckStore.setLastCheckDate(Date())

            // Ignoriert bewusst die übersprungene Version: Wer selbst
            // nachsieht, will das Ergebnis auch dann sehen.
            if isRelevant(release) {
                availableRelease = release
            } else {
                showsUpToDateConfirmation = true
            }
        } catch {
            manualCheckError = error.localizedDescription
        }
    }

    /// Merkt sich die angebotene Version als übersprungen und schließt den Hinweis.
    func skipOfferedRelease() {
        UpdateCheckStore.setSkippedVersion(availableRelease?.version)
        availableRelease = nil
    }

    /// Ob `release` für diese Installation überhaupt in Frage kommt: neuer als
    /// die laufende Version und lauffähig auf diesem System.
    private func isRelevant(_ release: AppRelease) -> Bool {
        UpdateCheckService.isNewer(release.version, than: currentVersion)
            && UpdateCheckService.systemMeetsRequirement(of: release)
    }
}
