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
    /// Optionaler Fokus-Zustand (z. B. für die Empfänger-Autovervollständigung).
    var focus: FocusState<Bool>.Binding? = nil
    /// Optionaler Tastatur-Hook direkt am Textfeld (fängt ↑/↓/Enter ab, bevor das
    /// Textfeld sie selbst verarbeitet). `.ignored` lässt normales Tippen unberührt.
    var onKeyPress: ((KeyPress) -> KeyPress.Result)? = nil

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
        case .apiKey:
            return "API-Schlüssel (UUID), z. B. 474e5046-deaf-4f9b-9a32-9797b778f047"
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
                    .modifier(OptionalFocusModifier(focus: focus))
                    .modifier(OptionalKeyPressModifier(onKeyPress: onKeyPress))

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

/// Wendet `.focused` nur an, wenn ein Fokus-Binding übergeben wurde.
private struct OptionalFocusModifier: ViewModifier {
    let focus: FocusState<Bool>.Binding?
    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}

/// Wendet `.onKeyPress` nur an, wenn ein Handler übergeben wurde.
private struct OptionalKeyPressModifier: ViewModifier {
    let onKeyPress: ((KeyPress) -> KeyPress.Result)?
    func body(content: Content) -> some View {
        if let onKeyPress {
            content.onKeyPress(action: onKeyPress)
        } else {
            content
        }
    }
}

/// Misst die Breite des Feldes, damit das Vorschlags-Popup exakt darunter passt.
private struct FieldWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Textfeld mit Autovervollständigung: zeigt beim Tippen ein schwebendes Popup
/// mit passenden Vorschlägen (nach Eingabe gefiltert). ↑/↓ markieren einen
/// Vorschlag, Enter übernimmt ihn, Escape schließt das Popup; Vorschläge sind
/// zusätzlich per Maus anklickbar.
struct SuggestingField: View {
    let title: String
    @Binding var text: String
    var isValidBinding: Binding<Bool>? = nil
    /// Bereits erfasste Empfänger (bereits distinct/sortiert vom Aufrufer).
    let suggestions: [String]

    private static let kind: FieldKind = .text(min: 1, max: 30)

    @FocusState private var isFocused: Bool
    @State private var highlighted = -1
    @State private var dismissed = false
    @State private var justAccepted = false
    @State private var fieldWidth: CGFloat = 0

    /// Nach Eingabe gefilterte Vorschläge (case-insensitiv, ohne exakten Treffer),
    /// auf maximal sechs begrenzt.
    private var matches: [String] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return suggestions
            .filter {
                $0.localizedCaseInsensitiveContains(query)
                    && $0.localizedCaseInsensitiveCompare(query) != .orderedSame
            }
            .prefix(6)
            .map { $0 }
    }

    private var showsPopup: Bool {
        isFocused && !dismissed && !matches.isEmpty
    }

    var body: some View {
        ValidatedField(
            title: title,
            text: $text,
            kind: Self.kind,
            isValidBinding: isValidBinding,
            focus: $isFocused,
            onKeyPress: handleKey
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: FieldWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(FieldWidthKey.self) { fieldWidth = $0 }
        .zIndex(1)
        .overlay(alignment: .bottomLeading) {
            if showsPopup {
                popup.alignmentGuide(.bottom) { $0[.top] }
            }
        }
        .onChange(of: text) { _, _ in
            if justAccepted {
                justAccepted = false
            } else {
                dismissed = false
                highlighted = -1
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { dismissed = true }
        }
    }

    private var popup: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.element) { index, suggestion in
                Text(suggestion)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(index == highlighted ? Color.accentColor.opacity(0.25) : Color.clear)
                    .contentShape(Rectangle())
                    .onHover { if $0 { highlighted = index } }
                    .onTapGesture { accept(suggestion) }
            }
        }
        .padding(.vertical, 4)
        .frame(width: fieldWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .padding(.top, 4)
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard showsPopup else { return .ignored }
        switch press.key {
        case .downArrow:
            highlighted = min(highlighted + 1, matches.count - 1)
            return .handled
        case .upArrow:
            if highlighted > 0 { highlighted -= 1 }
            return .handled
        case .return:
            if matches.indices.contains(highlighted) {
                accept(matches[highlighted])
                return .handled
            }
            return .ignored
        case .escape:
            dismissed = true
            return .handled
        default:
            return .ignored
        }
    }

    private func accept(_ suggestion: String) {
        justAccepted = true
        text = suggestion
        isValidBinding?.wrappedValue = FieldValidator.isValid(suggestion, kind: Self.kind)
        dismissed = true
        highlighted = -1
    }
}
