import SwiftUI

/// Zweiter Schritt beim Anlegen eines Dokuments: erst Fahrzeug, dann die
/// zugehörige sonstige Ausgabe auswählen. Die Datei selbst wurde bereits
/// über den Datei-öffnen-Dialog gewählt (siehe `DocumentsView`).
struct NewDocumentAssignmentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let path: String
    let bookmarkData: Data
    let onSaved: () -> Void

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var selectedVehicle: Vehicle?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GlassEffectContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassCard(title: "Datei") {
                            Text((path as NSString).lastPathComponent)
                                .font(.headline)
                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        GlassCard(title: "Fahrzeug") {
                            Picker("Fahrzeug", selection: $selectedVehicle) {
                                Text("Bitte wählen").tag(Vehicle?.none)
                                ForEach(vehicles) { vehicle in
                                    Text(vehicle.licensePlate ?? "").tag(Vehicle?.some(vehicle))
                                }
                            }
                            .labelsHidden()
                        }

                        if let selectedVehicle {
                            ExpensePickerSection(
                                vehicle: selectedVehicle,
                                path: path,
                                bookmarkData: bookmarkData,
                                onSaved: onSaved
                            )
                        }
                    }
                    .padding(20)
                }
            }

            Divider()

            HStack {
                Button("Abbrechen", role: .cancel) { onSaved() }
                    .pointerStyle(.link)
                Spacer()
            }
            .padding(16)
        }
        .frame(width: 460, height: 620)
    }
}

/// Liste der sonstigen Ausgaben eines Fahrzeugs zum Auswählen; Klick auf eine
/// Zeile legt sofort das Dokument an (analog zum bestehenden Button-statt-
/// List-Selektionsmuster in diesem Projekt).
private struct ExpensePickerSection: View {
    @Environment(\.managedObjectContext) private var viewContext

    let path: String
    let bookmarkData: Data
    let onSaved: () -> Void

    @FetchRequest private var expenses: FetchedResults<Expense>

    init(vehicle: Vehicle, path: String, bookmarkData: Data, onSaved: @escaping () -> Void) {
        self.path = path
        self.bookmarkData = bookmarkData
        self.onSaved = onSaved
        _expenses = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
            predicate: NSPredicate(format: "vehicle == %@", vehicle),
            animation: .default
        )
    }

    var body: some View {
        GlassCard(title: "Sonstige Ausgabe") {
            if expenses.isEmpty {
                Text("Für dieses Fahrzeug sind noch keine sonstigen Ausgaben erfasst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(expenses) { expense in
                        Button {
                            assign(to: expense)
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.recipient ?? "")
                                        .font(.subheadline.bold())
                                    Text(expense.purpose ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !expense.categoriesDisplay.isEmpty {
                                        Text(expense.categoriesDisplay)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(DisplayFormatter.costString(expense.signedAmount))
                                        .font(.subheadline)
                                    if let date = expense.date {
                                        Text(FieldValidator.string(from: date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        Divider()
                    }
                }
            }
        }
    }

    private func assign(to expense: Expense) {
        let document = Dokument(context: viewContext)
        document.id = UUID()
        document.path = path
        document.bookmarkData = bookmarkData
        document.createdAt = Date()
        document.expense = expense
        PersistenceController.shared.save(context: viewContext)
        onSaved()
    }
}
