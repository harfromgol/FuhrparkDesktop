import CoreLocation
import Observation

/// Steuert den Ablauf der Spritpreise-Ansicht: API-Key → Standort → Abruf →
/// Karte. Lebt als Environment-Objekt für die Dauer der App-Sitzung (siehe
/// `FuhrparkDesktopApp.swift`), NICHT als lokaler `@State` in der View – so
/// löst ein erneuter Sidebar-Besuch keinen wiederholten Abruf aus (Tankerkönigs
/// Rate Limit liegt bei ca. 1 Anfrage/Minute).
@MainActor
@Observable
final class FuelPricesViewModel {
    enum Phase: Equatable {
        case needsKey
        case locating
        case fetching
        case ready
        case failed(FuelPricesError)
    }

    enum FuelPricesError: Equatable {
        case rejectedKey(String)
        case network
        case decoding
        case locationDenied
        case locationRestricted
        case locationUnavailable
        case locationTimeout

        var message: String {
            switch self {
            case .rejectedKey(let msg):
                return "Der Tankerkönig-API-Schlüssel wurde abgelehnt: \(msg). Bitte prüfe den Schlüssel."
            case .network:
                return "Keine Verbindung zum Tankerkönig-Dienst. Bitte prüfe deine Internetverbindung und versuche es erneut."
            case .decoding:
                return "Die Antwort von Tankerkönig konnte nicht verarbeitet werden."
            case .locationDenied:
                return "Der Standortzugriff wurde verweigert. Bitte erlaube ihn in den Systemeinstellungen unter „Datenschutz & Sicherheit\u{201C} › „Ortungsdienste\u{201C}."
            case .locationRestricted:
                return "Die Ortungsdienste sind auf diesem Gerät eingeschränkt."
            case .locationUnavailable:
                return "Dein aktueller Standort konnte nicht ermittelt werden. Bitte versuche es erneut."
            case .locationTimeout:
                return "Die Standortermittlung hat zu lange gedauert. Bitte versuche es erneut."
            }
        }

        /// Nur bei verweigertem Standortzugriff macht ein Link in die
        /// Systemeinstellungen Sinn.
        var showsSettingsButton: Bool { self == .locationDenied }
    }

    var apiKey: String = TankerkoenigKeyStore.get() ?? ""
    var isKeyFieldValid = false
    private(set) var phase: Phase = .needsKey
    private(set) var stations: [GasStation] = []
    private(set) var userCoordinate: CLLocationCoordinate2D?
    var enabledFuelKinds: Set<FuelKind> = Set(FuelKind.allCases)

    private var didAppear = false
    private var running = false
    private var lastFetchAt: Date?

    /// Manuelles Aktualisieren ist erst 60 s nach dem letzten Abruf wieder
    /// erlaubt (Tankerkönigs Rate Limit); der automatische Erststart ist
    /// davon ausgenommen.
    var canRefresh: Bool {
        !running && (lastFetchAt.map { Date().timeIntervalSince($0) >= 60 } ?? true)
    }

    /// Sichtbare Stationen: mindestens eine angehakte Sorte wird dort geführt.
    var visibleStations: [GasStation] {
        stations.filter { station in
            FuelKind.allCases.contains { enabledFuelKinds.contains($0) && $0.price(for: station) != nil }
        }
    }

    /// Wird beim ersten Erscheinen der View aufgerufen. Startet den Ablauf nur
    /// einmal pro App-Sitzung automatisch, wenn bereits ein gültiger
    /// Schlüssel hinterlegt ist.
    func onAppear() {
        guard !didAppear else { return }
        didAppear = true
        if UUID(uuidString: apiKey) != nil {
            start()
        } else {
            phase = .needsKey
        }
    }

    /// Speichert einen neu eingegebenen/geänderten Schlüssel und startet den
    /// Ablauf. Wird über den „Speichern & Laden"-Button ausgelöst.
    func saveKeyAndStart() {
        guard isKeyFieldValid else { return }
        TankerkoenigKeyStore.set(apiKey)
        start()
    }

    /// Manuelles Aktualisieren, respektiert die 60-s-Abklingzeit.
    func refresh() {
        guard canRefresh else { return }
        start()
    }

    private func start() {
        guard !running else { return }
        running = true
        Task { await runFlow() }
    }

    private func runFlow() async {
        defer { running = false }
        phase = .locating
        do {
            let coordinate = try await LocationProvider.currentCoordinate()
            userCoordinate = coordinate
            phase = .fetching
            stations = try await TankerkoenigService.stations(
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                radiusKm: 5,
                apiKey: apiKey
            )
            lastFetchAt = Date()
            phase = .ready
        } catch let error as LocationError {
            phase = .failed(map(error))
        } catch let error as TankerkoenigError {
            phase = .failed(map(error))
        } catch is DecodingError {
            phase = .failed(.decoding)
        } catch {
            phase = .failed(.network)
        }
    }

    private func map(_ error: LocationError) -> FuelPricesError {
        switch error {
        case .denied: return .locationDenied
        case .restricted: return .locationRestricted
        case .unavailable: return .locationUnavailable
        case .timeout: return .locationTimeout
        }
    }

    private func map(_ error: TankerkoenigError) -> FuelPricesError {
        switch error {
        case .rejected(let message): return .rejectedKey(message)
        }
    }
}
