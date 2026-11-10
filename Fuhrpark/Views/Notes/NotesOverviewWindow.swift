import SwiftUI
import CoreData

/// Eigenständiges Fenster mit der fahrzeugübergreifenden Liste aller
/// Notizen, geöffnet über das Menü „Ansichten → Notizen“ (siehe
/// `AppMenuCommands`). Filter nach Fahrzeugstatus, Fahrzeug und Zeitraum –
/// aufgebaut wie `DocumentsOverviewWindow`s Filterkaskade, nur ohne die dortige
/// Kategorie-Stufe (Notizen kennen keine Kategorien).
///
/// Die Filter werden in `NotesOverviewFilterStore` gespeichert und beim
/// Öffnen wieder eingelesen – das Fenster wird bei jedem Öffnen neu erzeugt
/// (sein `@State` ginge sonst beim Schließen verloren), soll aber wie auch
/// nach einem Neustart genau dort weitermachen, wo man aufgehört hat.
/// Position und Größe des Fensters merkt sich `persistWindowFrame` an der
/// Szene.
struct NotesOverviewWindow: View {
    /// Feste ID der `Window`-Szene – zugleich der Schlüssel, unter dem
    /// Position und Größe des Fensters gespeichert werden.
    static let windowID = "notes-overview"

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
    @State private var statusFilter = NotesOverviewFilterStore.getStatusFilter()
    @State private var isDateFilterActive = NotesOverviewFilterStore.getIsDateFilterActive()
    @State private var dateFrom = NotesOverviewFilterStore.getDateRange()?.from ?? Date()
    @State private var dateTo = NotesOverviewFilterStore.getDateRange()?.to ?? Date()
    @State private var isPresentingFilterPopover = false
    /// `selectedVehicleFilter` selbst kann erst nach dem ersten Erscheinen
    /// aus der gespeicherten Fahrzeug-ID aufgelöst werden, da `vehicles`
    /// (der `@FetchRequest`) zum Zeitpunkt der `@State`-Initialisierung noch
    /// nicht befüllt ist – siehe `.onAppear` unten, analog zu
    /// `FuelEntriesOverviewWindow.didRestoreVehicleFilter`.
    @State private var didRestoreVehicleFilter = false

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
        .frame(minWidth: 420, minHeight: 360)
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
        .onAppear {
            guard !didRestoreVehicleFilter else { return }
            didRestoreVehicleFilter = true
            if let id = NotesOverviewFilterStore.getSelectedVehicleID() {
                selectedVehicleFilter = vehicles.first { $0.id == id }
            }
        }
        .onChange(of: statusFilter) { _, newValue in
            NotesOverviewFilterStore.setStatusFilter(newValue)
            if let selectedVehicleFilter, !vehiclesMatchingStatus.contains(selectedVehicleFilter) {
                self.selectedVehicleFilter = nil
            }
        }
        .onChange(of: selectedVehicleFilter) { _, newValue in
            NotesOverviewFilterStore.setSelectedVehicleID(newValue?.id)
        }
        .onChange(of: isDateFilterActive) { _, newValue in
            NotesOverviewFilterStore.setIsDateFilterActive(newValue)
            // Auch der unverändert übernommene Vorgabezeitraum (heute) gehört
            // zum gewählten Filter – sonst stünde nach dem erneuten Öffnen an
            // einem anderen Tag ein anderer Zeitraum da.
            if newValue {
                NotesOverviewFilterStore.setDateRange(from: dateFrom, to: dateTo)
            }
        }
        .onChange(of: dateFrom) { _, newValue in
            NotesOverviewFilterStore.setDateRange(from: newValue, to: dateTo)
        }
        .onChange(of: dateTo) { _, newValue in
            NotesOverviewFilterStore.setDateRange(from: dateFrom, to: newValue)
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
