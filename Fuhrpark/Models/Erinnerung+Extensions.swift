import Foundation
import CoreData

enum RepeatUnit: Int16, CaseIterable, Identifiable, Codable {
    case none = 0
    case week = 1
    case month = 2
    case year = 3

    var id: Int16 { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Keine"
        case .week: return "Wochen"
        case .month: return "Monate"
        case .year: return "Jahre"
        }
    }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .none: return nil
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

enum AdvanceNotice: Int16, CaseIterable, Identifiable, Codable {
    case none = 0
    case twoWeeks = 2
    case fourWeeks = 4
    case eightWeeks = 8

    var id: Int16 { rawValue }

    /// Vorlauf in Wochen (Rohwert entspricht direkt der Wochenzahl).
    var weeks: Int { Int(rawValue) }

    var displayName: String {
        switch self {
        case .none: return "Keine"
        case .twoWeeks: return "2 Wochen vorher"
        case .fourWeeks: return "4 Wochen vorher"
        case .eightWeeks: return "8 Wochen vorher"
        }
    }
}

extension Erinnerung {
    var repeatUnit: RepeatUnit {
        get { RepeatUnit(rawValue: repeatUnitRaw) ?? .none }
        set { repeatUnitRaw = newValue.rawValue }
    }

    var advanceNotice: AdvanceNotice {
        get { AdvanceNotice(rawValue: advanceNoticeRaw) ?? .none }
        set { advanceNoticeRaw = newValue.rawValue }
    }

    var isRecurring: Bool { repeatUnit != .none }

    /// Datum, ab dem die Erinnerung als fällig gilt: Fälligkeitsdatum minus
    /// Vorlaufzeit der vorzeitigen Erinnerung (identisch zum Fälligkeitsdatum,
    /// wenn keine vorzeitige Erinnerung gewählt ist).
    var earliestNoticeDate: Date {
        let due = dueDate ?? .distantFuture
        guard advanceNotice != .none else { return due }
        return Calendar.current.date(byAdding: .day, value: -advanceNotice.weeks * 7, to: due) ?? due
    }

    /// Fällig = heute >= Fälligkeitsdatum minus Vorlaufzeit, UND nicht erledigt.
    /// Grundlage für den Badge-Zähler in der Sidebar und die Farbmarkierung in der Liste.
    var isDue: Bool {
        guard !isDone else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let notice = Calendar.current.startOfDay(for: earliestNoticeDate)
        return today >= notice
    }

    /// Echt überfällig: das eigentliche Fälligkeitsdatum (nicht nur der Vorlauf)
    /// liegt in der Vergangenheit. Für die rote Hervorhebung in `ReminderRow`.
    var isOverdue: Bool {
        guard !isDone, let due = dueDate else { return false }
        return Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: due)
    }

    /// Kurzbeschreibung der Wiederholung, z. B. „alle 3 Monate" / „jede Woche".
    var repeatDescription: String? {
        guard isRecurring else { return nil }
        let n = Int(repeatIntervalValue)
        let unitWord: (singular: String, plural: String)
        switch repeatUnit {
        case .none: return nil
        case .week: unitWord = ("Woche", "Wochen")
        case .month: unitWord = ("Monat", "Monate")
        case .year: unitWord = ("Jahr", "Jahre")
        }
        guard n == 1 else { return "alle \(n) \(unitWord.plural)" }
        return repeatUnit == .week ? "jede \(unitWord.singular)" : "jeden \(unitWord.singular)"
    }

    // MARK: - Erledigt-Toggle mit Auto-Advance

    /// Markiert die Erinnerung als erledigt. Bei einer **nicht wiederkehrenden**
    /// Erinnerung ist das ein dauerhafter Endzustand (Toggle wie gewohnt). Bei
    /// einer **wiederkehrenden** Erinnerung springt sie stattdessen sofort auf
    /// den nächsten Fälligkeitstermin und bleibt offen (`isDone` bleibt `false`)
    /// – kein Verlauf einzelner Erledigungen, analog zu Apples Erinnerungen-App.
    /// Die Checkbox ist damit bei wiederkehrenden Erinnerungen nur ein UI-Trigger.
    func toggleDone(in context: NSManagedObjectContext) {
        if isRecurring {
            advanceToNextOccurrence()
        } else {
            isDone.toggle()
        }
        PersistenceController.shared.save(context: context)
    }

    /// Setzt `dueDate` auf den nächsten Termin (aktuelles Fälligkeitsdatum +
    /// ein Wiederholungsintervall). Bewusst ein einzelner Sprung (kein
    /// Nachhol-Loop bis zu einem zukünftigen Datum) – entspricht dem Verhalten
    /// von Apples Erinnerungen-App bei verspätet erledigten Wiederholungen.
    private func advanceToNextOccurrence() {
        guard let due = dueDate, let component = repeatUnit.calendarComponent else { return }
        dueDate = Calendar.current.date(byAdding: component, value: Int(repeatIntervalValue), to: due) ?? due
        isDone = false
    }
}
