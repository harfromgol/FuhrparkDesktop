import Foundation

/// Speichert die an die Menüleiste angepinnten Tankstellen/Sorten in den
/// UserDefaults – JSON-Blob-Muster wie `WindowFrameStore`. Bewusst NICHT in
/// `DataTransfer` (JSON-Export/-Import) eingebunden: angepinnte Stations-IDs
/// sind auf einem anderen Rechner oder nach Zeitablauf wertlos, dieselbe
/// Begründung wie beim bereits ausgeschlossenen `TankerkoenigKeyStore`.
enum PinnedFuelSelectionStore {
    private static let defaultsKey = "pinnedFuelSelections"

    static func get() -> [PinnedFuelSelection] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let selections = try? JSONDecoder().decode([PinnedFuelSelection].self, from: data)
        else { return [] }
        return selections
    }

    static func set(_ selections: [PinnedFuelSelection]) {
        guard let data = try? JSONEncoder().encode(selections) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
