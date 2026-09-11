import SwiftUI
import CoreData

/// Eigenständiges Fenster mit allen Notizen eines Fahrzeugs. Erreichbar über
/// den „Liste anzeigen"-Button in der Notizen-Sektion der Fahrzeugdetails
/// (dort nur eingeblendet, wenn mehr als eine Notiz vorhanden ist).
/// Bearbeiten/Löschen jeweils per Rechtsklick auf die Zeile (`NoteRow`);
/// neue Notizen legt man weiterhin in der Fahrzeugdetail-Ansicht an. Bietet
/// wie `FuelEntryListWindow` einen Jahresfilter (nur Jahre, in denen es
/// tatsächlich eine Notiz gab; Default das Jahr der jüngsten Notiz), eine
/// einstellbare Seitengröße mit Vor/Zurück-Blättern sowie PDF-Export.
struct NoteListWindow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let vehicleRef: VehicleRef

    @FetchRequest private var notizen: FetchedResults<Notiz>
    @FetchRequest private var vehicles: FetchedResults<Vehicle>
    @State private var noteToEdit: Notiz?
    @State private var pendingDeletion: Notiz?

    /// `nil` steht für „Alle Jahre". Wird einmalig beim ersten Erscheinen auf
    /// `latestYear` gesetzt (siehe `didSetDefaultYear`) – Nutzerwahl bleibt
    /// danach unangetastet, bis das gewählte Jahr keine Einträge mehr hat.
    @State private var selectedYear: Int?
    @State private var didSetDefaultYear = false
    @State private var pageSize = NotePageSizeStore.get()
    @State private var currentPage = 0
    @State private var pdfExportErrorMessage: String?

    init(vehicleRef: VehicleRef) {
        self.vehicleRef = vehicleRef
        _notizen = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Notiz.date, ascending: false)],
            predicate: NSPredicate(format: "vehicle.id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
        _vehicles = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "id == %@", vehicleRef.id as NSUUID)
        )
    }

    private var vehicle: Vehicle? { vehicles.first }

    /// Jahre mit mindestens einer Notiz, absteigend sortiert.
    private var availableYears: [Int] {
        Set(notizen.map { Calendar.current.component(.year, from: $0.date ?? Date()) })
            .sorted(by: >)
    }

    /// Jahr der jüngsten Notiz – Default für den Filter.
    private var latestYear: Int? {
        guard let latestDate = notizen.compactMap(\.date).max() else { return nil }
        return Calendar.current.component(.year, from: latestDate)
    }

    private var filteredNotizen: [Notiz] {
        guard let selectedYear else { return Array(notizen) }
        return notizen.filter { Calendar.current.component(.year, from: $0.date ?? Date()) == selectedYear }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredNotizen.count) / Double(pageSize))))
    }

    private var pagedNotizen: [Notiz] {
        let start = currentPage * pageSize
        guard start < filteredNotizen.count else { return [] }
        return Array(filteredNotizen[start..<min(start + pageSize, filteredNotizen.count)])
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 12) {
                    if notizen.isEmpty {
                        ContentUnavailableView(
                            "Keine Notizen",
                            systemImage: "note.text",
                            description: Text("Für dieses Fahrzeug sind keine Notizen erfasst.")
                        )
                        .padding(.top, 60)
                    } else {
                        displayOptions

                        if filteredNotizen.isEmpty {
                            Text("Keine Notizen im gewählten Jahr.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            GlassCard(title: "Notizen (\(filteredNotizen.count))") {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(pagedNotizen) { notiz in
                                        NoteRow(
                                            notiz: notiz,
                                            onEdit: { noteToEdit = notiz },
                                            onDelete: { pendingDeletion = notiz }
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
        .navigationTitle("Notizen – \(vehicleRef.licensePlate)")
        .toolbar { toolbarContent }
        .sheet(isPresented: Binding(
            get: { noteToEdit != nil },
            set: { if !$0 { noteToEdit = nil } }
        )) {
            if let noteToEdit {
                NoteFormView(notizToEdit: noteToEdit, fixedVehicle: vehicle)
            }
        }
        .onAppear {
            guard !didSetDefaultYear else { return }
            didSetDefaultYear = true
            selectedYear = latestYear
        }
        .onChange(of: availableYears) { _, years in
            if let selectedYear, !years.contains(selectedYear) {
                self.selectedYear = nil
            }
        }
        .onChange(of: selectedYear) { _, _ in currentPage = 0 }
        .onChange(of: pageSize) { _, newValue in
            NotePageSizeStore.set(newValue)
            currentPage = 0
        }
        .onChange(of: totalPages) { _, newValue in
            currentPage = min(currentPage, newValue - 1)
        }
        .modifier(NoteListAlertsModifier(
            pendingDeletion: $pendingDeletion,
            pdfExportErrorMessage: $pdfExportErrorMessage,
            onDelete: { notiz in
                viewContext.delete(notiz)
                DocumentCleanup.finishDeletion(in: viewContext)
            }
        ))
    }

    private func exportPDF() {
        do {
            let reportView = NoteListPDFReportView(
                vehicleRef: vehicleRef,
                notizen: filteredNotizen,
                selectedYear: selectedYear
            )
            let url = try ReportPDFGenerator.generate(
                reportView,
                sections: reportView.sections,
                filenamePrefix: "Notizen_\(vehicleRef.licensePlate)"
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
                    Text("Nach Jahr filtern")
                    Spacer()
                    Picker("Jahr", selection: $selectedYear) {
                        Text("Alle").tag(Int?.none)
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(Int?.some(year))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
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
/// `FuelEntryListAlertsModifier` in `FuelEntryListWindow.swift` für dasselbe
/// Muster).
private struct NoteListAlertsModifier: ViewModifier {
    @Binding var pendingDeletion: Notiz?
    @Binding var pdfExportErrorMessage: String?
    let onDelete: (Notiz) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Notiz wirklich löschen?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { notiz in
                Button("Löschen", role: .destructive) { onDelete(notiz) }
                Button("Abbrechen", role: .cancel) { }
            } message: { notiz in
                let anzahl = notiz.sortedDokumente.count
                Text(anzahl > 0
                     ? "Die Notiz wird gelöscht. \(anzahl) angehängte\(anzahl > 1 ? "" : "s") Dokument\(anzahl > 1 ? "e" : "") werden mit entfernt, sofern es an nichts anderem mehr hängt."
                     : "Die Notiz wird unwiderruflich gelöscht.")
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
