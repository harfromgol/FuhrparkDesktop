import SwiftUI
import UniformTypeIdentifiers

/// Auswahl in der Seitenleiste: allgemeine Statistik oder ein Fahrzeug.
enum SidebarSelection: Hashable {
    case statistics
    case fuelPrices
    case vehicle(Vehicle)
}

struct ContentView: View {
    @Environment(AppCommands.self) private var appCommands
    @Environment(FuelPricesViewModel.self) private var fuelPricesViewModel
    @State private var selection: SidebarSelection = .statistics

    var body: some View {
        @Bindable var appCommands = appCommands

        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            switch selection {
            case .statistics:
                StatisticsView()
            case .fuelPrices:
                FuelPricesView()
            case .vehicle(let vehicle):
                VehicleDetailView(vehicle: vehicle, onDelete: { selection = .statistics })
                    .id(vehicle.objectID)
            }
        }
        .confirmationDialog(
            "Wirklich alle Daten löschen?",
            isPresented: $appCommands.showDeleteAllDataConfirmation,
            titleVisibility: .visible
        ) {
            Button("Alle Daten löschen", role: .destructive) {
                deleteAllData()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Alle Fahrzeuge, Betankungen, sonstigen Ausgaben und Kategorien sowie der gespeicherte Tankerkönig-API-Schlüssel werden unwiderruflich gelöscht. Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
        .fileExporter(
            isPresented: $appCommands.showExportDialog,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                appCommands.transferError = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $appCommands.showImportDialog,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                importData(from: url)
            case .failure(let error):
                appCommands.transferError = error.localizedDescription
            }
        }
        .alert(
            "Datenübertragung fehlgeschlagen",
            isPresented: Binding(
                get: { appCommands.transferError != nil },
                set: { if !$0 { appCommands.transferError = nil } }
            ),
            presenting: appCommands.transferError
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }

    /// Dateiname-Vorschlag ohne Endung; `fileExporter` ergänzt „.json".
    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "FuhrparkDesktop_\(formatter.string(from: Date()))"
    }

    /// Serialisiert die Daten nur, wenn der Export-Dialog tatsächlich aktiv ist.
    private var exportDocument: JSONDocument {
        guard appCommands.showExportDialog else { return JSONDocument(data: Data()) }
        return JSONDocument(data: (try? DataTransfer.exportData()) ?? Data())
    }

    private func importData(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            // Auswahl zuerst zurücksetzen, da der Import alle Daten löscht.
            selection = .statistics
            try DataTransfer.importData(data)
        } catch {
            appCommands.transferError = error.localizedDescription
        }
    }

    private func deleteAllData() {
        // Auswahl zuerst zurücksetzen, damit der Detailbereich nicht auf ein
        // gleich gelöschtes (invalidiertes) Fahrzeug zugreift.
        selection = .statistics
        PersistenceController.shared.deleteAllData()
        fuelPricesViewModel.resetAPIKey()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(AppCommands())
        .environment(FuelPricesViewModel())
}
