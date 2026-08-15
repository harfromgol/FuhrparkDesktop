import SwiftUI
import CoreData

/// Eigenständiges Fenster mit allen Betankungen eines Fahrzeugs. Bietet einen
/// Jahresfilter (nur Jahre, in denen es tatsächlich eine Betankung gab;
/// Default das Jahr der chronologisch letzten Betankung) sowie eine
/// einstellbare Seitengröße mit Vor/Zurück-Blättern, da die Liste bei lange
/// genutzten Fahrzeugen sehr lang werden kann.
struct FuelEntryListWindow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let vehicleRef: VehicleRef

    @FetchRequest private var entries: FetchedResults<FuelEntry>
    @State private var pendingDeletion: FuelEntry?

    /// `nil` steht für „Alle Jahre". Wird einmalig beim ersten Erscheinen auf
    /// `latestYear` gesetzt (siehe `didSetDefaultYear`) – Nutzerwahl bleibt
    /// danach unangetastet, bis das gewählte Jahr keine Einträge mehr hat.
    @State private var selectedYear: Int?
    @State private var didSetDefaultYear = false
    @State private var pageSize = FuelEntryPageSizeStore.get()
    @State private var currentPage = 0
    @State private var pdfExportErrorMessage: String?

    init(vehicleRef: VehicleRef) {
        self.vehicleRef = vehicleRef
        _entries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.odometer, ascending: false)],
            predicate: NSPredicate(format: "vehicle.id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
    }

    /// Jahre mit mindestens einer Betankung, absteigend sortiert.
    private var availableYears: [Int] {
        Set(entries.map { Calendar.current.component(.year, from: $0.date ?? Date()) })
            .sorted(by: >)
    }

    /// Jahr der chronologisch letzten Betankung – Default für den Filter.
    private var latestYear: Int? {
        guard let latestDate = entries.compactMap(\.date).max() else { return nil }
        return Calendar.current.component(.year, from: latestDate)
    }

    private var filteredEntries: [FuelEntry] {
        guard let selectedYear else { return Array(entries) }
        return entries.filter { Calendar.current.component(.year, from: $0.date ?? Date()) == selectedYear }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredEntries.count) / Double(pageSize))))
    }

    private var pagedEntries: [FuelEntry] {
        let start = currentPage * pageSize
        guard start < filteredEntries.count else { return [] }
        return Array(filteredEntries[start..<min(start + pageSize, filteredEntries.count)])
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 12) {
                    if entries.isEmpty {
                        ContentUnavailableView(
                            "Keine \(vehicleRef.engineType.refuelNounPlural)",
                            systemImage: "fuelpump",
                            description: Text("Für dieses Fahrzeug sind noch keine \(vehicleRef.engineType.refuelNounPlural) erfasst.")
                        )
                        .padding(.top, 60)
                    } else {
                        displayOptions

                        ForEach(pagedEntries) { entry in
                            FuelEntryRow(entry: entry)
                                .contextMenu {
                                    Button("Löschen", role: .destructive) {
                                        pendingDeletion = entry
                                    }
                                }
                        }

                        if totalPages > 1 {
                            PaginationControls(currentPage: $currentPage, totalPages: totalPages)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 340, minHeight: 400)
        .navigationTitle("\(vehicleRef.engineType.refuelNounPlural) – \(vehicleRef.licensePlate)")
        .toolbar { toolbarContent }
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
            FuelEntryPageSizeStore.set(newValue)
            currentPage = 0
        }
        .onChange(of: totalPages) { _, newValue in
            currentPage = min(currentPage, newValue - 1)
        }
        .modifier(FuelEntryListAlertsModifier(
            pendingDeletion: $pendingDeletion,
            pdfExportErrorMessage: $pdfExportErrorMessage,
            refuelNoun: vehicleRef.engineType.refuelNoun,
            onDelete: { entry in
                viewContext.delete(entry)
                PersistenceController.shared.save(context: viewContext)
            }
        ))
    }

    private func exportPDF() {
        do {
            let reportView = FuelEntryListPDFReportView(
                vehicleRef: vehicleRef,
                entries: filteredEntries,
                selectedYear: selectedYear
            )
            let url = try ReportPDFGenerator.generate(
                reportView,
                sections: reportView.sections,
                filenamePrefix: "\(vehicleRef.engineType.refuelNounPlural)_\(vehicleRef.licensePlate)"
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
                Button("PDF") { exportPDF() }
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
/// `VehicleConfirmationModifier` in `SidebarView.swift` für dasselbe Muster).
private struct FuelEntryListAlertsModifier: ViewModifier {
    @Binding var pendingDeletion: FuelEntry?
    @Binding var pdfExportErrorMessage: String?
    let refuelNoun: String
    let onDelete: (FuelEntry) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "\(refuelNoun) löschen?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { entry in
                Button("Löschen", role: .destructive) { onDelete(entry) }
                Button("Abbrechen", role: .cancel) { }
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
