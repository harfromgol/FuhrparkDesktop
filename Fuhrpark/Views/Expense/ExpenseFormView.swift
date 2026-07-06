import SwiftUI

struct ExpenseFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    @State private var dateText = FieldValidator.string(from: Date())
    @State private var amountText = ""
    @State private var recipient = ""
    @State private var purpose = ""
    @State private var category: ExpenseCategory = .other

    @State private var dateValid = false
    @State private var amountValid = false
    @State private var recipientValid = false
    @State private var purposeValid = false

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

                        Picker("Kategorie", selection: $category) {
                            ForEach(ExpenseCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
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
        .frame(width: 440, height: 560)
    }

    private func save() {
        let expense = Expense(context: viewContext)
        expense.id = UUID()
        expense.date = FieldValidator.dateValue(dateText) ?? Date()
        expense.amount = NSDecimalNumber(decimal: FieldValidator.decimalValue(amountText) ?? 0)
        expense.recipient = recipient
        expense.purpose = purpose
        expense.category = category
        expense.vehicle = vehicle

        PersistenceController.shared.save(context: viewContext)
        dismiss()
    }
}
