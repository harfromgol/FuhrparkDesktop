import SwiftUI
import CoreData

/// Fahrzeugübergreifende Liste aller Notizen, mit Filter nach Fahrzeugstatus,
/// Fahrzeug und Zeitraum – aufgebaut wie `DocumentsView`s Filterkaskade, nur
/// ohne die dortige Kategorie-Stufe (Notizen kennen keine Kategorien).
struct NotesView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Notiz.date, ascending: false)],
        animation: .default
    )
    private var notizen: FetchedResults<Notiz>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var isPresentingNewNote = false
    @State private var noteToEdit: Notiz?
    @State private var pendingDeletion: Notiz?
    @State private var errorMessage: String?

    @State private var selectedVehicleFilter: Vehicle?
    @State private var statusFilter: FahrzeugStatusFilter = .alle
    @State private var isDateFilterActive = false
    @State private var dateFrom = Date()
    @State private var dateTo = Date()
    @State private var isPresentingFilterPopover = false

    /// Fahrzeuge, die zum gewählten Fahrzeugstatus passen – Grundlage der
    /// Fahrzeugauswahl im Filter-Popover.
    private var vehiclesMatchingStatus: [Vehicle] {
        switch statusFilter {
        case .alle: Array(vehicles)
        case .aktiv: vehicles.filter { !$0.decommissioned }
        case .stillgelegt: vehicles.filter { $0.decommissioned }
        }
    }

    /// Aktiver Zeitraum als geschlossener Bereich über volle Tage, oder
    /// `nil`, solange die Eingrenzung ausgeschaltet ist.
    private var dateRange: ClosedRange<Date>? {
        guard isDateFilterActive else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dateFrom)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: dateTo)) ?? dateTo
        return start...end
    }

    private var filteredNotes: [Notiz] {
        notizen.filter { notiz in
            let statusMatch: Bool = {
                guard statusFilter != .alle else { return true }
                guard let vehicle = notiz.vehicle else { return false }
                return statusFilter == .aktiv ? !vehicle.decommissioned : vehicle.decommissioned
            }()
            let vehicleMatch = selectedVehicleFilter == nil || notiz.vehicle == selectedVehicleFilter
            let dateMatch = dateRange.map { $0.contains(notiz.date ?? .distantPast) } ?? true
            return statusMatch && vehicleMatch && dateMatch
        }
    }

    private var isAnyFilterActive: Bool {
        statusFilter != .alle || selectedVehicleFilter != nil || isDateFilterActive
    }

    var body: some View {
        Group {
            if notizen.isEmpty {
                VStack(spacing: 20) {
                    addButtonRow
                    Spacer()
                    ContentUnavailableView(
                        "Keine Notizen",
                        systemImage: "note.text",
                        description: Text("Lege über „Neue Notiz“ eine Notiz zu einem Fahrzeug an.")
                    )
                    Spacer()
                }
                .padding(20)
            } else {
                ScrollView {
                    GlassEffectContainer {
                        VStack(alignment: .leading, spacing: 20) {
                            addButtonRow
                            noteListSection
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Notizen")
        .sheet(isPresented: $isPresentingNewNote) {
            NoteFormView()
        }
        .sheet(isPresented: Binding(
            get: { noteToEdit != nil },
            set: { if !$0 { noteToEdit = nil } }
        )) {
            if let noteToEdit {
                NoteFormView(notizToEdit: noteToEdit)
            }
        }
        .confirmationDialog(
            "Notiz wirklich löschen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { notiz in
            Button("Löschen", role: .destructive) {
                viewContext.delete(notiz)
                DocumentCleanup.finishDeletion(in: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { notiz in
            let anzahl = notiz.sortedDokumente.count
            Text(anzahl > 0
                 ? "Die Notiz wird gelöscht. \(anzahl) angehängte\(anzahl > 1 ? "" : "s") Dokument\(anzahl > 1 ? "e" : "") werden mit entfernt, sofern es an nichts anderem mehr hängt."
                 : "Die Notiz wird unwiderruflich gelöscht.")
        }
        .onChange(of: statusFilter) { _, _ in
            if let selectedVehicleFilter, !vehiclesMatchingStatus.contains(selectedVehicleFilter) {
                self.selectedVehicleFilter = nil
            }
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
            .help("Notizen filtern")
            .popover(isPresented: $isPresentingFilterPopover) {
                NotesFilterPopover(
                    statusFilter: $statusFilter,
                    selectedVehicleFilter: $selectedVehicleFilter,
                    isDateFilterActive: $isDateFilterActive,
                    dateFrom: $dateFrom,
                    dateTo: $dateTo,
                    availableVehicles: vehiclesMatchingStatus
                )
            }

            Spacer()

            Button {
                addNoteTapped()
            } label: {
                Label("Neue Notiz", systemImage: "note.text.badge.plus")
            }
            .buttonStyle(.glassProminent)
            .pointerStyle(.link)
        }
    }

    private func addNoteTapped() {
        if let message = NewItemPrerequisite.missingMessage(hasVehicles: !vehicles.isEmpty) {
            errorMessage = message
            return
        }
        isPresentingNewNote = true
    }

    private var noteListSection: some View {
        GlassCard(title: "Notizen (\(filteredNotes.count))") {
            if filteredNotes.isEmpty {
                Text("Keine Notizen für die gewählten Filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredNotes) { notiz in
                        NoteRow(
                            notiz: notiz,
                            onEdit: { noteToEdit = notiz },
                            onDelete: { pendingDeletion = notiz }
                        )
                        Divider()
                    }
                }
            }
        }
    }
}
