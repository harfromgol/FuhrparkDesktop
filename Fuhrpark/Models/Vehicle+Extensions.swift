import AppKit
import Foundation
import CoreData

enum EngineType: Int16, CaseIterable, Identifiable, Codable {
    case combustion = 0
    case bev = 1

    var id: Int16 { rawValue }

    private var isBEV: Bool { self == .bev }

    var displayName: String {
        switch self {
        case .combustion: return "Verbrenner"
        case .bev: return "BEV"
        }
    }

    /// SF-Symbol-Name für die Fahrzeug-Miniatur, wenn kein Foto gesetzt ist.
    var iconName: String { isBEV ? "bolt.car" : "car" }

    // MARK: - Einheiten (Verbrenner: Liter/Sprit, BEV: kWh/Strom)

    /// Einheit der getankten bzw. geladenen Menge ("l" / "kWh").
    var energyUnit: String { isBEV ? "kWh" : "l" }
    /// Einheit des Verbrauchs ("l/100km" / "kWh/100km").
    var consumptionUnit: String { isBEV ? "kWh/100km" : "l/100km" }
    /// Suffix hinter dem €-Betrag beim Einheitspreis ("/l" / "/kWh").
    var pricePerUnitSuffix: String { isBEV ? "/kWh" : "/l" }

    // MARK: - Begriffe

    /// Vorgang im Singular ("Betankung" / "Ladung").
    var refuelNoun: String { isBEV ? "Ladung" : "Betankung" }
    /// Vorgang im Plural ("Betankungen" / "Ladungen").
    var refuelNounPlural: String { isBEV ? "Ladungen" : "Betankungen" }
    /// Titel für einen neuen Vorgang ("Neue Betankung" / "Neue Ladung").
    var newRefuelTitle: String { isBEV ? "Neue Ladung" : "Neue Betankung" }
    /// Ort des Vorgangs ("Tankstelle" / "Ladestation").
    var stationLabel: String { isBEV ? "Ladestation" : "Tankstelle" }
    /// Titel des Preis-Abschnitts ("Spritpreis" / "Strompreis").
    var priceTitle: String { isBEV ? "Strompreis" : "Spritpreis" }
    /// Kosten des Energieträgers ("Spritkosten" / "Stromkosten").
    var energyCostLabel: String { isBEV ? "Stromkosten" : "Spritkosten" }
    /// Getankte/geladene Gesamtmenge ("Getankt gesamt" / "Geladen gesamt").
    var totalEnergyLabel: String { isBEV ? "Geladen gesamt" : "Getankt gesamt" }
    /// Datum des letzten Vorgangs ("Letzte Tankung" / "Letzte Ladung").
    var lastRefuelLabel: String { isBEV ? "Letzte Ladung" : "Letzte Tankung" }
    /// Toggle „voll" ("Vollgetankt?" / "Vollgeladen?").
    var fullLabel: String { isBEV ? "Vollgeladen?" : "Vollgetankt?" }

    /// Feldbeschriftung Menge im Formular ("Menge (Liter)" / "Menge (kWh)").
    var amountFieldLabel: String { isBEV ? "Menge (kWh)" : "Menge (Liter)" }
    /// Feldbeschriftung Einheitspreis im Formular ("Preis pro Liter (€)" / "Preis pro kWh (€)").
    var pricePerUnitFieldLabel: String { isBEV ? "Preis pro kWh (€)" : "Preis pro Liter (€)" }
}

/// Kosten eines Kalenderjahrs, aufgeschlüsselt nach Betankungen und sonstigen Ausgaben.
struct YearlyCost: Identifiable {
    let year: Int
    let fuel: Decimal
    let expense: Decimal
    var total: Decimal { fuel + expense }
    var id: Int { year }
}

/// Gefahrene Kilometer eines Kalenderjahrs (siehe `Vehicle.kilometersByYear`).
/// Jahre, für die sich weder Start- noch Endstand ermitteln lassen, tauchen
/// dort gar nicht erst auf – daher hier kein optionaler Wert.
struct YearlyDistance: Identifiable {
    let year: Int
    let kilometers: Int32
    /// Interpolierter Kilometerstand zum 31.12. dieses Jahres (siehe
    /// `Vehicle.interpolatedOdometer(endOfYear:)`).
    let odometerAtYearEnd: Int32
    var id: Int { year }
}

extension Vehicle {
    var engineType: EngineType {
        get { EngineType(rawValue: engineTypeRaw) ?? .combustion }
        set { engineTypeRaw = newValue.rawValue }
    }

    /// Das gesetzte Fahrzeugbild, falls vorhanden. `nil`, wenn kein Bild
    /// gesetzt ist oder die Datei im Arbeitsverzeichnis nicht (mehr) existiert.
    var photo: NSImage? {
        guard let photoPath else { return nil }
        return VehiclePhotoStorage.loadImage(forRelativePath: photoPath)
    }

    /// Setzt den Zeitstempel der letzten Änderung auf jetzt. Wird beim Hinzufügen
    /// einer Betankung oder sonstigen Ausgabe aufgerufen. Reines Metadatum
    /// (u. a. über MCP abrufbar) – bestimmt seit Einführung der manuellen
    /// Drag&Drop-Sortierung (`sortOrder`) nicht mehr die Reihenfolge in der
    /// Seitenleiste.
    func touch() {
        lastChangedDts = Date()
    }

    var sortedFuelEntries: [FuelEntry] {
        let entries = (fuelEntries as? Set<FuelEntry>) ?? []
        return entries.sorted { $0.odometer < $1.odometer }
    }

    var sortedExpenses: [Expense] {
        let items = (expenses as? Set<Expense>) ?? []
        return items.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Zugeordnete Erinnerungen, nach Fälligkeitsdatum aufsteigend sortiert.
    var sortedReminders: [Erinnerung] {
        let set = (erinnerungen as? Set<Erinnerung>) ?? []
        return set.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    /// Zugeordnete Notizen, nach Datum absteigend sortiert (neueste zuerst).
    var sortedNotizen: [Notiz] {
        let set = (notizen as? Set<Notiz>) ?? []
        return set.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Letzte (vom Kilometerstand her höchste) Betankung, exklusive der übergebenen.
    func previousFuelEntry(before entry: FuelEntry?) -> FuelEntry? {
        let entries = sortedFuelEntries.filter { $0 !== entry }
        guard let entry else { return entries.last }
        return entries.filter { $0.odometer < entry.odometer }.max { $0.odometer < $1.odometer }
    }

    // MARK: - Mutationen

    /// Löscht dieses Fahrzeug inkl. aller zugehörigen Betankungen/Ausgaben
    /// (Core-Data-Cascade) und räumt die gespeicherte Statistik-Karten-
    /// Konfiguration auf, die sonst als Karteileiche zurückbliebe.
    func delete(in context: NSManagedObjectContext) {
        if let id {
            StatisticsCardVisibilityStore.removeEnabledCards(for: id)
        }
        context.delete(self)
        // Räumt die Belege der gelöschten Ausgaben mit ab – samt ihrer
        // Dateien, die früher als Karteileichen zurückblieben.
        DocumentCleanup.finishDeletion(in: context)
    }

    /// Markiert das Fahrzeug als stillgelegt. Endgültig: eine Reaktivierung
    /// ist nicht vorgesehen.
    func decommission(in context: NSManagedObjectContext) {
        decommissioned = true
        PersistenceController.shared.save(context: context)
    }

    // MARK: - Statistik

    /// Summe aller Betankungskosten.
    var totalFuelCost: Decimal {
        sortedFuelEntries.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? 0) }
    }

    /// Netto-Summe der sonstigen Buchungen: Ausgaben minus Einnahmen (Einnahmen
    /// zählen über `signedAmount` negativ).
    var totalExpenseCost: Decimal {
        sortedExpenses.reduce(Decimal.zero) { $0 + $1.signedAmount }
    }

    /// Anzahl der erfassten sonstigen Ausgaben.
    var expenseCount: Int {
        sortedExpenses.count
    }

    /// Datum der letzten (jüngsten) sonstigen Ausgabe.
    var lastExpenseDate: Date? {
        sortedExpenses.compactMap(\.date).max()
    }

    /// Gesamtkosten je Kategorie, nach Betrag absteigend sortiert. Eine Ausgabe
    /// mit mehreren Kategorien fließt mit ihrem vollen Betrag in jede davon ein;
    /// die Summe der Kategorien kann daher über den Ausgaben-Gesamtkosten liegen.
    var expenseCostByCategory: [(category: String, total: Decimal)] {
        var totals: [String: Decimal] = [:]
        for expense in sortedExpenses {
            let amount = expense.signedAmount
            let names = expense.categoryNames
            if names.isEmpty {
                totals["Ohne Kategorie", default: 0] += amount
            } else {
                for name in names {
                    totals[name, default: 0] += amount
                }
            }
        }
        return totals
            .map { (category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    /// Gesamtkosten (Betankungen + sonstige Ausgaben).
    var totalCost: Decimal {
        totalFuelCost + totalExpenseCost
    }

    /// Kosten pro Kalenderjahr (Betankungen und sonstige Ausgaben), neuestes Jahr zuerst.
    var costsByYear: [YearlyCost] {
        let calendar = Calendar.current
        var fuelByYear: [Int: Decimal] = [:]
        var expenseByYear: [Int: Decimal] = [:]

        for entry in sortedFuelEntries {
            guard let date = entry.date else { continue }
            let year = calendar.component(.year, from: date)
            fuelByYear[year, default: 0] += entry.amount?.decimalValue ?? 0
        }
        for expense in sortedExpenses {
            guard let date = expense.date else { continue }
            let year = calendar.component(.year, from: date)
            expenseByYear[year, default: 0] += expense.signedAmount
        }

        let years = Set(fuelByYear.keys).union(expenseByYear.keys)
        return years
            .map { YearlyCost(year: $0, fuel: fuelByYear[$0, default: 0], expense: expenseByYear[$0, default: 0]) }
            .sorted { $0.year > $1.year }
    }

    /// Interpolierter Kilometerstand zum 31.12. `year`, 23:59:59 Uhr: aus der
    /// letzten Betankung bis zu diesem Zeitpunkt und der ersten danach linear
    /// interpoliert (nach Datum, nicht nach Kilometerstand sortiert – anders
    /// als `sortedFuelEntries`).
    ///
    /// Randfälle:
    /// - Fehlt die vorherige Betankung (vor der allerersten Betankung
    ///   überhaupt), wird ersatzweise der Anfangsstand des Fahrzeugs als
    ///   Näherung für diesen Zeitpunkt verwendet.
    /// - Fehlt die folgende Betankung, weil `year` das laufende Kalenderjahr
    ///   ist, wird ersatzweise der Stand der letzten Betankung verwendet.
    /// - Fehlt die folgende Betankung aus einem anderen Grund (z. B. ein
    ///   zukünftiges Jahr ohne jede Betankung), liefert die Funktion `nil` –
    ///   `kilometersByYear` blendet ein solches Jahr dann aus.
    private func interpolatedOdometer(endOfYear year: Int) -> Double? {
        guard let boundary = Calendar.current.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return nil
        }
        let entriesByDate = sortedFuelEntries
            .compactMap { entry -> (date: Date, odometer: Int32)? in
                guard let date = entry.date else { return nil }
                return (date, entry.odometer)
            }
        let before = entriesByDate.filter { $0.date < boundary }.max { $0.date < $1.date }
        let after = entriesByDate.filter { $0.date >= boundary }.min { $0.date < $1.date }

        switch (before, after) {
        case let (before?, after?):
            let totalInterval = after.date.timeIntervalSince(before.date)
            guard totalInterval > 0 else { return Double(before.odometer) }
            let fraction = boundary.timeIntervalSince(before.date) / totalInterval
            return Double(before.odometer) + fraction * Double(after.odometer - before.odometer)
        case (nil, .some):
            return Double(odometer)
        case let (before?, nil):
            guard year == Calendar.current.component(.year, from: Date()) else { return nil }
            return Double(before.odometer)
        case (nil, nil):
            return nil
        }
    }

    /// Gefahrene Kilometer je Kalenderjahr, aus den zum jeweiligen 31.12.
    /// interpolierten Kilometerständen berechnet (siehe
    /// `interpolatedOdometer(endOfYear:)`). Dieselbe Jahresbasis wie
    /// `costsByYear`, neuestes Jahr zuerst; Jahre ohne ermittelbaren Start-
    /// oder Endstand (z. B. ein zukünftiges Jahr ohne jede Betankung) fehlen
    /// in der Liste, statt mit einem Platzhalter angezeigt zu werden.
    var kilometersByYear: [YearlyDistance] {
        costsByYear
            .compactMap { yearlyCost -> YearlyDistance? in
                let year = yearlyCost.year
                guard
                    let end = interpolatedOdometer(endOfYear: year),
                    let start = interpolatedOdometer(endOfYear: year - 1)
                else {
                    return nil
                }
                return YearlyDistance(
                    year: year,
                    kilometers: Int32((end - start).rounded()),
                    odometerAtYearEnd: Int32(end.rounded())
                )
            }
    }

    /// Höchster bekannter Kilometerstand: der Anlagestand oder – falls höher –
    /// der höchste Kilometerstand aus den erfassten Betankungen.
    var highestOdometer: Int32 {
        max(odometer, sortedFuelEntries.map(\.odometer).max() ?? odometer)
    }

    /// Gefahrene Kilometer seit Anlage des Fahrzeugs (höchster Betankungs-Kilometerstand
    /// minus anfänglicher Tachostand). Nil, wenn nicht ermittelbar.
    var drivenKilometers: Int32? {
        guard let maxOdometer = sortedFuelEntries.map(\.odometer).max(), maxOdometer > odometer else {
            return nil
        }
        return maxOdometer - odometer
    }

    /// Kosten pro Kilometer. Nil, wenn keine gefahrenen Kilometer bekannt sind.
    var costPerKilometer: Decimal? {
        guard let km = drivenKilometers, km > 0 else { return nil }
        return totalCost / Decimal(km)
    }

    // MARK: - Betankungs-Statistik

    /// Anzahl der erfassten Betankungen.
    var fuelEntryCount: Int {
        sortedFuelEntries.count
    }

    /// Datum der letzten (jüngsten) Betankung.
    var lastFuelDate: Date? {
        sortedFuelEntries.compactMap(\.date).max()
    }

    /// Summe aller getankten Liter.
    var totalLiters: Decimal {
        sortedFuelEntries.reduce(Decimal.zero) { $0 + ($1.liters?.decimalValue ?? 0) }
    }

    // MARK: - Spritpreis

    private var pricesPerLiter: [Decimal] {
        sortedFuelEntries.compactMap { $0.pricePerLiter?.decimalValue }
    }

    var minPricePerLiter: Decimal? { pricesPerLiter.min() }
    var maxPricePerLiter: Decimal? { pricesPerLiter.max() }
    var averagePricePerLiter: Decimal? {
        let prices = pricesPerLiter
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +) / Decimal(prices.count)
    }

    // MARK: - Verbrauch

    /// Effektiver Verbrauch einer Betankung: gespeicherter Wert, sonst live berechnet.
    func effectiveConsumption(for entry: FuelEntry) -> Double? {
        if let stored = entry.consumption?.doubleValue {
            return stored
        }
        return FuelConsumptionCalculator.automaticConsumption(
            currentOdometer: entry.odometer,
            currentLiters: entry.liters?.decimalValue ?? 0,
            previousEntryExists: entry.previousEntryExists,
            currentFullTank: entry.fullTank,
            previousEntry: previousFuelEntry(before: entry)
        )
    }

    private var consumptions: [Double] {
        sortedFuelEntries.compactMap { effectiveConsumption(for: $0) }
    }

    /// Anzahl der Betankungen mit ermitteltem Verbrauch.
    var consumptionCount: Int { consumptions.count }

    /// Verbrauchsverlauf (Datum und Verbrauch) je Betankung mit ermitteltem Wert,
    /// nach Datum aufsteigend sortiert.
    var consumptionHistory: [(date: Date, consumption: Double)] {
        sortedFuelEntries
            .compactMap { entry -> (date: Date, consumption: Double)? in
                guard let date = entry.date, let value = effectiveConsumption(for: entry) else { return nil }
                return (date, value)
            }
            .sorted { $0.date < $1.date }
    }

    var minConsumption: Double? { consumptions.min() }
    var maxConsumption: Double? { consumptions.max() }
    var averageConsumption: Double? {
        let values = consumptions
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
