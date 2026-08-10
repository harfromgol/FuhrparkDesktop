import SwiftUI

/// Inhalt der Menüleisten-Erweiterung: angepinnte Tankstellen/Sorten mit
/// Preis, Update-Intervall und manuellem Aktualisieren-Button.
struct PinnedFuelPricesMenuView: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 12) {
            if vm.pinnedSelections.isEmpty {
                ContentUnavailableView(
                    "Keine Auswahl",
                    systemImage: "fuelpump",
                    description: Text("Pinne Tankstellen/Sorten über „Liste anzeigen\u{201C} im Bereich Spritpreise an.")
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.pinnedSelections) { selection in
                        PinnedFuelPriceRow(selection: selection)
                    }
                }

                if let lastErrorMessage = vm.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Divider()

                Picker("Aktualisierung", selection: $vm.refreshInterval) {
                    ForEach(FuelPriceRefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = vm.secondsRemaining(asOf: context.date)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Spacer()
                            Button("Aktualisieren", systemImage: "arrow.clockwise") {
                                Task { await vm.refresh() }
                            }
                            .buttonStyle(.glass)
                            .disabled(remaining != nil || vm.isRefreshing)
                            .pointerStyle(remaining == nil && !vm.isRefreshing ? .link : nil)
                        }
                        if let remaining {
                            Text("Nächste Abfrage in \(DisplayFormatter.countdownString(remaining))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Divider()

                TankerkoenigAttributionView()
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
