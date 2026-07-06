import SwiftUI

/// Zeilendarstellung einer einzelnen sonstigen Ausgabe.
struct ExpenseRow: View {
    @ObservedObject var expense: Expense

    var body: some View {
        GlassCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(FieldValidator.string(from: expense.date ?? Date()))
                        .font(.subheadline.bold())
                    Text(expense.recipient ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(expense.purpose ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(DisplayFormatter.currencyString(expense.amount?.decimalValue ?? 0))
                        .font(.subheadline.bold())
                    Text(expense.categoryName.isEmpty ? "–" : expense.categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
