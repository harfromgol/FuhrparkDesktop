import Foundation

/// Speichert den Tankerkönig-API-Schlüssel in den UserDefaults – analog zum
/// bestehenden `WindowFrameStore`-Muster. Anders als die Fensterpositionen
/// wird dieser Schlüssel bewusst NICHT in `DataTransfer` (JSON-Export/-Import)
/// eingebunden, damit er nie in eine geteilte Sicherungsdatei gelangt.
enum TankerkoenigKeyStore {
    private static let defaultsKey = "tankerkoenigAPIKey"

    static func get() -> String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }

    static func set(_ key: String) {
        UserDefaults.standard.set(key, forKey: defaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
