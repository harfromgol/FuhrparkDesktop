import SwiftUI

/// Ein Textfeld mit Live-Validierung: grüner Rahmen bei gültigem Wert,
/// roter Rahmen bei ungültigem Wert, neutraler Rahmen solange leer.
struct ValidatedField: View {
    let title: String
    @Binding var text: String
    let kind: FieldKind
    var placeholder: String = ""
    var isValidBinding: Binding<Bool>? = nil
    var extraValidation: ((String) -> Bool)? = nil
    var extraErrorMessage: String? = nil
    var accessory: AnyView? = nil

    private var isValid: Bool {
        FieldValidator.isValid(text, kind: kind) && (extraValidation?(text) ?? true)
    }

    private var borderColor: Color {
        if text.isEmpty { return Color.secondary.opacity(0.35) }
        return isValid ? .green : .red
    }

    private var hint: String? {
        switch kind {
        case .text(let min, let max):
            return "\(min)–\(max) Zeichen"
        case .licensePlate:
            return "z. B. KA-FD 123"
        case .integer(let minDigits, let maxDigits):
            return "\(minDigits)–\(maxDigits) Ziffern"
        case .decimal(let fractionDigits, _, _):
            return "mit \(fractionDigits) Nachkommastellen, z. B. 12,\(String(repeating: "3", count: fractionDigits))"
        case .date:
            return "TT.MM.JJJJ"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
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

                accessory
            }

            if !text.isEmpty, FieldValidator.isValid(text, kind: kind), !isValid, let extraErrorMessage {
                Text(extraErrorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            isValidBinding?.wrappedValue = isValid
        }
    }
}
