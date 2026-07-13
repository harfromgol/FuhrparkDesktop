import SwiftUI

struct ExpenseFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    /// Nur die Kategorien dieses Fahrzeugs (siehe `init`).
    @FetchRequest private var categories: FetchedResults<Category>

    /// Ausgabe (false, Standard) oder Einnahme (true).
    @State private var isIncome = false
    @State private var dateText = FieldValidator.string(from: Date())
    @State private var amountText = ""
    @State private var recipient = ""
    @State private var purpose = ""
    @State private var selectedCategories: Set<Category> = []
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
        dateValid && amountValid && recipientValid && purposeValid && !selectedCategories.isEmpty
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

                    GlassCard(title: isIncome ? "Einnahme" : "Ausgabe") {
                        DateValidatedField(title: "Datum", text: $dateText, isValidBinding: $dateValid)
                        Picker("Art", selection: $isIncome) {
                            Text("Ausgabe").tag(false)
                            Text("Einnahme").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        ValidatedField(
                            title: "Betrag (€)",
                            text: $amountText,
                            kind: .decimal(fractionDigits: 2, minLength: 4, maxLength: 8),
                            isValidBinding: $amountValid
                        )
                        ValidatedField(
                            title: isIncome ? "Zahler" : "Empfänger",
                            text: $recipient,
                            kind: .text(min: 1, max: 30),
                            isValidBinding: $recipientValid
                        )
                        ValidatedField(
                            title: isIncome ? "Grund" : "Verwendungszweck",
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
                    .pointerStyle(.link)
                Spacer()
                Button("Speichern") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(!isFormValid)
                    .pointerStyle(isFormValid ? .link : nil)
            }
            .padding(16)
        }
        .frame(width: 440, height: 700)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kategorien (mindestens eine)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if categories.isEmpty {
                Text("Noch keine Kategorien – lege unten eine an.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: 4
                ) {
                    ForEach(categories) { category in
                        Toggle(isOn: binding(for: category)) {
                            Text(category.name ?? "")
                                .lineLimit(1)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }

            HStack {
                TextField("Neue Kategorie", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addCategory() }
                Button("Hinzufügen", systemImage: "plus") { addCategory() }
                    .buttonStyle(.glass)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .pointerStyle(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : .link)
            }
        }
    }

    /// Ein-/Ausschalten einer Kategorie in der Mehrfachauswahl.
    private func binding(for category: Category) -> Binding<Bool> {
        Binding(
            get: { selectedCategories.contains(category) },
            set: { isOn in
                if isOn {
                    selectedCategories.insert(category)
                } else {
                    selectedCategories.remove(category)
                }
            }
        )
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        // Bereits vorhanden? Dann nur (zusätzlich) auswählen.
        if let existing = categories.first(where: {
            $0.name?.caseInsensitiveCompare(name) == .orderedSame
        }) {
            selectedCategories.insert(existing)
            newCategoryName = ""
            return
        }

        let category = Category(context: viewContext)
        category.id = UUID()
        category.name = name
        category.createdAt = Date()
        category.vehicle = vehicle
        PersistenceController.shared.save(context: viewContext)

        selectedCategories.insert(category)
        newCategoryName = ""
    }

    private func save() {
        let expense = Expense(context: viewContext)
        expense.id = UUID()
        expense.isIncome = isIncome
        expense.date = FieldValidator.dateValue(dateText) ?? Date()
        expense.amount = NSDecimalNumber(decimal: FieldValidator.decimalValue(amountText) ?? 0)
        expense.recipient = recipient
        expense.purpose = purpose
        expense.categories = NSSet(array: Array(selectedCategories))
        expense.vehicle = vehicle

        vehicle.touch()
        PersistenceController.shared.save(context: viewContext)
        dismiss()
    }
}
