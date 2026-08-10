import SwiftUI

/// Eigenständiges Fenster mit allen Tankstellen der letzten Umkreissuche.
/// Zeigt bewusst ALLE von `FuelPricesViewModel.stations` geführten Sorten,
/// ungefiltert vom Karten-Filter (`enabledFuelKinds`) – der ist eine
/// Anzeige-Entscheidung für die Karte, hier geht es um die vollständige
/// Auswahl fürs Anpinnen.
struct GasStationListWindow: View {
    @Environment(FuelPricesViewModel.self) private var fuelPricesViewModel

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 12) {
                    if fuelPricesViewModel.stations.isEmpty {
                        ContentUnavailableView(
                            "Keine Tankstellen",
                            systemImage: "fuelpump",
                            description: Text("Führe zuerst im Bereich „Spritpreise\u{201C} eine Umkreissuche durch.")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(fuelPricesViewModel.stations) { station in
                            GasStationPriceRow(station: station)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 420, minHeight: 400)
        .navigationTitle("Tankstellenliste")
    }
}
