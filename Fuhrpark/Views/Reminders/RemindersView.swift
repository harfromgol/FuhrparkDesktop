import SwiftUI
import CoreData

/// Fahrzeugübergreifende Liste aller Erinnerungen, mit Filter nach Kennzeichen
/// (Mehrfachauswahl) und Status. Die Filter liegen hinter einem
/// Filter-Icon-Button mit Popover statt fest sichtbarer Karten – analog zu
/// `NotesView`/`DocumentsView` (siehe `RemindersFilterPopover`).
struct RemindersView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Erinnerung.dueDate, ascending: true)],
        animation: .default
    )
    private var reminders: FetchedResults<Erinnerung>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var isPresentingNewReminder = false
    @State private var reminderToEdit: Erinnerung?
    @State private var pendingDeletion: Erinnerung?
    @State private var errorMessage: String?

    @State private var selectedVehicleFilter: Set<Vehicle> = []
    @State private var statusFilter: StatusFilter = .open
    @State private var isPresentingFilterPopover = false

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case open = "Offen"
        case done = "Erledigt"
        var id: String { rawValue }
    }

    private var isAnyFilterActive: Bool {
        statusFilter != .all || !selectedVehicleFilter.isEmpty
    }

    private var filteredReminders: [Erinnerung] {
        reminders.filter { reminder in
            let vehicleMatch = selectedVehicleFilter.isEmpty
                || reminder.vehicle.map(selectedVehicleFilter.contains) == true
            let statusMatch: Bool
            switch statusFilter {
            case .all: statusMatch = true
            case .open: statusMatch = !reminder.isDone
            case .done: statusMatch = reminder.isDone
            }
            return vehicleMatch && statusMatch
        }
    }

    var body: some View {
        Group {
            if reminders.isEmpty {
                VStack(spacing: 20) {
                    addButtonRow
                    Spacer()
                    ContentUnavailableView(
                        "Keine Erinnerungen",
                        systemImage: "bell",
                        description: Text("Lege über „Neue Erinnerung“ z. B. eine TÜV- oder Versicherungs-Erinnerung an.")
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
            Button {
                isPresentingFilterPopover = true
            } label: {
                Image(systemName: isAnyFilterActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderless)
            .pointerStyle(.link)
            .help("Erinnerungen filtern")
            .popover(isPresented: $isPresentingFilterPopover) {
                RemindersFilterPopover(
                    statusFilter: $statusFilter,
                    selectedVehicleFilter: $selectedVehicleFilter,
                    availableVehicles: Array(vehicles)
                )
            }

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
        GlassCard(title: "Erinnerungen (\(filteredReminders.count))") {
            if filteredReminders.isEmpty {
                Text("Keine Erinnerungen für die gewählten Filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredReminders) { reminder in
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
}
