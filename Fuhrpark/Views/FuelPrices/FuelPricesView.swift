import SwiftUI
import MapKit
import CoreLocation
import AppKit

/// Spritpreise in der Umgebung: API-Key-Eingabe → Standort → Tankerkönig-
/// Umkreissuche → Karte mit Preis-Markierungen.
struct FuelPricesView: View {
    @Environment(FuelPricesViewModel.self) private var vm
    @Environment(\.openWindow) private var openWindow
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 16) {
            keyCard(vm: vm)

            switch vm.phase {
            case .needsKey:
                needsKeyHint
            case .locating:
                progressView("Standort wird ermittelt…")
            case .fetching:
                progressView("Spritpreise werden geladen…")
            case .ready:
                mapArea(vm: vm)
            case .failed(let error):
                if vm.stations.isEmpty {
                    errorView(error, vm: vm)
                } else {
                    mapArea(vm: vm)
                        .overlay(alignment: .top) { errorBanner(error) }
                }
            }
        }
        .padding(20)
        .navigationTitle("Spritpreise")
        .onAppear { vm.onAppear() }
        .onChange(of: vm.userCoordinate.map(EquatableCoordinate.init)) { _, wrapped in
            guard let coordinate = wrapped?.coordinate else { return }
            camera = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 12_000,
                    longitudinalMeters: 12_000
                )
            )
        }
    }

    private func keyCard(vm: FuelPricesViewModel) -> some View {
        @Bindable var vm = vm
        return GlassCard(title: "Tankerkönig-API-Schlüssel") {
            HStack(alignment: .top, spacing: 12) {
                ValidatedField(
                    title: "API-Schlüssel",
                    text: $vm.apiKey,
                    kind: .apiKey,
                    isValidBinding: $vm.isKeyFieldValid
                )
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let cooldownActive = vm.secondsRemaining(asOf: context.date) != nil
                    Button("Speichern & Laden") {
                        vm.saveKeyAndStart()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!vm.isKeyFieldValid || cooldownActive)
                    .pointerStyle(vm.isKeyFieldValid && !cooldownActive ? .link : nil)
                    .padding(.top, 20)
                }
            }
        }
    }

    private var needsKeyHint: some View {
        ContentUnavailableView {
            Label("Kein API-Schlüssel", systemImage: "key")
        } description: {
            VStack(spacing: 4) {
                Text("Hinterlege oben deinen Tankerkönig-API-Schlüssel, um Spritpreise in deiner Umgebung zu sehen.")
                Link("Kostenlos registrieren unter tankerkoenig.de", destination: URL(string: "https://creativecommons.tankerkoenig.de")!)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func progressView(_ text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: FuelPricesViewModel.FuelPricesError, vm: FuelPricesViewModel) -> some View {
        ContentUnavailableView {
            Label("Fehler", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            HStack {
                Button("Erneut versuchen") { vm.refresh() }
                    .buttonStyle(.glass)
                    .pointerStyle(.link)
                if error.showsSettingsButton {
                    Button("Systemeinstellungen öffnen") { openLocationSettings() }
                        .buttonStyle(.glass)
                        .pointerStyle(.link)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ error: FuelPricesViewModel.FuelPricesError) -> some View {
        Text(error.message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.red.opacity(0.4), lineWidth: 1))
            .padding(.top, 8)
    }

    private func mapArea(vm: FuelPricesViewModel) -> some View {
        @Bindable var vm = vm
        return TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = vm.secondsRemaining(asOf: context.date)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    FuelTypeFilterView(enabled: $vm.enabledFuelKinds)
                    Spacer()
                    if !vm.stations.isEmpty {
                        Button("Liste anzeigen", systemImage: "list.bullet") {
                            openWindow(id: "gas-station-list")
                        }
                        .buttonStyle(.glass)
                        .pointerStyle(.link)
                    }
                    Button("Aktualisieren", systemImage: "arrow.clockwise") {
                        vm.refresh()
                    }
                    .buttonStyle(.glass)
                    .disabled(remaining != nil)
                    .pointerStyle(remaining == nil ? .link : nil)
                }

                Map(position: $camera) {
                    UserAnnotation()
                    ForEach(vm.visibleStations) { station in
                        Annotation(station.name, coordinate: station.coordinate) {
                            StationAnnotationView(station: station, enabled: vm.enabledFuelKinds)
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    TankerkoenigAttributionView()
                    Spacer()
                    if let remaining {
                        Text("Nächste Abfrage in \(DisplayFormatter.countdownString(remaining))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// `CLLocationCoordinate2D` ist nicht `Equatable` – dieser Wrapper macht die
/// Koordinate für `.onChange(of:)` vergleichbar.
private struct EquatableCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
