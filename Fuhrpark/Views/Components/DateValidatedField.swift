import SwiftUI

/// Datumsfeld mit Texteingabe (TT.MM.JJJJ) plus Kalender-Button zur Mausauswahl.
struct DateValidatedField: View {
    let title: String
    @Binding var text: String
    var isValidBinding: Binding<Bool>? = nil

    @State private var showPicker = false

    private var pickerDateBinding: Binding<Date> {
        Binding(
            get: { FieldValidator.dateValue(text) ?? Date() },
            set: { newDate in text = FieldValidator.string(from: newDate) }
        )
    }

    var body: some View {
        ValidatedField(
            title: title,
            text: $text,
            kind: .date,
            isValidBinding: isValidBinding,
            accessory: AnyView(
                Button {
                    showPicker = true
                } label: {
                    Image(systemName: "calendar")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $showPicker) {
                    DatePicker("Datum", selection: pickerDateBinding, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                }
            )
        )
    }
}
