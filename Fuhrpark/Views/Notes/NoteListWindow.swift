import SwiftUI
import CoreData

/// Eigenständiges Fenster mit allen Notizen eines Fahrzeugs. Erreichbar über
/// den „Liste anzeigen"-Button in der Notizen-Sektion der Fahrzeugdetails
/// (dort nur eingeblendet, wenn mehr als eine Notiz vorhanden ist).
/// Bearbeiten/Löschen jeweils per Rechtsklick auf die Zeile (`NoteRow`);
/// neue Notizen legt man weiterhin in der Fahrzeugdetail-Ansicht an – analog
/// zu `ExpenseListWindow`/`FuelEntryListWindow`.
struct NoteListWindow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let vehicleRef: VehicleRef

    @FetchRequest private var notizen: FetchedResults<Notiz>
    @FetchRequest private var vehicles: FetchedResults<Vehicle>
    @State private var noteToEdit: Notiz?
    @State private var pendingDeletion: Notiz?

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
                        GlassCard(title: "Notizen (\(notizen.count))") {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(notizen) { notiz in
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
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 340, minHeight: 400)
        .navigationTitle("Notizen – \(vehicleRef.licensePlate)")
        .sheet(isPresented: Binding(
            get: { noteToEdit != nil },
            set: { if !$0 { noteToEdit = nil } }
        )) {
            if let noteToEdit {
                NoteFormView(notizToEdit: noteToEdit, fixedVehicle: vehicle)
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
    }
}
