import SwiftUI
import CoreData

/// Eigenständiges Fenster mit allen Erinnerungen eines Fahrzeugs. Erreichbar
/// über den „Liste anzeigen"-Button in der Erinnerungen-Sektion der
/// Fahrzeugdetails (dort nur eingeblendet, wenn mehr als eine Erinnerung
/// vorhanden ist). Bearbeiten/Löschen jeweils per Rechtsklick auf die Zeile
/// (`ReminderRow`), Erledigt-Umschalten per Klick auf die Checkbox; neue
/// Erinnerungen legt man weiterhin in der Fahrzeugdetail-Ansicht an – analog
/// zu `NoteListWindow`, inklusive Status-Filter, einstellbarer Seitengröße
/// mit Vor/Zurück-Blättern und PDF-Export über die Werkzeuge-Menü-Taste.
struct ReminderListWindow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let vehicleRef: VehicleRef

    @FetchRequest private var reminders: FetchedResults<Erinnerung>
    @FetchRequest private var vehicles: FetchedResults<Vehicle>
    @State private var reminderToEdit: Erinnerung?
    @State private var pendingDeletion: Erinnerung?
    @State private var pdfExportErrorMessage: String?

    @State private var statusFilter: RemindersView.StatusFilter = .open
    @State private var pageSize = ReminderPageSizeStore.get()
    @State private var currentPage = 0

    init(vehicleRef: VehicleRef) {
        self.vehicleRef = vehicleRef
        _reminders = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Erinnerung.dueDate, ascending: true)],
            predicate: NSPredicate(format: "vehicle.id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
        _vehicles = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "id == %@", vehicleRef.id as NSUUID)
        )
    }

    private var vehicle: Vehicle? { vehicles.first }

    private var filteredReminders: [Erinnerung] {
        switch statusFilter {
        case .all: return Array(reminders)
        case .open: return reminders.filter { !$0.isDone }
        case .done: return reminders.filter(\.isDone)
        }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredReminders.count) / Double(pageSize))))
    }

    private var pagedReminders: [Erinnerung] {
        let start = currentPage * pageSize
        guard start < filteredReminders.count else { return [] }
        return Array(filteredReminders[start..<min(start + pageSize, filteredReminders.count)])
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 12) {
                    if reminders.isEmpty {
                        ContentUnavailableView(
                            "Keine Erinnerungen",
                            systemImage: "bell",
                            description: Text("Für dieses Fahrzeug sind keine Erinnerungen erfasst.")
                        )
                        .padding(.top, 60)
                    } else {
                        displayOptions

                        if filteredReminders.isEmpty {
                            Text("Keine Erinnerungen im gewählten Status.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            GlassCard(title: "Erinnerungen (\(filteredReminders.count))") {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(pagedReminders) { reminder in
                                        ReminderRow(
                                            reminder: reminder,
                                            onEdit: { reminderToEdit = reminder },
                                            onDelete: { pendingDeletion = reminder }
                                        )
                                        Divider()
                                    }
                                }
                            }

                            if totalPages > 1 {
                                PaginationControls(currentPage: $currentPage, totalPages: totalPages)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 340, minHeight: 400)
        .navigationTitle("Erinnerungen – \(vehicleRef.licensePlate)")
        .toolbar { toolbarContent }
        .sheet(isPresented: Binding(
            get: { reminderToEdit != nil },
            set: { if !$0 { reminderToEdit = nil } }
        )) {
            if let reminderToEdit {
                ReminderFormView(reminderToEdit: reminderToEdit, fixedVehicle: vehicle)
            }
        }
        .onChange(of: statusFilter) { _, _ in currentPage = 0 }
        .onChange(of: pageSize) { _, newValue in
            ReminderPageSizeStore.set(newValue)
            currentPage = 0
        }
        .onChange(of: totalPages) { _, newValue in
            currentPage = min(currentPage, newValue - 1)
        }
        .modifier(ReminderListAlertsModifier(
            pendingDeletion: $pendingDeletion,
            pdfExportErrorMessage: $pdfExportErrorMessage,
            onDelete: { reminder in
                viewContext.delete(reminder)
                PersistenceController.shared.save(context: viewContext)
            }
        ))
    }

    private func exportPDF() {
        do {
            let reportView = ReminderListPDFReportView(
                vehicleRef: vehicleRef,
                reminders: filteredReminders
            )
            let url = try ReportPDFGenerator.generate(
                reportView,
                sections: reportView.sections,
                filenamePrefix: "Erinnerungen_\(vehicleRef.licensePlate)"
            )
            Task {
                do {
                    try await ReportPDFGenerator.openInPreview(url)
                } catch {
                    pdfExportErrorMessage = error.localizedDescription
                }
            }
        } catch {
            pdfExportErrorMessage = error.localizedDescription
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button("PDF-Export") { exportPDF() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .pointerStyle(.link)
            .help("Weitere Aktionen")
        }
    }

    private var displayOptions: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Status")
                    Spacer()
                    Picker("Status", selection: $statusFilter) {
                        ForEach(RemindersView.StatusFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                Divider()

                HStack {
                    Text("Einträge pro Seite")
                    Spacer()
                    Stepper("\(pageSize)", value: $pageSize, in: 5...15)
                        .fixedSize()
                }
            }
        }
    }
}

/// Bündelt Lösch-Bestätigung und PDF-Fehler-Alert in einem eigenen
/// `ViewModifier` – hält `body` schlank genug für den Type-Checker (sonst
/// „unable to type-check this expression in reasonable time", siehe
/// `NoteListAlertsModifier` in `NoteListWindow.swift` für dasselbe Muster).
private struct ReminderListAlertsModifier: ViewModifier {
    @Binding var pendingDeletion: Erinnerung?
    @Binding var pdfExportErrorMessage: String?
    let onDelete: (Erinnerung) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Erinnerung wirklich löschen?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { reminder in
                Button("Löschen", role: .destructive) { onDelete(reminder) }
                Button("Abbrechen", role: .cancel) { }
            } message: { reminder in
                Text("„\(reminder.title ?? "")“ wird unwiderruflich gelöscht.")
            }
            .alert(
                "PDF-Erstellung fehlgeschlagen",
                isPresented: Binding(
                    get: { pdfExportErrorMessage != nil },
                    set: { if !$0 { pdfExportErrorMessage = nil } }
                ),
                presenting: pdfExportErrorMessage
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
    }
}
