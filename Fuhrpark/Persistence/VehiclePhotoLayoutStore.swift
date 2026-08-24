import Foundation

/// Wo das Fahrzeugbild in der Detailansicht sitzt: `side` wie bisher klein
/// vor dem Kennzeichen, `top` groß und zentriert über der ganzen Karte.
enum VehiclePhotoLayout: String {
    case side
    case top
}

/// Anordnung und Größe des Fahrzeugbilds in der Detailansicht – global für
/// die ganze App (reine Anzeigepräferenz, kein fahrzeugspezifischer Wert,
/// analog zum flachen `VehicleCostFilterStore`-Muster), umschaltbar per
/// Rechtsklick-Kontextmenü auf dem Bild.
enum VehiclePhotoLayoutStore {
    private static let layoutKey = "vehiclePhotoLayout"
    private static let topSizeKey = "vehiclePhotoTopSize"

    /// Größenstufen 1…5 für `top`, jeweils ein Vielfaches der Seitengröße
    /// (60pt) – Stufe 3 entspricht damit den zuerst ausprobierten 180pt.
    static let topSizeRange = 1...5
    static let defaultTopSize = 3
    static func topSizePoints(_ level: Int) -> CGFloat { CGFloat(level) * 60 }

    static func layout() -> VehiclePhotoLayout {
        UserDefaults.standard.string(forKey: layoutKey).flatMap(VehiclePhotoLayout.init(rawValue:)) ?? .side
    }

    static func setLayout(_ layout: VehiclePhotoLayout) {
        UserDefaults.standard.set(layout.rawValue, forKey: layoutKey)
    }

    static func topSize() -> Int {
        guard let stored = UserDefaults.standard.object(forKey: topSizeKey) as? Int, topSizeRange.contains(stored) else {
            return defaultTopSize
        }
        return stored
    }

    static func setTopSize(_ size: Int) {
        UserDefaults.standard.set(size, forKey: topSizeKey)
    }
}
