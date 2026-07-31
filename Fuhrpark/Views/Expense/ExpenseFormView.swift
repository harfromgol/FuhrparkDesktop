import SwiftUI
import UniformTypeIdentifiers

struct ExpenseFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    /// Nur die Kategorien dieses Fahrzeugs (siehe `init`).
    @FetchRequest private var categories: FetchedResults<Category>

    /// Ausgaben dieses Fahrzeugs – Quelle für die Empfänger-Vorschläge (siehe `init`).
    @FetchRequest private var recipientExpenses: FetchedResults<Expense>

    /// Ausgabe (false, Standard) oder Einnahme (true).
    @State private var isIncome = false
    @State private var dateText = FieldValidator.string(from: Date())
    @State private var amountText = ""
    @State private var recipient = ""
    @State private var purpose = ""
    @State private var selectedCategories: Set<Category> = []
    @State private var newCategoryName = ""
    @State private var pendingDocuments: [PendingDocument] = []
    @State private var isPresentingFilePicker = false
    @State private var errorMessage: String?
    @State private var hasSavedExpense = false

    @State private var dateValid = false
    @State private var amountValid = false
    @State private var recipientValid = false
    @State private var purposeValid = false

    /// Beim Anlegen ausgewählte, aber noch nicht gespeicherte Datei – wird erst
    /// beim Speichern der Ausgabe als `Dokument` angelegt.
    private struct PendingDocument: Identifiable {
        let id = UUID()
        let path: String
        let bookmarkData: Data

        var filename: String { (path as NSString).lastPathComponent }
    }

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _categories = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
            predicate: NSPredicate(format: "vehicle == %@", vehicle),
            animation: .default
        )
        _recipientExpenses = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Expense.recipient, ascending: true)],
            predicate: NSPredicate(format: "vehicle == %@", vehicle),
            animation: .default
        )
    }

    private var isFormValid: Bool {
        dateValid && amountValid && recipientValid && purposeValid && !selectedCategories.isEmpty
    }

    /// Bereits erfasste Empfänger dieses Fahrzeugs (distinct, case-insensitiv,
    /// alphabetisch) als Vorschläge für die Autovervollständigung.
    private var knownRecipients: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for expense in recipientExpenses {
            let name = (expense.recipient ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            result.append(name)
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GlassEffectContainer {
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
                        SuggestingField(
                            title: isIncome ? "Zahler" : "Empfänger",
                            text: $recipient,
                            isValidBinding: $recipientValid,
                            suggestions: knownRecipients
                        )
                        ValidatedField(
                            title: isIncome ? "Grund" : "Verwendungszweck",
                            text: $purpose,
                            kind: .text(min: 1, max: 30),
                            isValidBinding: $purposeValid
                        )

                        categorySection
                        documentsSection
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
                    .disabled(!isFormValid || hasSavedExpense)
                    .pointerStyle(isFormValid && !hasSavedExpense ? .link : nil)
            }
            .padding(16)
        }
        .frame(width: 440, height: 700)
        .fileImporter(
            isPresented: $isPresentingFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
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

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dokumente")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !pendingDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(pendingDocuments) { document in
                        HStack {
                            Label(document.filename, systemImage: "doc")
                                .lineLimit(1)
                                .font(.caption)
                            Spacer()
                            Button {
                                pendingDocuments.removeAll { $0.id == document.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button("Dokument auswählen", systemImage: "doc.badge.plus") {
                addDocumentTapped()
            }
            .buttonStyle(.glass)
            .pointerStyle(.link)
        }
    }

    private func addDocumentTapped() {
        guard WorkingDirectoryStore.isConfigured else {
            errorMessage = "Bevor du Dokumente hinzufügen kannst, lege im Bereich „Dokumente“ über das Zahnrad-Symbol ein Arbeitsverzeichnis fest."
            return
        }
        isPresentingFilePicker = true
    }

    /// Sichert für jede ausgewählte Datei ein Security-Scoped Bookmark (die
    /// App läuft sandboxed), damit der Zugriff bis zum Speichern erhalten
    /// bleibt. Das eigentliche `Dokument` (inkl. Kopie ins Arbeitsverzeichnis)
    /// wird erst beim Speichern der Ausgabe angelegt.
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Zugriff auf „\(url.lastPathComponent)“ wurde verweigert."
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let bookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) else {
                errorMessage = "Für „\(url.lastPathComponent)“ konnte kein dauerhafter Zugriff gespeichert werden."
                continue
            }
            pendingDocuments.append(PendingDocument(path: url.path, bookmarkData: bookmark))
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

        var failedFilenames: [String] = []
        for pending in pendingDocuments {
            var isStale = false
            guard let sourceURL = try? URL(
                resolvingBookmarkData: pending.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), sourceURL.startAccessingSecurityScopedResource() else {
                failedFilenames.append(pending.filename)
                continue
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            guard let relativePath = try? DocumentStorage.copyIntoWorkingDirectory(from: sourceURL, documentID: pending.id) else {
                failedFilenames.append(pending.filename)
                continue
            }
            let document = Dokument(context: viewContext)
            document.id = pending.id
            document.path = relativePath
            document.createdAt = Date()
            document.expense = expense
        }

        vehicle.touch()
        hasSavedExpense = true
        PersistenceController.shared.save(context: viewContext)

        if failedFilenames.isEmpty {
            dismiss()
        } else {
            errorMessage = "Die Ausgabe wurde gespeichert, folgende Dokumente konnten aber nicht hinzugefügt werden: \(failedFilenames.joined(separator: ", "))."
        }
    }
}
