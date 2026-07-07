import SwiftUI

struct ExpenseFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    /// Nur die Kategorien dieses Fahrzeugs (siehe `init`).
    @FetchRequest private var categories: FetchedResults<Category>

    @State private var dateText = FieldValidator.string(from: Date())
    @State private var amountText = ""
    @State private var recipient = ""
    @State private var purpose = ""
    @State private var selectedCategory: Category?
    @State private var newCategoryName = ""

    @State private var dateValid = false
    @State private var amountValid = false
    @State private var recipientValid = false
    @State private var purposeValid = false

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _categories = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
            predicate: NSPredicate(format: "vehicle == %@", vehicle),
            animation: .default
        )
    }

    private var isFormValid: Bool {
        dateValid && amountValid && recipientValid && purposeValid
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard(title: "Fahrzeug") {
                        Text(vehicle.licensePlate ?? "")
                            .font(.title3.bold())
                        Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    GlassCard(title: "Ausgabe") {
                        DateValidatedField(title: "Datum", text: $dateText, isValidBinding: $dateValid)
                        ValidatedField(
                            title: "Betrag (€)",
                            text: $amountText,
                            kind: .decimal(fractionDigits: 2, minLength: 4, maxLength: 8),
                            isValidBinding: $amountValid
                        )
                        ValidatedField(
                            title: "Empfänger",
                            text: $recipient,
                            kind: .text(min: 1, max: 30),
                            isValidBinding: $recipientValid
                        )
                        ValidatedField(
                            title: "Verwendungszweck",
                            text: $purpose,
                            kind: .text(min: 1, max: 30),
                            isValidBinding: $purposeValid
                        )

                        categorySection
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Abbrechen", role: .cancel) { dismiss() }
                Spacer()
                Button("Speichern") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(!isFormValid)
            }
            .padding(16)
        }
        .frame(width: 440, height: 700)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kategorie")
                .font(.caption)
                .foregroundStyle(.secondary)

            if categories.isEmpty {
                Text("Noch keine Kategorien – lege unten eine an.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Picker("Kategorie", selection: $selectedCategory) {
                    Text("Keine").tag(Category?.none)
                    ForEach(categories) { category in
                        Text(category.name ?? "").tag(Category?.some(category))
                    }
                }
                .labelsHidden()
            }

            HStack {
                TextField("Neue Kategorie", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addCategory() }
                Button("Hinzufügen", systemImage: "plus") { addCategory() }
                    .buttonStyle(.glass)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        // Bereits vorhanden? Dann nur auswählen.
        if let existing = categories.first(where: {
            $0.name?.caseInsensitiveCompare(name) == .orderedSame
        }) {
            selectedCategory = existing
            newCategoryName = ""
            return
        }

        let category = Category(context: viewContext)
        category.id = UUID()
        category.name = name
        category.createdAt = Date()
        category.vehicle = vehicle
        PersistenceController.shared.save(context: viewContext)

        selectedCategory = category
        newCategoryName = ""
    }

    private func save() {
        let expense = Expense(context: viewContext)
        expense.id = UUID()
        expense.date = FieldValidator.dateValue(dateText) ?? Date()
        expense.amount = NSDecimalNumber(decimal: FieldValidator.decimalValue(amountText) ?? 0)
        expense.recipient = recipient
        expense.purpose = purpose
        expense.categoryRaw = selectedCategory?.name ?? ""
        expense.vehicle = vehicle

        PersistenceController.shared.save(context: viewContext)
        dismiss()
    }
}
