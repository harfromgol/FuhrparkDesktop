import Foundation

/// Merkt sich, ob der Einrichtungsassistent (`SetupWizardModifier`) bereits
/// abgeschlossen oder abgebrochen wurde – einfacher Skalar wie bei
/// `FuelPriceRefreshIntervalStore`.
enum SetupWizardStore {
    private static let completedKey = "hasCompletedSetupWizard"

    /// Ob der Assistent jetzt gezeigt werden soll. Prüft nebenbei, ob es sich
    /// um eine Bestandsinstallation handelt, die die frühere einmalige
    /// Update-Rückfrage schon beantwortet oder bereits ein Arbeitsverzeichnis
    /// eingerichtet hat – solche Installationen gelten rückwirkend als
    /// abgeschlossen, damit der Assistent nach einem Update auf diese Version
    /// nicht plötzlich bei Bestandsnutzern erscheint. Bewusst eine Funktion,
    /// kein `var`: Anders als die übrigen Stores in diesem Ordner schreibt
    /// dieser Aufruf im Bestandsfall gleich mit (`markCompleted()`).
    static func shouldShowWizard() -> Bool {
        guard !UserDefaults.standard.bool(forKey: completedKey) else { return false }
        guard UpdateCheckStore.automaticCheckPreference() == nil, !WorkingDirectoryStore.isConfigured else {
            markCompleted()
            return false
        }
        return true
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }
}
