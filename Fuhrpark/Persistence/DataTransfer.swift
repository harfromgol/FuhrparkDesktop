import Foundation
import CoreData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - JSON-Struktur

private struct ExportRoot: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var vehicles: [VehicleDTO]
    /// Gespeicherte Fenster-Frames (Position/Größe) je Fenster-Schlüssel.
    /// Optional, damit ältere Exporte (ohne dieses Feld) weiterhin lesbar sind.
    var windowFrames: [String: WindowFrame]?
}

private struct VehicleDTO: Codable {
    var id: UUID
    var licensePlate: String
    var manufacturer: String
    var model: String
    var odometer: Int32
    var engineTypeRaw: Int16
    /// Stillgelegt-Kennzeichen. Optional, damit ältere Exporte (ohne dieses Feld)
    /// weiterhin lesbar sind – fehlt es, gilt das Fahrzeug als aktiv.
    var decommissioned: Bool?
    var createdAt: Date
    var lastChangedDts: Date?
    var fuelEntries: [FuelEntryDTO]
    var expenses: [ExpenseDTO]
    var categories: [CategoryDTO]
    /// Zugeordnete Erinnerungen. Optional, damit ältere Exporte (ohne dieses
    /// Feld) weiterhin lesbar sind – fehlt es, hat das Fahrzeug keine Erinnerungen.
    var reminders: [ReminderDTO]?
    /// Relativer Pfad des Fahrzeugbilds im Arbeitsverzeichnis (siehe
    /// `VehiclePhotoStorage`). Optional wie bei Dokumenten aus demselben
    /// Grund: die Datei selbst wird nicht mit übertragen, nur der Verweis –
    /// ohne ihn fände die App das beim Sichern vorhandene Bild beim
    /// Wiedereinspielen nicht mehr, obwohl die Datei noch am selben Namen
    /// (Fahrzeug-ID) im Arbeitsverzeichnis liegt.
    var photoPath: String?
    /// Vom Nutzer per Drag&Drop festgelegte Position in der Seitenleiste.
    /// Optional, damit ältere Exporte (ohne dieses Feld) weiterhin lesbar
    /// sind – fehlt es, sortiert das Fahrzeug beim Import mit dem
    /// Standardwert 0 ein.
    var sortOrder: Int32?
}

private struct FuelEntryDTO: Codable {
    var id: UUID
    var date: Date
    var odometer: Int32
    var station: String
    var pricePerLiter: Decimal
    var liters: Decimal
    var amount: Decimal
    var fullTank: Bool
    var previousEntryExists: Bool
    var manualConsumption: Bool
    var consumption: Double?
}

private struct ExpenseDTO: Codable {
    var id: UUID
    var date: Date
    var amount: Decimal
    /// Einnahme statt Ausgabe. Optional, damit ältere Exporte (ohne dieses Feld)
    /// weiterhin lesbar sind – fehlt es, gilt der Eintrag als Ausgabe.
    var isIncome: Bool?
    var recipient: String
    var purpose: String
    var categoryIDs: [UUID]
    /// Zugeordnete Dokumente. Optional, damit ältere Exporte (ohne dieses Feld)
    /// weiterhin lesbar sind – fehlt es, hat die Ausgabe keine Dokumente.
    var documents: [DokumentDTO]?
}

/// Dateien werden nicht mehr per Security-Scoped-Bookmark referenziert,
/// sondern beim Hinzufügen in ein konfiguriertes Arbeitsverzeichnis kopiert
/// (siehe `WorkingDirectoryStore`/`DocumentStorage`). Der Export enthält
/// daher keine Binärdaten, nur den relativen Pfad – beim Import müssen die
/// referenzierten Dateien bereits im (auf dem Zielrechner separat zu
/// konfigurierenden) Arbeitsverzeichnis liegen.
private struct DokumentDTO: Codable {
    var id: UUID
    var path: String
    var createdAt: Date
}

private struct CategoryDTO: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
}

private struct ReminderDTO: Codable {
    var id: UUID
    var title: String
    var dueDate: Date
    var isDone: Bool
    var repeatIntervalValue: Int16
    var repeatUnitRaw: Int16
    var advanceNoticeRaw: Int16
    var createdAt: Date
}

// MARK: - Entität -> DTO

private extension VehicleDTO {
    init(vehicle: Vehicle) {
        id = vehicle.id ?? UUID()
        licensePlate = vehicle.licensePlate ?? ""
        manufacturer = vehicle.manufacturer ?? ""
        model = vehicle.model ?? ""
        odometer = vehicle.odometer
        engineTypeRaw = vehicle.engineTypeRaw
        decommissioned = vehicle.decommissioned
        createdAt = vehicle.createdAt ?? Date()
        lastChangedDts = vehicle.lastChangedDts
        fuelEntries = vehicle.sortedFuelEntries.map(FuelEntryDTO.init(entry:))
        expenses = vehicle.sortedExpenses.map(ExpenseDTO.init(expense:))
        categories = (vehicle.categories as? Set<Category> ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
            .map(CategoryDTO.init(category:))
        reminders = vehicle.sortedReminders.map(ReminderDTO.init(reminder:))
        photoPath = vehicle.photoPath
        sortOrder = vehicle.sortOrder
    }
}

private extension FuelEntryDTO {
    init(entry: FuelEntry) {
        id = entry.id ?? UUID()
        date = entry.date ?? Date()
        odometer = entry.odometer
        station = entry.station ?? ""
        pricePerLiter = entry.pricePerLiter?.decimalValue ?? 0
        liters = entry.liters?.decimalValue ?? 0
        amount = entry.amount?.decimalValue ?? 0
        fullTank = entry.fullTank
        previousEntryExists = entry.previousEntryExists
        manualConsumption = entry.manualConsumption
        consumption = entry.consumption?.doubleValue
    }
}

private extension ExpenseDTO {
    init(expense: Expense) {
        id = expense.id ?? UUID()
        date = expense.date ?? Date()
        amount = expense.amount?.decimalValue ?? 0
        isIncome = expense.isIncome
        recipient = expense.recipient ?? ""
        purpose = expense.purpose ?? ""
        categoryIDs = expense.sortedCategories.compactMap { $0.id }
        documents = expense.sortedDocuments.map(DokumentDTO.init(document:))
    }
}

private extension DokumentDTO {
    init(document: Dokument) {
        id = document.id ?? UUID()
        path = document.path ?? ""
        createdAt = document.createdAt ?? Date()
    }
}

private extension CategoryDTO {
    init(category: Category) {
        id = category.id ?? UUID()
        name = category.name ?? ""
        createdAt = category.createdAt ?? Date()
    }
}

private extension ReminderDTO {
    init(reminder: Erinnerung) {
        id = reminder.id ?? UUID()
        title = reminder.title ?? ""
        dueDate = reminder.dueDate ?? Date()
        isDone = reminder.isDone
        repeatIntervalValue = reminder.repeatIntervalValue
        repeatUnitRaw = reminder.repeatUnitRaw
        advanceNoticeRaw = reminder.advanceNoticeRaw
        createdAt = reminder.createdAt ?? Date()
    }
}

// MARK: - Export / Import

enum DataTransfer {
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Serialisiert alle Fahrzeuge samt Betankungen, Ausgaben und Kategorien als JSON.
    static func exportData() throws -> Data {
        let context = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<Vehicle>(entityName: "Vehicle")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Vehicle.createdAt, ascending: true)]
        let vehicles = try context.fetch(request)
        let root = ExportRoot(
            schemaVersion: 7,
            exportedAt: Date(),
            vehicles: vehicles.map(VehicleDTO.init(vehicle:)),
            windowFrames: WindowFrameStore.all()
        )
        return try makeEncoder().encode(root)
    }

    /// Löscht alle vorhandenen Daten und ersetzt sie durch die im JSON enthaltenen.
    /// Das JSON wird zuerst vollständig geparst – schlägt das fehl, bleiben die
    /// bestehenden Daten unangetastet.
    static func importData(_ data: Data) throws {
        let root = try makeDecoder().decode(ExportRoot.self, from: data)
        let controller = PersistenceController.shared
        let context = controller.container.viewContext

        // Bewusst OHNE Dateien anzufassen: Bis hierher würde sonst der
        // Belegordner geleert – und gleich darauf entstünden Einträge, die
        // genau auf diese eben gelöschten Dateien zeigen. Der Abgleich mit
        // dem Arbeitsverzeichnis passiert erst ganz am Schluss, gegen den
        // dann gültigen Datenbankstand.
        controller.deleteAllData(sweepingFiles: false)

        // Belege liegen im JSON unter der jeweiligen Ausgabe. Ein Beleg, der
        // mehrere Ausgaben belegt, taucht deshalb mehrfach auf – mit
        // derselben ID. Über diesen Zwischenspeicher wird daraus wieder ein
        // einziger Datensatz. Er liegt außerhalb der Fahrzeugschleife, weil
        // dieselbe ID in mehreren Ausgaben vorkommen kann (anders als
        // `categoriesByID`, das fahrzeuggebunden bleibt).
        var documentsByID: [UUID: Dokument] = [:]

        for dto in root.vehicles {
            let vehicle = Vehicle(context: context)
            vehicle.id = dto.id
            vehicle.licensePlate = dto.licensePlate
            vehicle.manufacturer = dto.manufacturer
            vehicle.model = dto.model
            vehicle.odometer = dto.odometer
            vehicle.engineTypeRaw = dto.engineTypeRaw
            vehicle.decommissioned = dto.decommissioned ?? false
            vehicle.createdAt = dto.createdAt
            vehicle.lastChangedDts = dto.lastChangedDts
            vehicle.photoPath = dto.photoPath
            vehicle.sortOrder = dto.sortOrder ?? 0

            // Kategorien zuerst anlegen, damit die Ausgaben sie referenzieren können.
            var categoriesByID: [UUID: Category] = [:]
            for c in dto.categories {
                let category = Category(context: context)
                category.id = c.id
                category.name = c.name
                category.createdAt = c.createdAt
                category.vehicle = vehicle
                categoriesByID[c.id] = category
            }

            for f in dto.fuelEntries {
                let entry = FuelEntry(context: context)
                entry.id = f.id
                entry.date = f.date
                entry.odometer = f.odometer
                entry.station = f.station
                entry.pricePerLiter = NSDecimalNumber(decimal: f.pricePerLiter)
                entry.liters = NSDecimalNumber(decimal: f.liters)
                entry.amount = NSDecimalNumber(decimal: f.amount)
                entry.fullTank = f.fullTank
                entry.previousEntryExists = f.previousEntryExists
                entry.manualConsumption = f.manualConsumption
                if let consumption = f.consumption {
                    entry.consumption = NSNumber(value: consumption)
                }
                entry.vehicle = vehicle
            }

            for e in dto.expenses {
                let expense = Expense(context: context)
                expense.id = e.id
                expense.isIncome = e.isIncome ?? false
                expense.date = e.date
                expense.amount = NSDecimalNumber(decimal: e.amount)
                expense.recipient = e.recipient
                expense.purpose = e.purpose
                expense.categories = NSSet(array: e.categoryIDs.compactMap { categoriesByID[$0] })
                expense.vehicle = vehicle

                for d in e.documents ?? [] {
                    if let bekannt = documentsByID[d.id] {
                        // Ein Beleg gehört zu genau einem Fahrzeug. Taucht
                        // dieselbe ID unter einem zweiten auf, wäre der
                        // Datenbestand widersprüchlich – dann lieber die
                        // Verknüpfung auslassen als das Fahrzeug des Belegs
                        // mehrdeutig machen.
                        if bekannt.vehicle == nil || bekannt.vehicle == vehicle {
                            bekannt.link(to: expense)
                        }
                        continue
                    }
                    let document = Dokument(context: context)
                    document.id = d.id
                    document.path = d.path
                    document.createdAt = d.createdAt
                    document.link(to: expense)
                    documentsByID[d.id] = document
                }
            }

            for r in dto.reminders ?? [] {
                let reminder = Erinnerung(context: context)
                reminder.id = r.id
                reminder.title = r.title
                reminder.dueDate = r.dueDate
                reminder.isDone = r.isDone
                reminder.repeatIntervalValue = r.repeatIntervalValue
                reminder.repeatUnitRaw = r.repeatUnitRaw
                reminder.advanceNoticeRaw = r.advanceNoticeRaw
                reminder.createdAt = r.createdAt
                reminder.vehicle = vehicle
            }
        }

        controller.save(context: context)

        // Jetzt erst den Belegordner an den neuen Stand angleichen. Beim
        // Wiedereinlesen des eigenen Exports stehen alle Beleg-IDs wieder in
        // der Datenbank, ihre Ordner überleben also; beim Import eines
        // fremden Exports kennt die Datenbank sie nicht mehr und die alten
        // Ordner fallen weg – ohne Karteileichen zu hinterlassen.
        DocumentCleanup.sweepWorkingDirectory(in: context)

        // Fenster-Frames übernehmen. Fehlt das Feld (ältere Exporte), bleiben die
        // aktuell gespeicherten Frames unangetastet.
        if let windowFrames = root.windowFrames {
            WindowFrameStore.replaceAll(windowFrames)
        }
    }
}
