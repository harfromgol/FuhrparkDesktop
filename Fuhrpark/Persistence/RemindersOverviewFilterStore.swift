import Foundation

/// Speichert die zuletzt gewählten Filtereinstellungen der
/// fahrzeugübergreifenden Erinnerungsübersicht (`RemindersOverviewWindow`) in
/// den UserDefaults, damit sie einen Neustart überstehen und beim erneuten
/// Öffnen des Fensters („Ansichten → Erinnerungen“) wiederhergestellt werden
/// – das Fenster wird bei jedem Öffnen neu erzeugt, sein `@State` allein
/// würde also nicht reichen. Aufgebaut wie `NotesOverviewFilterStore`.
enum RemindersOverviewFilterStore {
    private static let statusFilterDefaultsKey = "remindersOverviewStatusFilter"
    private static let selectedVehicleIDDefaultsKey = "remindersOverviewSelectedVehicleID"

    /// Ohne gespeicherten Wert – etwa beim allerersten Öffnen – zeigt das
    /// Fenster die offenen Erinnerungen.
    static func getStatusFilter() -> ReminderStatusFilter {
        UserDefaults.standard.string(forKey: statusFilterDefaultsKey)
            .flatMap(ReminderStatusFilter.init(rawValue:)) ?? .open
    }

    static func setStatusFilter(_ statusFilter: ReminderStatusFilter) {
        UserDefaults.standard.set(statusFilter.rawValue, forKey: statusFilterDefaultsKey)
    }

    static func getSelectedVehicleID() -> UUID? {
        (UserDefaults.standard.string(forKey: selectedVehicleIDDefaultsKey)).flatMap(UUID.init(uuidString:))
    }

    static func setSelectedVehicleID(_ vehicleID: UUID?) {
        UserDefaults.standard.set(vehicleID?.uuidString, forKey: selectedVehicleIDDefaultsKey)
    }
}
