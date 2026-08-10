import Foundation

/// Speichert den Stand der letzten Preisabfrage der angepinnten Spritpreise
/// (Zeitpunkt + Preise) in den UserDefaults – JSON-Blob-Muster wie
/// `WindowFrameStore`. Das ist, was nach einem Neustart sofort die letzten
/// bekannten Preise zeigt und das Update-Intervall über den Neustart hinweg
/// einhält. Bewusst NICHT in `DataTransfer` eingebunden, siehe
/// `PinnedFuelSelectionStore`.
enum PinnedFuelPricesCacheStore {
    private static let defaultsKey = "pinnedFuelPricesCache"

    static func get() -> PinnedFuelPricesCache {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let cache = try? JSONDecoder().decode(PinnedFuelPricesCache.self, from: data)
        else { return .empty }
        return cache
    }

    static func set(_ cache: PinnedFuelPricesCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
