import Foundation

/// Speichert die Einstellungen der Update-Prüfung in den UserDefaults –
/// einfache Skalare wie bei `FuelPriceRefreshIntervalStore`. Bewusst NICHT in
/// `DataTransfer` eingebunden: Das sind Einstellungen dieser Installation,
/// keine Fuhrparkdaten, und nach einem Import auf einem anderen Rechner wären
/// sie dort schlicht falsch.
enum UpdateCheckStore {
    private static let automaticKey = "updateAutomaticCheckEnabled"
    private static let lastCheckKey = "updateLastCheckDate"
    private static let skippedVersionKey = "updateSkippedVersion"

    /// Ob beim Start automatisch geprüft werden soll.
    ///
    /// **Dreiwertig**: `nil` heißt „noch nie gefragt" – das wertet
    /// `SetupWizardStore.shouldShowWizard()` aus, um zu entscheiden, ob der
    /// Einrichtungsassistent automatisch erscheinen soll. Deshalb
    /// `object(forKey:)` statt `bool(forKey:)` – letzteres liefert für „nie
    /// gesetzt" dasselbe `false` wie für ein bewusstes Nein, und Bestands-
    /// installationen ließen sich dann nicht mehr von echten Erstinstalla-
    /// tionen unterscheiden.
    static func automaticCheckPreference() -> Bool? {
        UserDefaults.standard.object(forKey: automaticKey) as? Bool
    }

    static func setAutomaticCheckPreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: automaticKey)
    }

    /// Zeitpunkt der letzten *erfolgreichen* Abfrage – begrenzt die
    /// automatische Prüfung auf einmal täglich.
    static func lastCheckDate() -> Date? {
        UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }

    static func setLastCheckDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastCheckKey)
    }

    /// Version, für die der Nutzer „Diese Version überspringen" gewählt hat.
    static func skippedVersion() -> String? {
        UserDefaults.standard.string(forKey: skippedVersionKey)
    }

    static func setSkippedVersion(_ version: String?) {
        guard let version else {
            UserDefaults.standard.removeObject(forKey: skippedVersionKey)
            return
        }
        UserDefaults.standard.set(version, forKey: skippedVersionKey)
    }
}
