import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Fuhrpark")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        if !inMemory {
            backfillVehicleTimestamps()
        }
    }

    /// Setzt für Fahrzeuge aus älteren Datenbeständen (vor Einführung von
    /// `lastChangedDts`) den Zeitstempel auf ihr Anlagedatum, damit die
    /// Sortierung nach letzter Änderung sofort sinnvoll startet.
    private func backfillVehicleTimestamps() {
        let context = container.viewContext
        let request = NSFetchRequest<Vehicle>(entityName: "Vehicle")
        request.predicate = NSPredicate(format: "lastChangedDts == nil")
        guard let vehicles = try? context.fetch(request), !vehicles.isEmpty else { return }
        for vehicle in vehicles {
            vehicle.lastChangedDts = vehicle.createdAt ?? Date()
        }
        save(context: context)
    }

    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let vehicle = Vehicle(context: context)
        vehicle.id = UUID()
        vehicle.licensePlate = "KA-FD 123"
        vehicle.manufacturer = "Volkswagen"
        vehicle.model = "Golf"
        vehicle.odometer = 42000
        vehicle.engineType = .combustion
        vehicle.createdAt = Date()
        vehicle.lastChangedDts = Date()

        let fuelEntry = FuelEntry(context: context)
        fuelEntry.id = UUID()
        fuelEntry.date = Date()
        fuelEntry.odometer = 42450
        fuelEntry.station = "Shell"
        fuelEntry.pricePerLiter = 1.799
        fuelEntry.liters = 38.5
        fuelEntry.amount = 69.26
        fuelEntry.fullTank = true
        fuelEntry.previousEntryExists = false
        fuelEntry.manualConsumption = false
        fuelEntry.vehicle = vehicle

        try? context.save()
        return controller
    }()

    func save(context: NSManagedObjectContext? = nil) {
        let context = context ?? container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Core Data save error: \(error)")
        }
    }

    /// Löscht sämtliche Daten (Fahrzeuge, Betankungen, sonstige Ausgaben,
    /// Kategorien) aus dem Core-Data-Speicher.
    ///
    /// Die Objekte werden einzeln im `viewContext` gelöscht (statt via
    /// `NSBatchDeleteRequest`), damit alle `@FetchRequest`-Views automatisch
    /// aktualisiert werden. Das Löschen der Fahrzeuge entfernt zugehörige
    /// Betankungen und Ausgaben zwar bereits per Cascade-Regel; die übrigen
    /// Entitäten werden dennoch explizit abgeräumt, um verwaiste Datensätze
    /// (z. B. eigenständige Kategorien) sicher mitzunehmen.
    func deleteAllData() {
        let context = container.viewContext
        let entityNames = ["Vehicle", "FuelEntry", "Expense", "Category"]
        for name in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            request.includesPropertyValues = false
            guard let objects = try? context.fetch(request) else { continue }
            for object in objects where !object.isDeleted {
                context.delete(object)
            }
        }
        save(context: context)
    }
}
