import SwiftUI
import AppKit

/// Einrichtung des KI-Zugriffs: erklärt das Verfahren, liefert die fertigen
/// Konfigurationsangaben zum Kopieren und prüft auf Knopfdruck, ob die
/// Verbindung funktioniert.
struct MCPSettingsView: View {
    @State private var copiedItem: String?
    @State private var selfTestState: SelfTestState = .idle

    private enum SelfTestState {
        case idle
        case running
        case success(String)
        case failure(String)
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 20) {
                    introCard
                    claudeDesktopCard
                    claudeCodeCard
                    selfTestCard
                }
                .padding(20)
            }
        }
        .navigationTitle("KI-Zugriff")
    }

    // MARK: - Erklärung

    private var introCard: some View {
        GlassCard(title: "Fuhrparkdaten für eine KI freigeben") {
            Text("""
                FuhrparkDesktop kann seine Daten über das Model Context Protocol \
                (MCP) für eine KI wie Claude bereitstellen. Danach lassen sich \
                Fragen wie „Was kostet mich der Wagen pro Kilometer?“ oder „Was \
                wird demnächst fällig?“ direkt im Chat beantworten.
                """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                factRow("lock.shield", "Nur lesend – die KI kann nichts anlegen, ändern oder löschen.")
                factRow("doc.on.doc", "Ohne Datenkopie – gelesen wird direkt aus der Datenbank der App.")
                factRow("hand.raised", "Nur auf Nachfrage – es wird nichts von sich aus übertragen. Was du fragst, entscheidet, welche Daten an die KI gehen.")
                factRow("bolt", "Die App muss dafür nicht laufen.")
            }
            .padding(.top, 4)
        }
    }

    private func factRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 18)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Claude Desktop

    private var claudeDesktopCard: some View {
        GlassCard(title: "Claude Desktop einrichten") {
            stepText(1, "Diese Konfiguration kopieren:")
            codeBlock(MCPSetup.claudeDesktopSnippet)
            copyButton("Konfiguration kopieren", value: MCPSetup.claudeDesktopSnippet, id: "desktop")

            stepText(2, "In diese Datei einfügen (bei vorhandenen Einträgen nur den Block innerhalb von „mcpServers“ ergänzen):")
            codeBlock(MCPSetup.claudeDesktopConfigPath)
            copyButton("Dateipfad kopieren", value: MCPSetup.claudeDesktopConfigPath, id: "desktopPath")

            stepText(3, "Claude Desktop vollständig beenden (⌘Q) und neu starten. Ein bloßes Schließen des Fensters genügt nicht.")
        }
    }

    // MARK: - Claude Code

    private var claudeCodeCard: some View {
        GlassCard(title: "Claude Code einrichten") {
            Text("Diesen Befehl im Terminal ausführen:")
                .font(.callout)
                .foregroundStyle(.secondary)
            codeBlock(MCPSetup.claudeCodeCommand)
            copyButton("Befehl kopieren", value: MCPSetup.claudeCodeCommand, id: "code")
        }
    }

    // MARK: - Selbsttest

    private var selfTestCard: some View {
        GlassCard(title: "Selbsttest") {
            Text("""
                Prüft, ob der Server startet, die Datenbank erreicht und korrekt \
                antwortet – ohne dass du dafür einen Client einrichten musst.
                """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Verbindung testen") { runSelfTest() }
                    .buttonStyle(.glassProminent)
                    .pointerStyle(.link)
                    .disabled(isSelfTestRunning)

                switch selfTestState {
                case .idle:
                    EmptyView()
                case .running:
                    ProgressView().controlSize(.small)
                case .success(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                case .failure(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var isSelfTestRunning: Bool {
        if case .running = selfTestState { return true }
        return false
    }

    private func runSelfTest() {
        selfTestState = .running
        Task {
            // Der Selbsttest startet einen Kindprozess und wartet auf ihn –
            // das gehört von der Oberfläche weg.
            let result = await Task.detached(priority: .userInitiated) {
                MCPSetup.runSelfTest()
            }.value

            switch result {
            case .success(let toolCount, let vehicleCount):
                selfTestState = .success("Verbindung steht – \(toolCount) Werkzeuge, \(vehicleCount) Fahrzeuge gelesen.")
            case .failure(let message):
                selfTestState = .failure(message)
            }
        }
    }

    // MARK: - Bausteine

    private func stepText(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).")
                .font(.callout.bold())
                .foregroundStyle(.tint)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func copyButton(_ title: String, value: String, id: String) -> some View {
        Button(copiedItem == id ? "Kopiert" : title,
               systemImage: copiedItem == id ? "checkmark" : "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copiedItem = id
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copiedItem == id { copiedItem = nil }
            }
        }
        .buttonStyle(.glass)
        .pointerStyle(.link)
    }
}
