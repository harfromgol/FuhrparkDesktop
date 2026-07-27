import SwiftUI
import CoreData

/// Fahrzeugübergreifende Liste aller Erinnerungen, mit Filter nach Kennzeichen
/// (Mehrfachauswahl) und Status. Aufbau angelehnt an `DocumentsView`.
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

    @State private var selectedVehicleFilter: Set<Vehicle> = []
    @State private var statusFilter: StatusFilter = .open

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case open = "Offen"
        case done = "Erledigt"
        var id: String { rawValue }
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
                            if !vehicles.isEmpty {
                                vehicleFilterSection
                            }
                            statusFilterSection
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
    }

    private var addButtonRow: some View {
        HStack {
            Spacer()
            Button {
                isPresentingNewReminder = true
            } label: {
                Label("Neue Erinnerung", systemImage: "bell.badge.plus")
            }
            .buttonStyle(.glassProminent)
            .pointerStyle(.link)
        }
    }

    private var vehicleFilterSection: some View {
        GlassCard(title: "Nach Kennzeichen filtern") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                filterChip(title: "Alle", selected: selectedVehicleFilter.isEmpty) {
                    selectedVehicleFilter.removeAll()
                }
                ForEach(vehicles) { vehicle in
                    filterChip(
                        title: vehicle.licensePlate ?? "",
                        selected: selectedVehicleFilter.contains(vehicle)
                    ) {
                        if selectedVehicleFilter.contains(vehicle) {
                            selectedVehicleFilter.remove(vehicle)
                        } else {
                            selectedVehicleFilter.insert(vehicle)
                        }
                    }
                }
            }
        }
    }

    private var statusFilterSection: some View {
        GlassCard(title: "Status") {
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    selected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
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
