import SwiftUI
import CoreData

/// Eigenständiges Fenster mit allen Betankungen eines Fahrzeugs.
struct FuelEntryListWindow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let vehicleRef: VehicleRef

    @FetchRequest private var entries: FetchedResults<FuelEntry>
    @State private var pendingDeletion: FuelEntry?

    init(vehicleRef: VehicleRef) {
        self.vehicleRef = vehicleRef
        _entries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.odometer, ascending: false)],
            predicate: NSPredicate(format: "vehicle.id == %@", vehicleRef.id as NSUUID),
            animation: .default
        )
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
                        ForEach(entries) { entry in
                            FuelEntryRow(entry: entry)
                                .contextMenu {
                                    Button("Löschen", role: .destructive) {
                                        pendingDeletion = entry
                                    }
                                }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 340, minHeight: 400)
        .navigationTitle("\(vehicleRef.engineType.refuelNounPlural) – \(vehicleRef.licensePlate)")
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
}
