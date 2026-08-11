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
                            pagination
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 340, minHeight: 400)
        .navigationTitle("\(vehicleRef.engineType.refuelNounPlural) – \(vehicleRef.licensePlate)")
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
        .confirmationDialog(
            "\(vehicleRef.engineType.refuelNoun) löschen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { entry in
            Button("Löschen", role: .destructive) {
                viewContext.delete(entry)
                PersistenceController.shared.save(context: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        }
    }

    private var displayOptions: some View {
        GlassCard {
            HStack {
                Picker("Jahr", selection: $selectedYear) {
                    Text("Alle").tag(Int?.none)
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(Int?.some(year))
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Spacer()

                Stepper("Anzahl: \(pageSize)", value: $pageSize, in: 5...15)
                    .fixedSize()
            }
        }
    }

    private var pagination: some View {
        HStack {
            Button("Zurück", systemImage: "chevron.left") {
                currentPage -= 1
            }
            .buttonStyle(.glass)
            .disabled(currentPage == 0)
            .pointerStyle(currentPage == 0 ? nil : .link)

            Spacer()

            Text("Seite \(currentPage + 1) von \(totalPages)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Weiter", systemImage: "chevron.right") {
                currentPage += 1
            }
            .buttonStyle(.glass)
            .disabled(currentPage >= totalPages - 1)
            .pointerStyle(currentPage >= totalPages - 1 ? nil : .link)
        }
        .frame(maxWidth: .infinity)
    }
}
