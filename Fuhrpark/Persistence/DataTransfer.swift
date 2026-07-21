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

private struct DokumentDTO: Codable {
    var id: UUID
    var path: String
    /// Security-Scoped Bookmark der Datei. Löst sich beim Import nur auf,
    /// wenn die Datei noch am selben Ort auf demselben Mac liegt.
    var bookmarkData: Data
    var createdAt: Date
}

private struct CategoryDTO: Codable {
    var id: UUID
    var name: String
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
        bookmarkData = document.bookmarkData ?? Data()
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
            schemaVersion: 4,
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

        controller.deleteAllData()

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
                    let document = Dokument(context: context)
                    document.id = d.id
                    document.path = d.path
                    document.bookmarkData = d.bookmarkData
                    document.createdAt = d.createdAt
                    document.expense = expense
                }
            }
        }

        controller.save(context: context)

        // Fenster-Frames übernehmen. Fehlt das Feld (ältere Exporte), bleiben die
        // aktuell gespeicherten Frames unangetastet.
        if let windowFrames = root.windowFrames {
            WindowFrameStore.replaceAll(windowFrames)
        }
    }
}

// MARK: - FileDocument für den Export-Dialog

/// Trägt die fertig serialisierten JSON-Daten in den `fileExporter`.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
