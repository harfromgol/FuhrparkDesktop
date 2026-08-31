import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Auswahl in der Seitenleiste: allgemeine Statistik oder ein Fahrzeug.
enum SidebarSelection: Hashable {
    case statistics
    case fuelPrices
    case documents
    case notes
    case reminders
    case mcp
    case vehicle(Vehicle)
}

struct ContentView: View {
    @Environment(AppCommands.self) private var appCommands
    @Environment(FuelPricesViewModel.self) private var fuelPricesViewModel
    @Environment(PinnedFuelPricesViewModel.self) private var pinnedFuelPricesViewModel
    @Environment(UpdateChecker.self) private var updateChecker
    @State private var selection: SidebarSelection = .statistics

    /// Wird beim Start gesetzt, wenn sich der Datenspeicher nicht öffnen ließ
    /// (etwa weil eine Modellmigration fehlgeschlagen ist). Ohne diesen
    /// Hinweis stünde die App mit leeren Listen da und der Nutzer müsste
    /// glauben, seine Daten seien weg.
    @State private var showsStoreError = PersistenceController.shared.loadError != nil

    /// Geprüfte, aber noch nicht eingespielte Sicherung – hält den Zustand
    /// zwischen Dateiauswahl und Sicherheitsabfrage. Wird die Abfrage
    /// verneint, muss `BackupService.discard(_:)` aufräumen.
    @State private var pendingRestore: BackupInspection?

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
            case .documents:
                DocumentsView()
            case .notes:
                NotesView()
            case .reminders:
                RemindersView()
            case .mcp:
                MCPSettingsView()
            case .vehicle(let vehicle):
                VehicleDetailView(vehicle: vehicle, onDelete: { selection = .statistics })
                    .id(vehicle.objectID)
            }
        }
        // Der Titel in der Fensterleiste kommt von der `.navigationTitle` der
        // gerade gewählten Ansicht und überschreibt den Titel der Szene; der
        // Zusatz aus `Window(AppVariant.windowTitle, …)` wirkt nur im
        // „Fenster“-Menü. Beim Testbau kommt deshalb hier ein Untertitel dazu,
        // damit auch am Fenster selbst erkennbar ist, welcher Datenbestand
        // offen ist. Die produktive App bleibt unverändert.
        .navigationSubtitle(AppVariant.isTestContainer ? "Testdaten" : "")
        .alert("Datenbank konnte nicht geöffnet werden", isPresented: $showsStoreError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("""
                \(PersistenceController.shared.loadError ?? "")

                Deine Daten sind dadurch nicht verloren – sie wurden nur nicht \
                geladen. Bitte nichts eingeben und nichts löschen, solange \
                dieser Hinweis erscheint, sonst überschreibst du den bisherigen \
                Stand. Am besten die App beenden und die vorige Version wieder \
                installieren oder ein Backup einspielen.
                """)
        }
        .confirmationDialog(
            "Wirklich die App zurücksetzen?",
            isPresented: $appCommands.showResetAppConfirmation,
            titleVisibility: .visible
        ) {
            Button("App zurücksetzen", role: .destructive) {
                resetApp()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Alle Fahrzeuge, Betankungen, sonstigen Ausgaben, Kategorien, Erinnerungen, Notizen und die gespeicherten Belege/Fahrzeugbilder werden unwiderruflich gelöscht. Zusätzlich werden sämtliche Einstellungen zurückgesetzt: Tankerkönig-API-Schlüssel, angepinnte Spritpreise, das festgelegte Arbeitsverzeichnis, alle Filter, Sortierungen und Fenstergrößen. Die App beendet sich danach und startet beim nächsten Öffnen wie frisch installiert. Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
        // Export/Import laufen bewusst NICHT über `.fileExporter`/`.fileImporter`,
        // sondern über direkte `NSSavePanel`/`NSOpenPanel` (siehe
        // `presentExportPanel`/`presentImportPanel`): Beide SwiftUI-Modifier
        // zeigen den Dialog als Sheet, das am Fenster verankert und nicht frei
        // verschiebbar ist (siehe auch `DocumentsView.presentFolderPicker`).
        .onChange(of: appCommands.showExportDialog) { _, isShown in
            guard isShown else { return }
            appCommands.showExportDialog = false
            // Erst im nächsten Runloop-Durchlauf zeigen: Ruft man `runModal()`
            // noch innerhalb der Menü-Aktion auf, während das Menü selbst sich
            // gerade erst schließt, erscheint das Panel manchmal nicht – ein
            // bekanntes AppKit/SwiftUI-Timing-Problem bei aus `CommandMenu`
            // ausgelösten modalen Panels.
            DispatchQueue.main.async { presentExportPanel() }
        }
        .onChange(of: appCommands.showImportDialog) { _, isShown in
            guard isShown else { return }
            appCommands.showImportDialog = false
            DispatchQueue.main.async { presentImportPanel() }
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
        .modifier(UpdateNoticeModifier(updateChecker: updateChecker))
        .modifier(BackupModifier(
            appCommands: appCommands,
            pendingRestore: $pendingRestore,
            onBackupRequested: presentBackupFolderPanel,
            onRestoreRequested: presentRestoreFilePanel,
            onRestoreConfirmed: performRestore
        ))
    }

    /// Dateiname-Vorschlag ohne Endung; `fileExporter` ergänzt „.json".
    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "FuhrparkDesktop_\(formatter.string(from: Date()))"
    }

    private func presentExportPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(exportFilename).json"
        panel.prompt = "Sichern"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DataTransfer.exportData().write(to: url, options: .atomic)
        } catch {
            appCommands.transferError = error.localizedDescription
        }
    }

    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Importieren"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importData(from: url)
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

    /// Fragt den Ablageort ab und schreibt eine vollständige Sicherung.
    private func presentBackupFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Sichern"
        panel.message = "Ordner wählen, in dem die Sicherung abgelegt werden soll."
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        appCommands.isBackupRunning = true
        Task {
            defer { appCommands.isBackupRunning = false }
            do {
                let url = try await BackupService.createBackup(inFolder: folder)
                appCommands.backupResultMessage = "Die Sicherung wurde abgelegt unter:\n\(url.path)"
            } catch {
                appCommands.backupError = error.localizedDescription
            }
        }
    }

    /// Wählt eine Sicherung aus und entpackt sie zur Prüfung – ändert selbst
    /// noch nichts am Bestand. Das übernimmt erst `performRestore` nach der
    /// Sicherheitsabfrage.
    private func presentRestoreFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Öffnen"
        // Dynamischer Typ aus der Endung – die App meldet keinen eigenen
        // Dokumenttyp an. Klappt das nicht, lieber ungefiltert anzeigen als
        // die Datei gar nicht auswählbar zu machen.
        if let type = UTType(filenameExtension: BackupService.fileExtension) {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }

        appCommands.isBackupRunning = true
        Task {
            defer { appCommands.isBackupRunning = false }
            do {
                pendingRestore = try await BackupService.inspect(archiveURL: url)
            } catch {
                appCommands.backupError = error.localizedDescription
            }
        }
    }

    /// Spielt die bestätigte Sicherung ein. Fragt vorher den Zielordner für
    /// Belege und Fahrzeugbilder ab – nur, wenn welche im Archiv sind.
    private func performRestore(_ inspection: BackupInspection) {
        var documentsTarget: URL?
        let documentFolderCount = inspection.manifest.documentFolderCount
        let photoFileCount = inspection.manifest.photoFileCount ?? 0
        if documentFolderCount > 0 || photoFileCount > 0 {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.prompt = "Wählen"
            panel.message = restoreFolderPickerMessage(documents: documentFolderCount, photos: photoFileCount)
            // Der Ordner aus dem Backup als Ausgangspunkt – er darf, muss aber
            // nicht derselbe sein.
            if let previous = inspection.manifest.originalWorkingDirectoryPath {
                panel.directoryURL = URL(fileURLWithPath: previous)
            }
            guard panel.runModal() == .OK, let folder = panel.url else {
                BackupService.discard(inspection)
                return
            }
            documentsTarget = folder
        }

        // Auswahl zuerst zurücksetzen, da gleich alle Fahrzeuge gelöscht
        // werden – wie beim JSON-Import.
        selection = .statistics
        appCommands.isBackupRunning = true
        Task {
            defer { appCommands.isBackupRunning = false }
            do {
                try await BackupService.restore(inspection, documentsTarget: documentsTarget)
                appCommands.backupResultMessage = """
                    Die Sicherung wurde eingespielt.

                    Bitte starte FuhrparkDesktop neu, damit alle \
                    wiederhergestellten Einstellungen greifen.
                    """
            } catch {
                appCommands.backupError = error.localizedDescription
            }
        }
    }

    /// Text für die Ordnerauswahl beim Einspielen – nennt nur, was tatsächlich
    /// im Archiv steckt.
    private func restoreFolderPickerMessage(documents: Int, photos: Int) -> String {
        switch (documents > 0, photos > 0) {
        case (true, true):
            return "Ordner wählen, in dem die \(documents) Belege und \(photos) Fahrzeugbilder abgelegt werden sollen."
        case (true, false):
            return "Ordner wählen, in dem die \(documents) Belege abgelegt werden sollen."
        case (false, true):
            return "Ordner wählen, in dem die \(photos) Fahrzeugbilder abgelegt werden sollen."
        case (false, false):
            return "Ordner wählen."
        }
    }

    private func resetApp() {
        // Auswahl zuerst zurücksetzen, damit der Detailbereich nicht auf ein
        // gleich gelöschtes (invalidiertes) Fahrzeug zugreift, während
        // `AppReset` noch läuft.
        selection = .statistics
        fuelPricesViewModel.resetAPIKey()
        pinnedFuelPricesViewModel.resetPinnedSelections()
        // Core Data, Belege/Fahrzeugbilder und alle UserDefaults dieses
        // Containers löschen, dann die App beenden – siehe Doc-Kommentar an
        // `AppReset` für den Grund, warum kein automatischer Neustart folgt.
        AppReset.performFactoryReset()
    }
}

/// Bündelt die vier Präsentationen der Update-Prüfung in einem eigenen
/// `ViewModifier` – hält `body` schlank genug für den Type-Checker (sonst
/// „unable to type-check this expression in reasonable time", siehe
/// `FuelEntryListAlertsModifier` in `FuelEntryListWindow.swift` für dasselbe
/// Muster).
private struct UpdateNoticeModifier: ViewModifier {
    @Bindable var updateChecker: UpdateChecker

    func body(content: Content) -> some View {
        content
            .sheet(item: $updateChecker.availableRelease) { release in
                UpdateAvailableSheet(
                    release: release,
                    currentVersion: updateChecker.currentVersion,
                    automaticChecks: $updateChecker.automaticChecksEnabled,
                    onSkip: { updateChecker.skipOfferedRelease() },
                    onDismiss: { updateChecker.availableRelease = nil }
                )
            }
            .confirmationDialog(
                "Nach neuen Versionen suchen?",
                isPresented: $updateChecker.showsPermissionQuestion,
                titleVisibility: .visible
            ) {
                Button("Ja, beim Start nachsehen") {
                    Task { await updateChecker.answerPermissionQuestion(allowed: true) }
                }
                Button("Nein", role: .cancel) {
                    Task { await updateChecker.answerPermissionQuestion(allowed: false) }
                }
            } message: {
                Text("""
                    FuhrparkDesktop kann beim Start höchstens einmal täglich nachsehen, \
                    ob eine neue Version vorliegt. Dabei wird nur eine kleine Datei von \
                    fuhrpark-macos.gerd-klaus.de geladen – es werden keine Angaben über \
                    dich oder deinen Fuhrpark übertragen, auch nicht die verwendete \
                    Version.

                    Die Einstellung lässt sich jederzeit im Menü „FuhrparkDesktop“ ändern.
                    """)
            }
            .alert("Du hast die neueste Version", isPresented: $updateChecker.showsUpToDateConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("FuhrparkDesktop \(updateChecker.currentVersion) ist aktuell.")
            }
            .alert(
                "Suche nach Updates fehlgeschlagen",
                isPresented: Binding(
                    get: { updateChecker.manualCheckError != nil },
                    set: { if !$0 { updateChecker.manualCheckError = nil } }
                ),
                presenting: updateChecker.manualCheckError
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
    }
}

/// Bündelt die Präsentationen rund um Sicherung und Einspielen in einem
/// eigenen `ViewModifier` – hält `body` schlank genug für den Type-Checker,
/// dasselbe Muster wie `UpdateNoticeModifier` darüber.
private struct BackupModifier: ViewModifier {
    @Bindable var appCommands: AppCommands
    @Binding var pendingRestore: BackupInspection?
    let onBackupRequested: () -> Void
    let onRestoreRequested: () -> Void
    let onRestoreConfirmed: (BackupInspection) -> Void

    func body(content: Content) -> some View {
        content
            // Menüaktionen liegen außerhalb der View-Hierarchie und können
            // keine Panels zeigen; sie setzen ein Flag, das hier ausgewertet
            // und sofort zurückgenommen wird – wie bei Export/Import. Das
            // Zeigen selbst erst im nächsten Runloop-Durchlauf (siehe
            // Kommentar bei `showExportDialog` in `ContentView.body`).
            .onChange(of: appCommands.showBackupFolderPicker) { _, isShown in
                guard isShown else { return }
                appCommands.showBackupFolderPicker = false
                DispatchQueue.main.async { onBackupRequested() }
            }
            .onChange(of: appCommands.showRestoreFilePicker) { _, isShown in
                guard isShown else { return }
                appCommands.showRestoreFilePicker = false
                DispatchQueue.main.async { onRestoreRequested() }
            }
            .confirmationDialog(
                "Sicherung wirklich einspielen?",
                isPresented: Binding(
                    get: { pendingRestore != nil },
                    set: { if !$0 { pendingRestore = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingRestore
            ) { inspection in
                Button("Einspielen", role: .destructive) { onRestoreConfirmed(inspection) }
                Button("Abbrechen", role: .cancel) { BackupService.discard(inspection) }
            } message: { inspection in
                Text(Self.confirmationText(for: inspection))
            }
            .alert(
                "Sicherung",
                isPresented: Binding(
                    get: { appCommands.backupResultMessage != nil },
                    set: { if !$0 { appCommands.backupResultMessage = nil } }
                ),
                presenting: appCommands.backupResultMessage
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
            .alert(
                "Sicherung fehlgeschlagen",
                isPresented: Binding(
                    get: { appCommands.backupError != nil },
                    set: { if !$0 { appCommands.backupError = nil } }
                ),
                presenting: appCommands.backupError
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
    }

    private static func confirmationText(for inspection: BackupInspection) -> String {
        let belege = inspection.manifest.documentFolderCount
        let fotos = inspection.manifest.photoFileCount ?? 0
        let belegeText: String
        switch (belege > 0, fotos > 0) {
        case (true, true):
            belegeText = "Sie enthält \(belege) \(belege == 1 ? "Beleg" : "Belege") und \(fotos) \(fotos == 1 ? "Fahrzeugbild" : "Fahrzeugbilder") – der Ablageort dafür wird gleich abgefragt."
        case (true, false):
            belegeText = "Sie enthält \(belege) \(belege == 1 ? "Beleg" : "Belege") – der Ablageort dafür wird gleich abgefragt."
        case (false, true):
            belegeText = "Sie enthält \(fotos) \(fotos == 1 ? "Fahrzeugbild" : "Fahrzeugbilder") – der Ablageort dafür wird gleich abgefragt."
        case (false, false):
            belegeText = "Sie enthält keine Belege oder Fahrzeugbilder."
        }
        return """
            „\(inspection.archiveName)“ vom \
            \(FieldValidator.string(from: inspection.manifest.createdAt)) \
            (erstellt mit Version \(inspection.manifest.appVersion)). \(belegeText)

            Alle vorhandenen Fahrzeuge, Betankungen, Ausgaben, Erinnerungen, \
            Notizen und Einstellungen werden dabei unwiderruflich durch den \
            Stand aus der Sicherung ersetzt.
            """
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(AppCommands())
        .environment(FuelPricesViewModel())
        .environment(PinnedFuelPricesViewModel())
        .environment(UpdateChecker())
}
