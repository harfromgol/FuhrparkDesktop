import Foundation

/// Erzeugt die Einrichtungsangaben für MCP-Clients und führt den Selbsttest aus.
///
/// Die Pfade werden bewusst zur Laufzeit aus dem Bundle ermittelt statt fest
/// hinterlegt: Wird die App verschoben, stimmt der angezeigte Schnipsel sofort
/// wieder – die bereits eingetragene Client-Konfiguration allerdings nicht mehr
/// und muss dann neu übernommen werden.
///
/// Auch der Servername kommt aus `AppVariant`: Trüge der Testbau denselben
/// Namen wie die produktive App, überschriebe sein Schnipsel im Client deren
/// Eintrag – und die KI läse ab dann die Testdaten.
enum MCPSetup {

    static var executablePath: String {
        Bundle.main.executableURL?.path ?? "(unbekannt)"
    }

    static var serverName: String { AppVariant.mcpServerName }

    static var claudeDesktopConfigPath: String {
        "~/Library/Application Support/Claude/claude_desktop_config.json"
    }

    /// Fertiger Konfigurationsschnipsel für Claude Desktop.
    static var claudeDesktopSnippet: String {
        """
        {
          "mcpServers": {
            "\(serverName)": {
              "command": "\(executablePath)",
              "args": ["--mcp-stdio"]
            }
          }
        }
        """
    }

    /// Fertige Kommandozeile für Claude Code.
    static var claudeCodeCommand: String {
        "claude mcp add \(serverName) --scope user -- \"\(executablePath)\" --mcp-stdio"
    }

    // MARK: - Selbsttest

    enum SelfTestResult {
        case success(toolCount: Int, vehicleCount: Int)
        case failure(String)
    }

    /// Startet das eigene Binary im MCP-Modus, führt einen vollständigen
    /// Handshake aus und prüft die Antworten. Damit sieht der Nutzer sofort, ob
    /// die Einrichtung funktionieren wird, ohne selbst zur Kommandozeile zu
    /// greifen.
    ///
    /// Blockierend – gehört auf einen Hintergrund-Task.
    nonisolated static func runSelfTest() -> SelfTestResult {
        guard let executable = Bundle.main.executableURL else {
            return .failure("Das Programm konnte sich selbst nicht finden.")
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["--mcp-stdio"]

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        let requests = [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"selbsttest","version":"1"}}}"#,
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#,
            #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"fleet_overview","arguments":{}}}"#
        ]

        do {
            try process.run()
        } catch {
            return .failure("Der Serverprozess ließ sich nicht starten: \(error.localizedDescription)")
        }

        input.fileHandleForWriting.write(Data((requests.joined(separator: "\n") + "\n").utf8))
        try? input.fileHandleForWriting.close()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return .failure("Der Serverprozess endete mit Code \(process.terminationStatus).")
        }

        let lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Erwartet werden genau drei Antworten – auf die Notification darf
        // keine kommen.
        guard lines.count == 3 else {
            return .failure("Unerwartete Antwortzahl (\(lines.count) statt 3). Der Protokollstrom ist gestört.")
        }

        var toolCount = 0
        var vehicleCount = 0

        for line in lines {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                let result = object["result"] as? [String: Any]
            else {
                return .failure("Eine Antwort war kein gültiges JSON.")
            }

            if let tools = result["tools"] as? [[String: Any]] {
                toolCount = tools.count
            }
            if let content = result["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String,
               let payload = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
               let inventory = payload["bestand"] as? [String: Any],
               let count = inventory["fahrzeuge"] as? Int {
                vehicleCount = count
            }
        }

        guard toolCount > 0 else {
            return .failure("Der Server hat keine Werkzeuge gemeldet.")
        }

        return .success(toolCount: toolCount, vehicleCount: vehicleCount)
    }
}
