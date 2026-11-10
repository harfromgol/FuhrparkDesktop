import SwiftUI
import CoreData

/// Die fälligen Erinnerungen aller Fahrzeuge – der Inhalt von „Allgemein →
/// Erinnerungen“ im Hauptfenster. „Fällig“ bedeutet dasselbe wie beim roten
/// Zähler am Seitenleisten-Eintrag (`SidebarView.dueReminderCount`): offen
/// und das Fälligkeitsdatum abzüglich Vorlaufzeit ist erreicht (siehe
/// `Erinnerung.isDue`). Liste und Zähler zeigen damit immer dieselbe Menge.
///
/// Bewusst ohne Filter: Die vollständige Liste samt Status- und
/// Fahrzeugfilter liegt im eigenen Fenster `RemindersOverviewWindow`
/// („Ansichten → Erinnerungen“).
struct RemindersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppCommands.self) private var appCommands

    /// Nur offene Erinnerungen, die dringendste zuerst. Ob eine davon schon
    /// fällig ist, hängt vom heutigen Datum ab und lässt sich deshalb nicht
    /// im Prädikat ausdrücken – das erledigt `dueReminders`.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Erinnerung.dueDate, ascending: true)],
        predicate: NSPredicate(format: "isDone == NO"),
        animation: .default
    )
    private var openReminders: FetchedResults<Erinnerung>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var isPresentingNewReminder = false
    @State private var reminderToEdit: Erinnerung?
    @State private var pendingDeletion: Erinnerung?
    @State private var errorMessage: String?

    /// Liest `dailyDueCheckTick` mit, damit die Liste – wie der Zähler in der
    /// Seitenleiste – auch ohne Klick oder Datenänderung einmal täglich neu
    /// berechnet wird (siehe dort).
    private var dueReminders: [Erinnerung] {
        _ = appCommands.dailyDueCheckTick
        return openReminders.filter(\.isDue)
    }

    var body: some View {
        Group {
            if dueReminders.isEmpty {
                VStack(spacing: 20) {
                    addButtonRow
                    Spacer()
                    ContentUnavailableView(
                        "Keine fälligen Erinnerungen",
                        systemImage: "bell",
                        description: Text("Alle Erinnerungen findest du im Menü unter „Ansichten → Erinnerungen“.")
                    )
                    Spacer()
                }
                .padding(20)
            } else {
                ScrollView {
                    GlassEffectContainer {
                        VStack(alignment: .leading, spacing: 20) {
                            addButtonRow
                            reminderListSection
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Erinnerungen")
        .sheet(isPresented: $isPresentingNewReminder) {
            ReminderFormView()
        }
        .sheet(isPresented: Binding(
            get: { reminderToEdit != nil },
            set: { if !$0 { reminderToEdit = nil } }
        )) {
            if let reminderToEdit {
                ReminderFormView(reminderToEdit: reminderToEdit)
            }
        }
        .confirmationDialog(
            "Erinnerung wirklich löschen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { reminder in
            Button("Löschen", role: .destructive) {
                viewContext.delete(reminder)
                PersistenceController.shared.save(context: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { reminder in
            Text("„\(reminder.title ?? "")“ wird unwiderruflich gelöscht.")
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }

    private var addButtonRow: some View {
        HStack {
            Spacer()

            Button {
                addReminderTapped()
            } label: {
                Label("Neue Erinnerung", systemImage: "bell.badge.plus")
            }
            .buttonStyle(.glassProminent)
            .pointerStyle(.link)
        }
    }

    private func addReminderTapped() {
        if let message = NewItemPrerequisite.missingMessage(hasVehicles: !vehicles.isEmpty) {
            errorMessage = message
            return
        }
        isPresentingNewReminder = true
    }

    private var reminderListSection: some View {
        GlassCard(title: "Fällige Erinnerungen (\(dueReminders.count))") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(dueReminders) { reminder in
                    ReminderRow(
                        reminder: reminder,
                        onEdit: { reminderToEdit = reminder },
                        onDelete: { pendingDeletion = reminder }
                    )
                    Divider()
                }
            }
        }
    }
}
