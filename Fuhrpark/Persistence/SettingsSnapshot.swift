import Foundation

/// Sichert und restauriert **alle** Einstellungen der App als Ganzes.
///
/// Bewusst über den kompletten UserDefaults-Domain statt Store für Store:
/// Es gibt inzwischen 17 Schlüssel in ebenso vielen `*Store`-Typen, und jede
/// künftig ergänzte Einstellung wäre in einer handgepflegten Liste früher
/// oder später vergessen worden. Über den Domain ist sie automatisch dabei.
///
/// Der Domain hängt an der Bundle-ID – Testbau und produktive App sichern
/// also getrennte Bestände (siehe `AppVariant`).
enum SettingsSnapshot {
    /// Schlüssel, die an diesen Mac gebunden sind und deshalb nie in eine
    /// Sicherung gehören: Das Security-Scoped Bookmark auf das
    /// Arbeitsverzeichnis ist auf einem anderen Rechner wertlos, und der
    /// Pfad daneben wäre dort schlicht falsch (siehe
    /// `WorkingDirectoryStore`). Wo die Belege nach dem Einspielen liegen,
    /// entscheidet stattdessen die Ordnerabfrage im Restore.
    private static let machineBoundKeys = [
        "documentsWorkingDirectoryPath",
        "documentsWorkingDirectoryBookmark"
    ]

    private static var domainName: String {
        Bundle.main.bundleIdentifier ?? "de.gerdklaus.FuhrparkDesktop"
    }

    /// Alle Einstellungen als binäres Plist.
    ///
    /// Enthält absichtlich auch den Tankerkönig-API-Schlüssel: Anders als der
    /// JSON-Export, der zum Weitergeben gedacht ist, ist eine Sicherung die
    /// private Kopie derselben Installation – ohne den Schlüssel müsste man
    /// ihn nach jedem Einspielen von Hand nachtragen (siehe
    /// `TankerkoenigKeyStore`).
    static func capture() throws -> Data {
        var domain = UserDefaults.standard.persistentDomain(forName: domainName) ?? [:]
        for key in machineBoundKeys {
            domain.removeValue(forKey: key)
        }
        return try PropertyListSerialization.data(
            fromPropertyList: domain,
            format: .binary,
            options: 0
        )
    }

    /// Spielt die Einstellungen zurück.
    ///
    /// `setPersistentDomain` **ersetzt** den Domain vollständig. Das
    /// Arbeitsverzeichnis, das nach `machineBoundKeys` gar nicht erst
    /// gesichert wurde, verschwände dabei mit – auch dann, wenn die Sicherung
    /// überhaupt keine Belege enthält und der Ordner deshalb gar nicht neu
    /// abgefragt wird. Es wird deshalb vorher gerettet und hinterher wieder
    /// eingesetzt; enthält die Sicherung Belege, überschreibt der Restore es
    /// danach ohnehin mit dem neu gewählten Ordner.
    static func restore(from data: Data) throws {
        guard let restored = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw BackupArchiveError.incomplete(missing: "settings.plist")
        }

        let defaults = UserDefaults.standard
        let preserved = machineBoundKeys.reduce(into: [String: Any]()) { result, key in
            if let value = defaults.object(forKey: key) { result[key] = value }
        }

        defaults.setPersistentDomain(restored, forName: domainName)

        for (key, value) in preserved {
            defaults.set(value, forKey: key)
        }
    }
}
