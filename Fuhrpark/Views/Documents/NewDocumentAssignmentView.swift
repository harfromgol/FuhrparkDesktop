import SwiftUI
import CoreData

/// Ordnet einen Beleg einer oder mehreren sonstigen Ausgaben zu.
///
/// Zwei Betriebsarten:
/// - **Neu anlegen**: Die Datei wurde über den Öffnen-Dialog gewählt und liegt
///   noch am Ursprungsort; kopiert wird sie erst beim Bestätigen. Bricht der
///   Nutzer ab, bleiben keine Spuren zurück.
/// - **Nachträglich zuordnen**: Der Beleg existiert bereits, es ändert sich
///   nur die Auswahl der Ausgaben. Es wird nichts kopiert.
///
/// In beiden Fällen gilt: Ein Beleg gehört zu genau **einem** Fahrzeug. Die
/// Ausgabenliste ist deshalb nach Fahrzeug gefiltert, und ein Fahrzeugwechsel
/// leert die Auswahl – so kann gar keine gemischte Zuordnung entstehen.
struct NewDocumentAssignmentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    /// Anzeigename der Datei (beim Anlegen der Ursprungspfad, sonst der Beleg).
    let path: String
    /// Security-Scoped Bookmark der noch nicht kopierten Datei – nur beim Anlegen.
    let bookmarkData: Data?
    /// Bereits vorhandener Beleg – nur beim nachträglichen Zuordnen.
    let existingDocument: Dokument?
    let onSaved: () -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)])
    private var vehicles: FetchedResults<Vehicle>

    @State private var selectedVehicle: Vehicle?
    @State private var selectedExpenses: Set<Expense>
    @State private var selectedNotizen: Set<Notiz>
    /// Welche der beiden Listen gerade eingeblendet ist. Rein die Anzeige –
    /// die Auswahl in der jeweils ausgeblendeten Liste bleibt beim Umschalten
    /// erhalten, ein Beleg kann weiterhin gleichzeitig Ausgaben UND Notizen
    /// zugeordnet sein.
    @State private var assignmentTab: AssignmentTab = .expenses

    private enum AssignmentTab: String, CaseIterable, Identifiable {
        case expenses, notes
        var id: String { rawValue }
        var title: String {
            switch self {
            case .expenses: "Sonstige Ausgaben"
            case .notes: "Notizen"
            }
        }
    }

    init(
        path: String,
        bookmarkData: Data? = nil,
        existingDocument: Dokument? = nil,
        onSaved: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.path = path
        self.bookmarkData = bookmarkData
        self.existingDocument = existingDocument
        self.onSaved = onSaved
        self.onCancel = onCancel
        self.onError = onError
        _selectedVehicle = State(initialValue: existingDocument?.vehicle)
        _selectedExpenses = State(initialValue: Set(existingDocument?.sortedExpenses ?? []))
        _selectedNotizen = State(initialValue: Set(existingDocument?.sortedNotizen ?? []))
    }

    private var isEditingExisting: Bool { existingDocument != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GlassEffectContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        fileCard
                        vehicleCard
                        if let selectedVehicle {
                            Picker("Zuordnungsart", selection: $assignmentTab) {
                                ForEach(AssignmentTab.allCases) { tab in
                                    Text(tab.title).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            switch assignmentTab {
                            case .expenses:
                                ExpensePickerSection(
                                    vehicle: selectedVehicle,
                                    selection: $selectedExpenses
                                )
                            case .notes:
                                NotePickerSection(
                                    vehicle: selectedVehicle,
                                    selection: $selectedNotizen
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }

            Divider()

            HStack {
                Button("Abbrechen", role: .cancel) { onCancel() }
                    .pointerStyle(.link)
                Spacer()
                Button(zuordnenTitle) {
                    save()
                }
                .buttonStyle(.glassProminent)
                .disabled(selectedExpenses.isEmpty && selectedNotizen.isEmpty)
                .pointerStyle(selectedExpenses.isEmpty && selectedNotizen.isEmpty ? nil : .link)
            }
            .padding(16)
        }
        .frame(width: 460, height: 700)
    }

    private var zuordnenTitle: String {
        let count = selectedExpenses.count + selectedNotizen.count
        return count == 0 ? "Zuordnen" : "Zuordnen (\(count))"
    }

    // MARK: - Karten

    private var fileCard: some View {
        GlassCard(title: "Datei") {
            Text((path as NSString).lastPathComponent)
                .font(.headline)
            Text(path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var vehicleCard: some View {
        GlassCard(title: "Fahrzeug") {
            if isEditingExisting {
                // Beim nachträglichen Zuordnen liegt das Fahrzeug fest – ein
                // Wechsel würde die bestehenden Zuordnungen ungültig machen.
                Text(selectedVehicle?.licensePlate ?? "—")
                    .font(.subheadline.bold())
            } else {
                Picker("Fahrzeug", selection: $selectedVehicle) {
                    Text("Bitte wählen").tag(Vehicle?.none)
                    ForEach(vehicles) { vehicle in
                        Text(vehicle.licensePlate ?? "").tag(Vehicle?.some(vehicle))
                    }
                }
                .labelsHidden()
                .onChange(of: selectedVehicle) {
                    selectedExpenses.removeAll()
                    selectedNotizen.removeAll()
                }
            }

            Text("Ein Beleg gehört zu genau einem Fahrzeug. Du kannst ihm mehrere Ausgaben und/oder Notizen dieses Fahrzeugs zuordnen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Speichern

    private func save() {
        guard !selectedExpenses.isEmpty || !selectedNotizen.isEmpty else { return }

        if let existingDocument {
            existingDocument.setExpenses(selectedExpenses)
            existingDocument.setNotizen(selectedNotizen)
            PersistenceController.shared.save(context: viewContext)
            onSaved()
            return
        }

        guard let bookmarkData else {
            onError("Zu dieser Datei liegt kein Zugriff mehr vor.")
            return
        }

        let documentID = UUID()
        var isStale = false
        guard let sourceURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), sourceURL.startAccessingSecurityScopedResource() else {
            onError("Auf die ausgewählte Datei konnte nicht mehr zugegriffen werden.")
            return
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let relativePath: String
        do {
            relativePath = try DocumentStorage.copyIntoWorkingDirectory(from: sourceURL, documentID: documentID)
        } catch {
            onError(error.localizedDescription)
            return
        }

        let document = Dokument(context: viewContext)
        document.id = documentID
        document.path = relativePath
        document.createdAt = Date()
        document.setExpenses(selectedExpenses)
        document.setNotizen(selectedNotizen)

        do {
            try viewContext.save()
        } catch {
            // Die Kopie liegt schon im Arbeitsverzeichnis, der Eintrag fehlt –
            // ohne Aufräumen bliebe ein herrenloser Ordner zurück.
            viewContext.rollback()
            DocumentStorage.delete(documentID: documentID)
            onError(error.localizedDescription)
            return
        }
        onSaved()
    }
}

/// Ausgabenliste eines Fahrzeugs zum An- und Abwählen. Die Auswahl gehört
/// bewusst der übergeordneten Ansicht – diese hier hat nur den `FetchRequest`.
private struct ExpensePickerSection: View {
    @Binding var selection: Set<Expense>

    @FetchRequest private var expenses: FetchedResults<Expense>

    init(vehicle: Vehicle, selection: Binding<Set<Expense>>) {
        _selection = selection
        _expenses = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
            predicate: NSPredicate(format: "vehicle == %@", vehicle),
            animation: .default
        )
    }

    var body: some View {
        GlassCard(title: "Sonstige Ausgaben (\(selection.count) ausgewählt)") {
            if expenses.isEmpty {
                Text("Für dieses Fahrzeug sind noch keine sonstigen Ausgaben erfasst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(expenses) { expense in
                        Button {
                            toggle(expense)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selection.contains(expense) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection.contains(expense) ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.recipient ?? "")
                                        .font(.subheadline.bold())
                                    Text(expense.purpose ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !expense.categoriesDisplay.isEmpty {
                                        Text(expense.categoriesDisplay)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(DisplayFormatter.costString(expense.signedAmount))
                                        .font(.subheadline)
                                    if let date = expense.date {
                                        Text(FieldValidator.string(from: date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        Divider()
                    }
                }
            }
        }
    }

    private func toggle(_ expense: Expense) {
        if selection.contains(expense) {
            selection.remove(expense)
        } else {
            selection.insert(expense)
        }
    }
}

/// Notizenliste eines Fahrzeugs zum An- und Abwählen, exakt analog zu
/// `ExpensePickerSection` – ein Beleg kann gleichzeitig Ausgaben UND Notizen
/// zugeordnet sein, beide Sektionen sind daher unabhängig voneinander nutzbar.
private struct NotePickerSection: View {
    @Binding var selection: Set<Notiz>

    @FetchRequest private var notizen: FetchedResults<Notiz>

    init(vehicle: Vehicle, selection: Binding<Set<Notiz>>) {
        _selection = selection
        _notizen = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Notiz.date, ascending: false)],
            predicate: NSPredicate(format: "vehicle == %@", vehicle),
            animation: .default
        )
    }

    var body: some View {
        GlassCard(title: "Notizen (\(selection.count) ausgewählt)") {
            if notizen.isEmpty {
                Text("Für dieses Fahrzeug sind noch keine Notizen erfasst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(notizen) { notiz in
                        Button {
                            toggle(notiz)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selection.contains(notiz) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection.contains(notiz) ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(notiz.text ?? "")
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if let date = notiz.date {
                                    Text(FieldValidator.string(from: date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        Divider()
                    }
                }
            }
        }
    }

    private func toggle(_ notiz: Notiz) {
        if selection.contains(notiz) {
            selection.remove(notiz)
        } else {
            selection.insert(notiz)
        }
    }
}
