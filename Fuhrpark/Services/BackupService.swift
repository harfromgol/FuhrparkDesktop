import Foundation

/// Ein entpacktes, noch nicht eingespieltes Backup.
///
/// Zwischen „Datei gewählt" und „einspielen" liegt die Sicherheitsabfrage;
/// damit deren Text die Kopfdaten nennen kann, wird vorher entpackt und das
/// Ergebnis hier festgehalten. Wird die Abfrage verneint, muss
/// `BackupService.discard(_:)` das Temp-Verzeichnis wieder aufräumen.
struct BackupInspection {
    let manifest: BackupManifest
    let unpackedDirectory: URL
    /// Nur für die Anzeige in der Sicherheitsabfrage.
    let archiveName: String
}

/// Vollständige Sicherung: Fuhrparkdaten, Einstellungen und Belegdateien in
/// einem einzelnen komprimierten Archiv.
///
/// Abgrenzung zum JSON-Export in `DataTransfer`: Der Export ist das
/// **teilbare**, lesbare Format ohne Geheimnisse und ohne Dateien. Diese
/// Sicherung ist die **private** Komplettkopie derselben Installation und
/// enthält deshalb auch den API-Schlüssel und die Belege.
///
/// Bewusste Grenze: Der Datenteil entsteht über `DataTransfer.exportData()`
/// und erbt dessen Reichweite – der Export läuft über `Vehicle`, Objekte ohne
/// Fahrzeugbezug (verwaiste Kategorie, Erinnerung oder Beleg) sind nicht
/// erfasst. Über die Oberfläche lassen sich solche Objekte nicht erzeugen.
/// Eine Byte-Kopie der SQLite-Dateien wäre die Alternative, ist aber wegen
/// `-wal`/`-shm` und der Modellmigration deutlich fehleranfälliger.
@MainActor
enum BackupService {
    // `nonisolated`, weil sie zum Archivformat gehören und nicht zum
    // Main-Actor: Das Packen und Entpacken läuft im Hintergrund und muss sie
    // dort lesen können.
    nonisolated static let fileExtension = "fuhrparkbackup"

    nonisolated private static let manifestFilename = "manifest.json"
    nonisolated private static let dataFilename = "data.json"
    nonisolated private static let settingsFilename = "settings.plist"
    nonisolated private static let documentsFolderName = "documents"

    // MARK: - Sichern

    /// Schreibt eine vollständige Sicherung in `folder` und liefert die
    /// erzeugte Datei zurück.
    static func createBackup(inFolder folder: URL) async throws -> URL {
        // Core Data und UserDefaults gehören auf den Main-Actor; beides ist
        // schnell. Das Kopieren der Belege und das Packen laufen danach im
        // Hintergrund, damit die Oberfläche nicht einfriert.
        let dataJSON = try DataTransfer.exportData()
        let settings = try SettingsSnapshot.capture()
        let documentIDs = (try? DocumentStorage.documentFolderIDs()) ?? []
        let originalPath = WorkingDirectoryStore.displayPath
        let appVersion = UpdateCheckService.currentVersion

        return try await Task.detached(priority: .userInitiated) {
            try writeArchive(
                dataJSON: dataJSON,
                settings: settings,
                documentIDs: documentIDs,
                originalWorkingDirectoryPath: originalPath,
                appVersion: appVersion,
                destinationFolder: folder
            )
        }.value
    }

    private nonisolated static func writeArchive(
        dataJSON: Data,
        settings: Data,
        documentIDs: Set<UUID>,
        originalWorkingDirectoryPath: String?,
        appVersion: String,
        destinationFolder: URL
    ) throws -> URL {
        // Das Staging-Verzeichnis liegt im Container-Temp und ist damit
        // sandbox-unkritisch. Dabei entsteht kurzzeitig eine zweite Kopie
        // aller Belege – bei den zu erwartenden Größen unproblematisch.
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("FuhrparkBackup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        try dataJSON.write(to: staging.appendingPathComponent(dataFilename))
        try settings.write(to: staging.appendingPathComponent(settingsFilename))

        if !documentIDs.isEmpty {
            let documentsDir = staging.appendingPathComponent(documentsFolderName, isDirectory: true)
            try FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
            // Ein einziger Zugriffsblock für alle Ordner statt einer je
            // Beleg – der Security-Scope ist nicht umsonst zu haben.
            try WorkingDirectoryStore.withAccess { workingDirURL in
                for id in documentIDs {
                    let source = workingDirURL.appendingPathComponent(id.uuidString, isDirectory: true)
                    guard FileManager.default.fileExists(atPath: source.path) else { continue }
                    try FileManager.default.copyItem(
                        at: source,
                        to: documentsDir.appendingPathComponent(id.uuidString, isDirectory: true)
                    )
                }
            }
        }

        let manifest = BackupManifest(
            formatVersion: BackupManifest.currentFormatVersion,
            appVersion: appVersion,
            createdAt: Date(),
            documentFolderCount: documentIDs.count,
            originalWorkingDirectoryPath: originalWorkingDirectoryPath
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: staging.appendingPathComponent(manifestFilename))

        let archiveURL = uniqueArchiveURL(in: destinationFolder)
        let accessed = destinationFolder.startAccessingSecurityScopedResource()
        defer { if accessed { destinationFolder.stopAccessingSecurityScopedResource() } }
        try BackupArchive.encode(stagingDirectory: staging, to: archiveURL)
        return archiveURL
    }

    /// `FuhrparkDesktop-Backup_20260816-0930.fuhrparkbackup`, bei Namensgleichheit
    /// mit angehängter Nummer – zwei Sicherungen in derselben Minute dürfen
    /// sich nicht gegenseitig überschreiben.
    private nonisolated static func uniqueArchiveURL(in folder: URL) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let base = "FuhrparkDesktop-Backup_\(formatter.string(from: Date()))"

        var candidate = folder.appendingPathComponent("\(base).\(fileExtension)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base)-\(counter).\(fileExtension)")
            counter += 1
        }
        return candidate
    }

    // MARK: - Einspielen

    /// Entpackt das Archiv und liest die Kopfdaten – ohne irgendetwas am
    /// Bestand zu ändern.
    static func inspect(archiveURL: URL) async throws -> BackupInspection {
        let name = archiveURL.lastPathComponent
        return try await Task.detached(priority: .userInitiated) {
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("FuhrparkRestore-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

            let accessed = archiveURL.startAccessingSecurityScopedResource()
            defer { if accessed { archiveURL.stopAccessingSecurityScopedResource() } }

            do {
                try BackupArchive.decode(archiveURL: archiveURL, to: temp)

                let manifestURL = temp.appendingPathComponent(manifestFilename)
                guard let manifestData = try? Data(contentsOf: manifestURL) else {
                    throw BackupArchiveError.incomplete(missing: manifestFilename)
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let manifest = try decoder.decode(BackupManifest.self, from: manifestData)

                // Lieber gar nicht einspielen als halb: Der JSON-Import prüft
                // seine eigene `schemaVersion` bis heute nicht – dieser Fehler
                // soll sich hier nicht wiederholen.
                guard manifest.formatVersion <= BackupManifest.currentFormatVersion else {
                    throw BackupArchiveError.unsupportedFormat(
                        found: manifest.formatVersion,
                        supported: BackupManifest.currentFormatVersion
                    )
                }
                guard FileManager.default.fileExists(
                    atPath: temp.appendingPathComponent(dataFilename).path
                ) else {
                    throw BackupArchiveError.incomplete(missing: dataFilename)
                }

                return BackupInspection(manifest: manifest, unpackedDirectory: temp, archiveName: name)
            } catch {
                try? FileManager.default.removeItem(at: temp)
                throw error
            }
        }.value
    }

    /// Verwirft ein geprüftes, aber nicht eingespieltes Backup.
    static func discard(_ inspection: BackupInspection) {
        try? FileManager.default.removeItem(at: inspection.unpackedDirectory)
    }

    /// Spielt das geprüfte Backup ein. **Löscht den gesamten bisherigen
    /// Bestand.**
    ///
    /// Die Reihenfolge ist der eigentliche Kern und darf nicht vertauscht
    /// werden – die Begründung steht jeweils am Schritt.
    static func restore(_ inspection: BackupInspection, documentsTarget: URL?) async throws {
        let unpacked = inspection.unpackedDirectory
        defer { try? FileManager.default.removeItem(at: unpacked) }

        // 1. Einstellungen zuerst: `setPersistentDomain` ersetzt den
        //    kompletten Domain und würde ein danach gesetztes
        //    Arbeitsverzeichnis wieder wegräumen.
        if let settingsData = try? Data(contentsOf: unpacked.appendingPathComponent(settingsFilename)) {
            try SettingsSnapshot.restore(from: settingsData)
        }

        // 2. Arbeitsverzeichnis danach – der Nutzer darf einen anderen Ordner
        //    wählen als den, aus dem gesichert wurde.
        if let documentsTarget {
            try WorkingDirectoryStore.set(url: documentsTarget)
        }

        // 3. Daten einspielen. Löscht den Altbestand und räumt am Ende das
        //    Arbeitsverzeichnis auf: Belegordner, die die frisch eingespielte
        //    Datenbank nicht kennt, fallen weg. Normale Dateien und Ordner,
        //    deren Name keine UUID ist, bleiben unangetastet.
        let dataJSON = try Data(contentsOf: unpacked.appendingPathComponent(dataFilename))
        try DataTransfer.importData(dataJSON)

        // 4. Belege zuletzt – NACH Schritt 3. Andersherum hielte der Aufräumer
        //    aus `importData` die gerade entpackten Ordner für Fremdkörper und
        //    löschte sie wieder.
        guard inspection.manifest.documentFolderCount > 0, documentsTarget != nil else { return }
        try await Task.detached(priority: .userInitiated) {
            try restoreDocuments(from: unpacked)
        }.value
    }

    private nonisolated static func restoreDocuments(from unpacked: URL) throws {
        let documentsDir = unpacked.appendingPathComponent(documentsFolderName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: documentsDir.path) else { return }

        let folders = try FileManager.default.contentsOfDirectory(
            at: documentsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        try WorkingDirectoryStore.withAccess { workingDirURL in
            for folder in folders {
                // Nur UUID-benannte Ordner, dasselbe Schutzgitter wie in
                // `DocumentStorage.documentFolderIDs()`.
                guard UUID(uuidString: folder.lastPathComponent) != nil else { continue }
                let target = workingDirURL.appendingPathComponent(
                    folder.lastPathComponent,
                    isDirectory: true
                )
                try? FileManager.default.removeItem(at: target)
                try FileManager.default.copyItem(at: folder, to: target)
            }
        }
    }
}
