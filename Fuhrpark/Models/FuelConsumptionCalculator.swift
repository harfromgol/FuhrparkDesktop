import Foundation

enum FuelConsumptionCalculator {
    /// Berechnet den Verbrauch (l/100km) automatisch, falls möglich.
    /// - Voraussetzungen: vorherige Betankung ist erfasst, war vollgetankt,
    ///   und die aktuelle Betankung ist ebenfalls vollgetankt.
    static func automaticConsumption(
        currentOdometer: Int32,
        currentLiters: Decimal,
        previousEntryExists: Bool,
        currentFullTank: Bool,
        previousEntry: FuelEntry?
    ) -> Double? {
        guard previousEntryExists, currentFullTank else { return nil }
        guard let previousEntry, previousEntry.fullTank else { return nil }

        let distance = currentOdometer - previousEntry.odometer
        guard distance > 0 else { return nil }

        let litersDouble = NSDecimalNumber(decimal: currentLiters).doubleValue
        return litersDouble / Double(distance) * 100.0
    }
}
