import Foundation

/// Fehler beim Abruf der Tankerkönig-Umkreissuche.
enum TankerkoenigError: Error {
    /// Die API hat den Aufruf mit `ok: false` abgelehnt (z. B. ungültiger Key).
    case rejected(String)
}

/// Zugriff auf die Tankerkönig-„list.php"-Umkreissuche (Creative Commons API).
/// Siehe https://creativecommons.tankerkoenig.de/.
enum TankerkoenigService {
    private static let base = URL(string: "https://creativecommons.tankerkoenig.de/json/list.php")!

    /// Tankstellen im angegebenen Radius um eine Position, alle Kraftstoffsorten.
    /// Wirft bei Netzwerk-/Dekodierfehlern den jeweiligen Fehler von
    /// `URLSession`/`JSONDecoder` durch; bei einer von der API abgelehnten
    /// Anfrage `TankerkoenigError.rejected(message)`.
    static func stations(lat: Double, lng: Double, radiusKm: Double, apiKey: String) async throws -> [GasStation] {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "rad", value: String(radiusKm)),
            URLQueryItem(name: "sort", value: "dist"),
            URLQueryItem(name: "type", value: "all"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(TankerkoenigListResponse.self, from: data)

        guard decoded.ok else {
            throw TankerkoenigError.rejected(decoded.message ?? "Unbekannter Fehler")
        }
        return decoded.stations ?? []
    }
}
