import SwiftUI
import AppKit

/// Zeigt beim allerersten Start automatisch zwei kurze Einrichtungsschritte:
/// automatische Update-Prüfung und Arbeitsverzeichnis. Ersetzt die frühere,
/// einmalige Rückfrage zur Update-Prüfung (siehe `UpdateChecker`) – die ist
/// jetzt Schritt 1 dieses Assistenten. Ob der Assistent überhaupt erscheinen
/// soll, entscheidet `SetupWizardStore.shouldShowWizard()`.
///
/// Explizite `updateChecker`-Übergabe statt `@Environment` in diesem
/// `ViewModifier` selbst – analog zu `UpdateNoticeModifier`/`BackupModifier`
/// in `ContentView.swift`, den einzigen anderen `ViewModifier`n dort, die
/// geteilten Zustand brauchen.
struct SetupWizardModifier: ViewModifier {
    let updateChecker: UpdateChecker
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .task {
                guard SetupWizardStore.shouldShowWizard() else { return }
                isPresented = true
            }
            .sheet(isPresented: $isPresented) {
                SetupWizardView()
            }
            // Erst NACH vollständigem Schließen des Assistenten automatisch
            // prüfen: Ein sofortiger Aufruf direkt aus Schritt 1 heraus
            // könnte `updateChecker.availableRelease` setzen, während der
            // Assistent selbst noch als Sheet offen ist (Nutzer ist längst
            // bei Schritt 2) – zwei gleichzeitig präsentierte `.sheet`s auf
            // demselben `ContentView` (dieses hier und
            // `UpdateNoticeModifier.availableRelease`) sind auf diesem
            // SDK-Stand nicht zuverlässig. `DispatchQueue.main.async` wie
            // beim Export/Import-Panel in `ContentView`.
            .onChange(of: isPresented) { _, isShown in
                guard !isShown, updateChecker.automaticChecksEnabled else { return }
                DispatchQueue.main.async {
                    Task { await updateChecker.checkAutomatically() }
                }
            }
    }
}

private enum WizardStep: Int, CaseIterable {
    case updateCheck
    case workingDirectory
}

/// Jeder Schritt ist einzeln überspringbar, der ganze Assistent jederzeit
/// abbrechbar – beides merkt ihn in `SetupWizardStore` als abgeschlossen,
/// damit er beim nächsten Start nicht erneut erscheint.
private struct SetupWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: WizardStep = .updateCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Schritt \(step.rawValue + 1) von \(WizardStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
                .padding(.horizontal, 20)

            ScrollView {
                stepContent
                    .padding(20)
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack {
                Button("Abbrechen") { abbrechen() }
                    .keyboardShortcut(.cancelAction)
                    .pointerStyle(.link)

                Spacer()

                if step == .workingDirectory {
                    Button("Fertig") { weiterOderFertig() }
                        .keyboardShortcut(.defaultAction)
                        .pointerStyle(.link)
                } else {
                    Button("Überspringen") { weiterOderFertig() }
                        .pointerStyle(.link)
                }
            }
            .padding(16)
        }
        .frame(width: 520, height: 420)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .updateCheck:
            UpdateCheckStepView(onAnswered: { step = .workingDirectory })
        case .workingDirectory:
            WorkingDirectoryStepView()
        }
    }

    private func abbrechen() {
        SetupWizardStore.markCompleted()
        dismiss()
    }

    /// Auf Schritt 1: „Überspringen" – geht ohne gespeicherte Antwort weiter.
    /// Auf Schritt 2 (letzter Schritt): „Fertig" – schließt den Assistenten.
    private func weiterOderFertig() {
        switch step {
        case .updateCheck:
            step = .workingDirectory
        case .workingDirectory:
            SetupWizardStore.markCompleted()
            dismiss()
        }
    }
}

/// Schritt 1: wortgleich zur früheren einmaligen Rückfrage aus
/// `UpdateNoticeModifier` (deren `.confirmationDialog` entfällt) – nur jetzt
/// als Assistent-Schritt statt als Dialog. Schreibt direkt auf
/// `updateChecker.automaticChecksEnabled` – als `@Observable`-Klasse braucht
/// eine einmalige Zuweisung kein `@Bindable`, das ist nur für `$`-Bindings
/// nötig.
private struct UpdateCheckStepView: View {
    @Environment(UpdateChecker.self) private var updateChecker
    let onAnswered: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nach neuen Versionen suchen?")
                .font(.title2.bold())

            Text("""
                FuhrparkDesktop kann beim Start höchstens einmal täglich nachsehen, \
                ob eine neue Version vorliegt. Dabei wird nur eine kleine Datei von \
                fuhrpark-macos.gerd-klaus.de geladen – es werden keine Angaben über \
                dich oder deinen Fuhrpark übertragen, auch nicht die verwendete \
                Version.

                Die Einstellung lässt sich jederzeit im Menü „FuhrparkDesktop" ändern.
                """)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Ja, beim Start nachsehen") {
                    updateChecker.automaticChecksEnabled = true
                    onAnswered()
                }
                .keyboardShortcut(.defaultAction)
                .pointerStyle(.link)

                Button("Nein") {
                    updateChecker.automaticChecksEnabled = false
                    onAnswered()
                }
                .pointerStyle(.link)
            }
        }
    }
}

/// Schritt 2: identisches Verhalten zu `DocumentsSettingsSection` in
/// `SettingsView.swift` (bewusst dupliziert statt geteilt – `SettingsView`
/// bleibt unverändert). Anders als dort kein „Im Finder anzeigen"-Button
/// (auf einem frischen Verzeichnis gibt es noch nichts zu zeigen, später
/// jederzeit über Einstellungen → Dokumente erreichbar) und kein
/// automatisches Schließen bei Erfolg: Der Assistent schließt sich nur über
/// den „Fertig"-Button unten – ein Sheet, das sich aus einem verschachtelten
/// Kind-Sheet (Migrations-Fehler) heraus selbst schließt, wäre unnötiges
/// Risiko.
private struct WorkingDirectoryStepView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var isConfigured = WorkingDirectoryStore.isConfigured
    @State private var revision = 0
    @State private var migrationFailures: [DocumentMigration.Failure] = []
    @State private var isPresentingMigrationFailures = false
    @State private var hinweis: Hinweis?

    private struct Hinweis: Identifiable {
        let id = UUID()
        let titel: String
        let text: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Arbeitsverzeichnis auswählen")
                .font(.title2.bold())

            Text("""
                Belege und andere Dokumente werden als Kopie in einem Ordner \
                deiner Wahl abgelegt, damit sie auch dann auffindbar bleiben, \
                wenn sich der Ablageort der Originaldatei später ändert.

                Die Einstellung lässt sich jederzeit in den Einstellungen unter \
                „Dokumente" ändern.
                """)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text(WorkingDirectoryStore.displayPath ?? "Kein Arbeitsverzeichnis festgelegt")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .id(revision)

                Button(isConfigured ? "Ändern…" : "Ordner wählen…") {
                    presentFolderPicker()
                }
                .buttonStyle(.bordered)
                .pointerStyle(.link)
            }
        }
        .alert(
            hinweis?.titel ?? "",
            isPresented: Binding(
                get: { hinweis != nil },
                set: { if !$0 { hinweis = nil } }
            ),
            presenting: hinweis
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { hinweis in
            Text(hinweis.text)
        }
        .sheet(isPresented: $isPresentingMigrationFailures) {
            MigrationFailuresSheet(failures: migrationFailures, onDismiss: { isPresentingMigrationFailures = false })
        }
    }

    private func presentFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Wählen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let outcome = try WorkingDirectoryChange.apply(url: url, in: viewContext)
            isConfigured = true
            revision += 1
            if !outcome.migrationFailures.isEmpty {
                migrationFailures = outcome.migrationFailures
                isPresentingMigrationFailures = true
            } else if let warning = outcome.foreignFolderWarning {
                hinweis = Hinweis(titel: "Fremde Belegordner im Verzeichnis", text: warning)
            }
        } catch {
            hinweis = Hinweis(titel: "Fehler", text: error.localizedDescription)
        }
    }
}

#Preview {
    let updateChecker = UpdateChecker()
    return Color.clear
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(updateChecker)
        .modifier(SetupWizardModifier(updateChecker: updateChecker))
}
