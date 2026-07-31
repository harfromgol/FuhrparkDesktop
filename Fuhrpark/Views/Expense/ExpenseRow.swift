import SwiftUI

/// Zeilendarstellung einer einzelnen sonstigen Ausgabe.
struct ExpenseRow: View {
    @ObservedObject var expense: Expense
    @State private var isPresentingDocuments = false
    @State private var errorMessage: String?

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
                    HStack(spacing: 6) {
                        if !expense.sortedDocuments.isEmpty {
                            Button {
                                isPresentingDocuments = true
                            } label: {
                                Image(systemName: "paperclip")
                            }
                            .buttonStyle(.borderless)
                            .pointerStyle(.link)
                            .help("\(expense.sortedDocuments.count) zugeordnete\(expense.sortedDocuments.count == 1 ? "s" : "") Dokument\(expense.sortedDocuments.count == 1 ? "" : "e")")
                            .popover(isPresented: $isPresentingDocuments) {
                                documentsPopover
                            }
                        }
                        Text((expense.isIncome ? "+" : "") + DisplayFormatter.currencyString(expense.amount?.decimalValue ?? 0))
                            .font(.subheadline.bold())
                            .foregroundStyle(expense.isIncome ? Color.green : Color.primary)
                    }
                    Text(expense.categoriesDisplay.isEmpty ? "–" : expense.categoriesDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }

    private var documentsPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dokumente")
                .font(.headline)
            ForEach(expense.sortedDocuments) { document in
                Button {
                    do {
                        try document.open()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    Label(document.filename, systemImage: "doc")
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
        }
        .padding(12)
        .frame(minWidth: 220, alignment: .leading)
    }
}
