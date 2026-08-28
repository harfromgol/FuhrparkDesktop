import SwiftUI

/// Anlegen und Bearbeiten einer Erinnerung in einer View (analog `VehicleFormView`).
struct ReminderFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    /// Erinnerung, die bearbeitet wird; `nil` beim Anlegen einer neuen Erinnerung.
    let reminderToEdit: Erinnerung?

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var title: String
    @State private var dueDateText: String
    @State private var selectedVehicle: Vehicle?
    @State private var isDone: Bool
    @State private var isRecurring: Bool
    @State private var repeatIntervalText: String
    @State private var repeatUnit: RepeatUnit
    @State private var advanceNotice: AdvanceNotice

    @State private var titleValid = false
    @State private var dueDateValid = false
    @State private var repeatIntervalValid = true

    init(reminderToEdit: Erinnerung? = nil) {
        self.reminderToEdit = reminderToEdit
        _title = State(initialValue: reminderToEdit?.title ?? "")
        _dueDateText = State(initialValue: FieldValidator.string(from: reminderToEdit?.dueDate ?? Date()))
        _selectedVehicle = State(initialValue: reminderToEdit?.vehicle)
        _isDone = State(initialValue: reminderToEdit?.isDone ?? false)
        let currentUnit = reminderToEdit?.repeatUnit ?? .none
        _isRecurring = State(initialValue: currentUnit != .none)
        _repeatIntervalText = State(initialValue: String(reminderToEdit?.repeatIntervalValue ?? 1))
        _repeatUnit = State(initialValue: currentUnit == .none ? .month : currentUnit)
        _advanceNotice = State(initialValue: reminderToEdit?.advanceNotice ?? .none)
    }

    private var isFormValid: Bool {
        titleValid && dueDateValid && selectedVehicle != nil && (!isRecurring || repeatIntervalValid)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GlassEffectContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassCard(title: "Erinnerung") {
                            ValidatedField(
                                title: "Titel",
                                text: $title,
                                kind: .text(min: 1, max: 40),
                                isValidBinding: $titleValid
                            )
                            DateValidatedField(title: "Fälligkeitsdatum", text: $dueDateText, isValidBinding: $dueDateValid)

                            if !isRecurring {
                                Toggle("Erledigt", isOn: $isDone)
                                    .toggleStyle(.checkbox)
                            } else {
                                Text("Wiederkehrende Erinnerungen werden über die Checkbox in der Liste erledigt und springen automatisch auf den nächsten Termin.")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        GlassCard(title: "Kennzeichen") {
                            VehiclePicker(vehicles: Array(vehicles), selection: $selectedVehicle)
                        }

                        GlassCard(title: "Wiederholung") {
                            Toggle("Wiederholen", isOn: $isRecurring)
                                .toggleStyle(.checkbox)
                            if isRecurring {
                                HStack {
                                    ValidatedField(
                                        title: "Alle",
                                        text: $repeatIntervalText,
                                        kind: .integer(minDigits: 1, maxDigits: 3),
                                        isValidBinding: $repeatIntervalValid,
                                        extraValidation: { (FieldValidator.intValue($0) ?? 0) > 0 },
                                        extraErrorMessage: "Muss größer als 0 sein"
                                    )
                                    .frame(width: 110)

                                    Picker("Einheit", selection: $repeatUnit) {
                                        ForEach(RepeatUnit.allCases.filter { $0 != .none }) { unit in
                                            Text(unit.displayName).tag(unit)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                }
                            }
                        }

                        GlassCard(title: "Vorzeitige Erinnerung") {
                            Picker("Vorzeitige Erinnerung", selection: $advanceNotice) {
                                ForEach(AdvanceNotice.allCases) { notice in
                                    Text(notice.displayName).tag(notice)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                        }
                    }
                    .padding(20)
                }
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
        .frame(width: 440, height: 680)
    }

    private func save() {
        let reminder = reminderToEdit ?? Erinnerung(context: viewContext)
        if reminderToEdit == nil {
            reminder.id = UUID()
            reminder.createdAt = Date()
        }
        reminder.title = title
        reminder.dueDate = FieldValidator.dateValue(dueDateText) ?? Date()
        reminder.vehicle = selectedVehicle
        reminder.repeatUnit = isRecurring ? repeatUnit : .none
        reminder.repeatIntervalValue = isRecurring
            ? Int16(FieldValidator.intValue(repeatIntervalText) ?? 1)
            : 1
        reminder.advanceNotice = advanceNotice
        // Bei wiederkehrenden Erinnerungen ist „erledigt" nur ein UI-Trigger
        // (siehe Erinnerung.toggleDone) – im Formular daher nie persistieren.
        reminder.isDone = isRecurring ? false : isDone

        PersistenceController.shared.save(context: viewContext)
        dismiss()
    }
}
