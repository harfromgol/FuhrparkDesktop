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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "Keine Ausgaben",
                        systemImage: "eurosign.circle",
                        description: Text("Für dieses Fahrzeug sind noch keine sonstigen Ausgaben erfasst.")
                    )
                    .padding(.top, 60)
                } else {
                    if !categories.isEmpty {
                        filterSection
                    }

                    if filteredExpenses.isEmpty {
                        Text("Keine Ausgaben in den gewählten Kategorien.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, 24)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(filteredExpenses) { expense in
                            ExpenseRow(expense: expense)
                                .contextMenu {
                                    Button("Löschen", role: .destructive) {
                                        pendingDeletion = expense
                                    }
                                }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 340, minHeight: 400)
        .navigationTitle("Sonstige Ausgaben – \(vehicleRef.licensePlate)")
        .confirmationDialog(
            "Ausgabe löschen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { expense in
            Button("Löschen", role: .destructive) {
                viewContext.delete(expense)
                PersistenceController.shared.save(context: viewContext)
            }
            Button("Abbrechen", role: .cancel) { }
        }
    }

    private var filterSection: some View {
        GlassCard(title: "Nach Kategorie filtern") {
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
