import SwiftUI
import CoreData

/// Eigenständiges Fenster mit allen sonstigen Ausgaben eines Fahrzeugs.
struct ExpenseListWindow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let vehicleRef: VehicleRef

    @FetchRequest private var expenses: FetchedResults<Expense>
    @State private var pendingDeletion: Expense?

    init(vehicleRef: VehicleRef) {
        self.vehicleRef = vehicleRef
        _expenses = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
            predicate: NSPredicate(format: "vehicle.id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
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
                    ForEach(expenses) { expense in
                        ExpenseRow(expense: expense)
                            .contextMenu {
                                Button("Löschen", role: .destructive) {
                                    pendingDeletion = expense
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
}
