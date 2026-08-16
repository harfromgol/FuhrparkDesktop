import Foundation

/// Speichert den Tankerkönig-API-Schlüssel in den UserDefaults – analog zum
/// bestehenden `WindowFrameStore`-Muster.
///
/// Der Schlüssel wird bewusst NICHT in `DataTransfer` (JSON-Export/-Import)
/// eingebunden: Diese Datei ist zum **Weitergeben** gedacht und lesbar, dort
/// hat ein Geheimnis nichts verloren.
///
/// Im vollständigen Backup (`BackupService`) ist er dagegen enthalten. Das ist
/// kein Widerspruch, sondern der Unterschied zwischen den beiden Wegen: Das
/// Backup ist die private Komplettkopie derselben Installation, und ohne den
/// Schlüssel müsste man ihn nach jedem Einspielen von Hand nachtragen.
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
