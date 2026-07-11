import Foundation

/// Leichtgewichtige, serialisierbare Referenz auf ein Fahrzeug – dient als Wert
/// zum Öffnen der Listen-Fenster (`WindowGroup(for:)`).
struct VehicleRef: Codable, Hashable, Identifiable {
    let id: UUID
    let licensePlate: String
    let engineType: EngineType
}
