import SwiftUI
import CoreData

/// Eigenständiges Fenster mit allen sonstigen Ausgaben eines Fahrzeugs.
struct ExpenseListWindow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let vehicleRef: VehicleRef

    @FetchRequest private var expenses: FetchedResults<Expense>
    @FetchRequest private var categories: FetchedResults<Category>
    @State private var selectedCategories: Set<Category> = []
    @State private var pendingDeletion: Expense?
    @State private var pageSize = ExpensePageSizeStore.get()
    @State private var currentPage = 0
    @State private var pdfExportErrorMessage: String?

    init(vehicleRef: VehicleRef) {
        self.vehicleRef = vehicleRef
        _expenses = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
            predicate: NSPredicate(format: "vehicle.id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
        _categories = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
            predicate: NSPredicate(format: "vehicle.id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
    }

    /// Ausgaben, gefiltert nach den gewählten Kategorien (Treffer = enthält
    /// mindestens eine der gewählten Kategorien). Leere Auswahl = alle Ausgaben.
    private var filteredExpenses: [Expense] {
        guard !selectedCategories.isEmpty else { return Array(expenses) }
        return expenses.filter { expense in
            let expenseCategories = (expense.categories as? Set<Category>) ?? []
            return !expenseCategories.isDisjoint(with: selectedCategories)
        }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredExpenses.count) / Double(pageSize))))
    }

    private var pagedExpenses: [Expense] {
        let start = currentPage * pageSize
        guard start < filteredExpenses.count else { return [] }
        return Array(filteredExpenses[start..<min(start + pageSize, filteredExpenses.count)])
    }

    /// Beschreibt den aktuellen Kategoriefilter für den PDF-Bericht – leere
    /// Auswahl heißt „alle Ausgaben", siehe `filteredExpenses`.
    private var categoryFilterLabel: String {
        guard !selectedCategories.isEmpty else { return "Alle Kategorien" }
        return selectedCategories.map { $0.name ?? "" }.sorted().joined(separator: ", ")
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 12) {
                    if expenses.isEmpty {
                        ContentUnavailableView(
                            "Keine Ausgaben",
                            systemImage: "eurosign.circle",
                            description: Text("Für dieses Fahrzeug sind noch keine sonstigen Ausgaben erfasst.")
                        )
                        .padding(.top, 60)
                    } else {
                        displayOptions

                        if filteredExpenses.isEmpty {
                            Text("Keine Ausgaben in den gewählten Kategorien.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(pagedExpenses) { expense in
                                ExpenseRow(expense: expense)
                                    .contextMenu {
                                        Button("Löschen", role: .destructive) {
                                            pendingDeletion = expense
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
        .navigationTitle("Sonstige Ausgaben – \(vehicleRef.licensePlate)")
        .toolbar { toolbarContent }
        .onChange(of: selectedCategories) { _, _ in currentPage = 0 }
        .onChange(of: pageSize) { _, newValue in
            ExpensePageSizeStore.set(newValue)
            currentPage = 0
        }
        .onChange(of: totalPages) { _, newValue in
            currentPage = min(currentPage, newValue - 1)
        }
        .modifier(ExpenseListAlertsModifier(
            pendingDeletion: $pendingDeletion,
            pdfExportErrorMessage: $pdfExportErrorMessage,
            onDelete: { expense in
                viewContext.delete(expense)
                DocumentCleanup.finishDeletion(in: viewContext)
            }
        ))
    }

    private func exportPDF() {
        do {
            let reportView = ExpenseListPDFReportView(
                vehicleRef: vehicleRef,
                expenses: filteredExpenses,
                categoryFilterLabel: categoryFilterLabel
            )
            let url = try ReportPDFGenerator.generate(
                reportView,
                sections: reportView.sections,
                filenamePrefix: "Ausgaben_\(vehicleRef.licensePlate)"
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
                if !categories.isEmpty {
                    Text("Nach Kategorie filtern")
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        filterChip(title: "Alle", selected: selectedCategories.isEmpty) {
                            selectedCategories.removeAll()
                        }
                        ForEach(categories) { category in
                            filterChip(
                                title: category.name ?? "",
                                selected: selectedCategories.contains(category)
                            ) {
                                if selectedCategories.contains(category) {
                                    selectedCategories.remove(category)
                                } else {
                                    selectedCategories.insert(category)
                                }
                            }
                        }
                    }

                    Divider()
                }

                HStack {
                    Text("Einträge pro Seite")
                    Spacer()
                    Stepper("\(pageSize)", value: $pageSize, in: 5...15)
                        .fixedSize()
                }
            }
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
}

/// Bündelt Lösch-Bestätigung und PDF-Fehler-Alert in einem eigenen
/// `ViewModifier` – hält `body` schlank genug für den Type-Checker (sonst
/// „unable to type-check this expression in reasonable time", siehe
/// `FuelEntryListAlertsModifier` in `FuelEntryListWindow.swift` für dasselbe
/// Muster).
private struct ExpenseListAlertsModifier: ViewModifier {
    @Binding var pendingDeletion: Expense?
    @Binding var pdfExportErrorMessage: String?
    let onDelete: (Expense) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Ausgabe löschen?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { expense in
                Button("Löschen", role: .destructive) { onDelete(expense) }
                Button("Abbrechen", role: .cancel) { }
            } message: { expense in
                let belege = expense.sortedDocuments.count
                Text(belege == 0
                     ? "„\(expense.recipient ?? "")“ wird unwiderruflich gelöscht."
                     : "„\(expense.recipient ?? "")“ wird unwiderruflich gelöscht. Zugeordnete Belege bleiben erhalten, solange sie noch zu einer anderen Ausgabe gehören – sonst werden sie mit entfernt.")
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
