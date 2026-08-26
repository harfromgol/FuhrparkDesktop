import SwiftUI

/// Mehrzeiliges Pendant zu `ValidatedField`: gleicher grün/rot/neutraler
/// Rahmen, aber ein `TextEditor` statt eines einzeiligen `TextField` – für
/// frei formulierten Text mit Zeilenumbrüchen (z. B. Notizen).
struct ValidatedTextEditor: View {
    let title: String
    @Binding var text: String
    let kind: FieldKind
    var placeholder: String = ""
    var isValidBinding: Binding<Bool>? = nil
    var height: CGFloat = 100

    private var isValid: Bool {
        FieldValidator.isValid(text, kind: kind)
    }

    private var borderColor: Color {
        if text.isEmpty { return Color.secondary.opacity(0.35) }
        return isValid ? .green : .red
    }

    private var maxLength: Int {
        if case .text(_, let max) = kind { return max }
        return Int.max
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty, !placeholder.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .frame(height: height)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
            .onChange(of: text) { _, newValue in
                let sanitized = FieldValidator.sanitize(newValue, kind: kind)
                if sanitized != newValue {
                    text = sanitized
                }
                isValidBinding?.wrappedValue = isValid
            }

            if maxLength < Int.max {
                Text("\(text.count)/\(maxLength) Zeichen")
                    .font(.caption2)
                    .foregroundStyle(text.count >= maxLength ? Color.red : Color.secondary)
            }
        }
        .onAppear {
            isValidBinding?.wrappedValue = isValid
        }
    }
}
