import SwiftUI
import CoreData

/// Eigenständiges Fenster mit der fahrzeugübergreifenden Liste aller
/// Erinnerungen, geöffnet über das Menü „Ansichten → Erinnerungen“ (siehe
/// `AppMenuCommands`). Filter nach Status und Fahrzeug liegen hinter einem
/// Filter-Icon-Button mit Popover – analog zu `NotesOverviewWindow`,
/// inklusive derselben Einfachauswahl für das Fahrzeug (siehe
/// `RemindersFilterPopover`).
///
/// Die Filter werden in `RemindersOverviewFilterStore` gespeichert und beim
/// Öffnen wieder eingelesen – das Fenster wird bei jedem Öffnen neu erzeugt
/// (sein `@State` ginge sonst beim Schließen verloren), soll aber wie auch
/// nach einem Neustart genau dort weitermachen, wo man aufgehört hat.
/// Position und Größe des Fensters merkt sich `persistWindowFrame` an der
/// Szene.
///
/// Nur die fälligen Erinnerungen zeigt daneben `RemindersView` unter
/// „Allgemein → Erinnerungen“ im Hauptfenster.
struct RemindersOverviewWindow: View {
    /// Feste ID der `Window`-Szene – zugleich der Schlüssel, unter dem
    /// Position und Größe des Fensters gespeichert werden.
    static let windowID = "reminders-overview"

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

    @State private var selectedVehicleFilter: Vehicle?
    @State private var statusFilter = RemindersOverviewFilterStore.getStatusFilter()
    @State private var isPresentingFilterPopover = false
    /// `selectedVehicleFilter` selbst kann erst nach dem ersten Erscheinen
    /// aus der gespeicherten Fahrzeug-ID aufgelöst werden, da `vehicles`
    /// (der `@FetchRequest`) zum Zeitpunkt der `@State`-Initialisierung noch
    /// nicht befüllt ist – siehe `.onAppear` unten, analog zu
    /// `NotesOverviewWindow.didRestoreVehicleFilter`.
    @State private var didRestoreVehicleFilter = false

    private var isAnyFilterActive: Bool {
        statusFilter != .all || selectedVehicleFilter != nil
    }

    private var filteredReminders: [Erinnerung] {
        reminders.filter { reminder in
            let vehicleMatch = selectedVehicleFilter == nil || reminder.vehicle == selectedVehicleFilter
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
        .frame(minWidth: 420, minHeight: 360)
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
        .onAppear {
            guard !didRestoreVehicleFilter else { return }
            didRestoreVehicleFilter = true
            if let id = RemindersOverviewFilterStore.getSelectedVehicleID() {
                selectedVehicleFilter = vehicles.first { $0.id == id }
            }
        }
        .onChange(of: statusFilter) { _, newValue in
            RemindersOverviewFilterStore.setStatusFilter(newValue)
        }
        .onChange(of: selectedVehicleFilter) { _, newValue in
            RemindersOverviewFilterStore.setSelectedVehicleID(newValue?.id)
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
