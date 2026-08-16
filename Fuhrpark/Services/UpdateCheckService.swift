import Foundation

/// Eine auf der Produktseite veröffentlichte Version, so wie sie
/// `updates/version.json` beschreibt.
struct AppRelease: Decodable, Sendable, Identifiable {
    let version: String
    /// Nur zur Anzeige im Hinweis, kein `Date`: Das Manifest wird von Hand
    /// gepflegt, ein Tippfehler im Datum soll nicht die ganze Prüfung
    /// scheitern lassen.
    let publishedAt: String
    let minimumSystemVersion: String
    let downloadPageURL: URL
    /// Stichpunkte für den Hinweis – Kurzfassung des Changelogs.
    let notes: [String]

    var id: String { version }
}

enum UpdateCheckError: LocalizedError {
    case unreachable
    case malformed

    var errorDescription: String? {
        switch self {
        case .unreachable:
            return "Die Versionsinformation ist gerade nicht erreichbar."
        case .malformed:
            return "Die Versionsinformation war nicht lesbar."
        }
    }
}

/// Fragt die aktuell veröffentlichte Version von der Produktseite ab.
///
/// Aufbau wie `TankerkoenigService`: ein `enum` mit statischen Methoden über
/// `URLSession.shared` und `JSONDecoder`, ohne eigenen Netzwerk-Layer.
enum UpdateCheckService {
    /// Statische Datei auf der Produktseite. Bewusst **ohne** Query-Parameter:
    /// Die eigene Version wird nicht mitgesendet, damit aus den Abrufen kein
    /// Nutzungsprofil entstehen kann (siehe „Datenschutz" im README).
    private static let manifestURL = URL(string: "https://fuhrpark-macos.gerd-klaus.de/updates/version.json")!

    /// Die aktuell veröffentlichte Version. Wirft `UpdateCheckError` bzw. bei
    /// Netzwerkproblemen den Fehler von `URLSession` durch.
    static func latestRelease() async throws -> AppRelease {
        var request = URLRequest(url: manifestURL)
        // Ohne das reicht `URLCache` die Antwort des Apache anhand von
        // `Last-Modified` tagelang weiter – die Prüfung liefe dann gegen einen
        // veralteten Stand und meldete nach einem Release nichts Neues.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        // Ein fehlendes Manifest beantwortet Apache mit einer HTML-Fehlerseite.
        // Ohne diese Prüfung scheiterte erst der Decoder – mit einer Meldung,
        // die den eigentlichen Grund (404) nicht erkennen lässt.
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateCheckError.unreachable
        }

        do {
            return try JSONDecoder().decode(AppRelease.self, from: data)
        } catch {
            throw UpdateCheckError.malformed
        }
    }

    /// Version dieser Installation (`CFBundleShortVersionString`, dieselbe
    /// Quelle wie in `MCPProtocol`).
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Ob `remote` neuer ist als `local`. `.numeric` vergleicht Zahlenfolgen
    /// als Zahlen – ein reiner String-Vergleich hielte „1.10" für älter als
    /// „1.7", weil er bei „1" gegen „7" entscheidet.
    static func isNewer(_ remote: String, than local: String) -> Bool {
        remote.compare(local, options: .numeric) == .orderedDescending
    }

    /// Ob das laufende System die von `release` geforderte Mindestversion
    /// erfüllt. Verhindert, dass jemandem ein Update angeboten wird, das auf
    /// seinem Mac gar nicht startet.
    static func systemMeetsRequirement(of release: AppRelease) -> Bool {
        let parts = release.minimumSystemVersion.split(separator: ".").map { Int($0) ?? 0 }
        let required = OperatingSystemVersion(
            majorVersion: parts.count > 0 ? parts[0] : 0,
            minorVersion: parts.count > 1 ? parts[1] : 0,
            patchVersion: parts.count > 2 ? parts[2] : 0
        )
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(required)
    }
}
