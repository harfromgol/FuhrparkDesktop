import Foundation

/// Speichert die zuletzt gewählte Seitengröße der Notizenliste
/// (`NoteListWindow`) in den UserDefaults, damit die Einstellung einen
/// Neustart der App übersteht – analog zu `FuelEntryPageSizeStore`.
enum NotePageSizeStore {
    private static let defaultsKey = "noteListPageSize"
    private static let defaultValue = 10
    private static let allowedRange = 5...15

    static func get() -> Int {
        let stored = UserDefaults.standard.integer(forKey: defaultsKey)
        guard stored != 0 else { return defaultValue }
        return stored.clamped(to: allowedRange)
    }

    static func set(_ pageSize: Int) {
        UserDefaults.standard.set(pageSize.clamped(to: allowedRange), forKey: defaultsKey)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
