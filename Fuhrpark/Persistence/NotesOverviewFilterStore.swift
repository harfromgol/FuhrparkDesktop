import Foundation

/// Speichert die zuletzt gewählten Filtereinstellungen der
/// fahrzeugübergreifenden Notizenübersicht (`NotesOverviewWindow`) in den
/// UserDefaults, damit sie einen Neustart überstehen und beim erneuten Öffnen
/// des Fensters („Ansichten → Notizen“) wiederhergestellt werden – das
/// Fenster wird bei jedem Öffnen neu erzeugt, sein `@State` allein würde also
/// nicht reichen. Aufgebaut wie `FuelEntriesOverviewFilterStore`.
enum NotesOverviewFilterStore {
    private static let statusFilterDefaultsKey = "notesOverviewStatusFilter"
    private static let selectedVehicleIDDefaultsKey = "notesOverviewSelectedVehicleID"
    private static let isDateFilterActiveDefaultsKey = "notesOverviewIsDateFilterActive"
    private static let dateFromDefaultsKey = "notesOverviewDateFrom"
    private static let dateToDefaultsKey = "notesOverviewDateTo"

    static func getStatusFilter() -> FahrzeugStatusFilter {
        UserDefaults.standard.string(forKey: statusFilterDefaultsKey)
            .flatMap(FahrzeugStatusFilter.init(rawValue:)) ?? .alle
    }

    static func setStatusFilter(_ statusFilter: FahrzeugStatusFilter) {
        UserDefaults.standard.set(statusFilter.rawValue, forKey: statusFilterDefaultsKey)
    }

    static func getSelectedVehicleID() -> UUID? {
        (UserDefaults.standard.string(forKey: selectedVehicleIDDefaultsKey)).flatMap(UUID.init(uuidString:))
    }

    static func setSelectedVehicleID(_ vehicleID: UUID?) {
        UserDefaults.standard.set(vehicleID?.uuidString, forKey: selectedVehicleIDDefaultsKey)
    }

    static func getIsDateFilterActive() -> Bool {
        UserDefaults.standard.bool(forKey: isDateFilterActiveDefaultsKey)
    }

    static func setIsDateFilterActive(_ isActive: Bool) {
        UserDefaults.standard.set(isActive, forKey: isDateFilterActiveDefaultsKey)
    }

    /// Der zuletzt eingestellte Zeitraum – auch dann, wenn die Eingrenzung
    /// gerade ausgeschaltet ist, damit sie beim Wiedereinschalten dort
    /// weitermacht, wo man aufgehört hat.
    ///
    /// Beide Grenzen werden stets gemeinsam geschrieben und nur gemeinsam
    /// zurückgegeben: `NotesOverviewWindow` bildet daraus einen
    /// `ClosedRange`, der bei „Von“ nach „Bis“ abstürzen würde. Ein
    /// unvollständiges oder verdrehtes Paar (etwa aus einer von Hand
    /// bearbeiteten Sicherung) gilt deshalb als nicht vorhanden.
    static func getDateRange() -> (from: Date, to: Date)? {
        let defaults = UserDefaults.standard
        guard let from = defaults.object(forKey: dateFromDefaultsKey) as? Date,
              let to = defaults.object(forKey: dateToDefaultsKey) as? Date,
              from <= to else {
            return nil
        }
        return (from, to)
    }

    static func setDateRange(from: Date, to: Date) {
        let defaults = UserDefaults.standard
        defaults.set(from, forKey: dateFromDefaultsKey)
        defaults.set(to, forKey: dateToDefaultsKey)
    }
}
