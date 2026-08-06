import Foundation

/// JSON-RPC-Schicht und Nachrichtenschleife des MCP-Servers.
final class MCPServer {

    /// Protokollfassungen, die dieser Server versteht. Fragt der Client eine
    /// davon an, wird sie bestätigt; sonst nennt der Server seine bevorzugte
    /// Fassung und überlässt dem Client die Entscheidung.
    private static let supportedProtocolVersions: Set<String> = [
        "2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"
    ]
    private static let preferredProtocolVersion = "2025-06-18"

    private let transport: MCPTransport

    init(transport: MCPTransport) {
        self.transport = transport
    }

    /// Läuft, bis stdin auf EOF geht.
    func run() {
        while let line = transport.nextLine() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            handle(trimmed)
        }
    }

    // MARK: - Nachrichtenverarbeitung

    private func handle(_ line: String) {
        guard
            let data = line.data(using: .utf8),
            let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            // Fehlerhafte Eingaben beenden den Server nicht – der Client soll
            // sich davon erholen können.
            send(error: -32700, message: "Ungültiges JSON.", id: NSNull())
            return
        }

        guard let method = message["method"] as? String else {
            if let id = message["id"] {
                send(error: -32600, message: "Feld „method“ fehlt.", id: id)
            }
            return
        }

        // Nachrichten ohne „id“ sind Notifications (etwa
        // `notifications/initialized`) und werden nie beantwortet.
        guard let id = message["id"], !(id is NSNull) else { return }

        let params = message["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            send(result: initializeResult(params: params), id: id)
        case "ping":
            send(result: [:], id: id)
        case "tools/list":
            send(result: ["tools": MCPToolCatalog.definitions], id: id)
        case "tools/call":
            handleToolCall(params: params, id: id)
        default:
            send(error: -32601, message: "Unbekannte Methode „\(method)“.", id: id)
        }
    }

    private func initializeResult(params: [String: Any]) -> [String: Any] {
        let requested = params["protocolVersion"] as? String
        let version = requested.flatMap { Self.supportedProtocolVersions.contains($0) ? $0 : nil }
            ?? Self.preferredProtocolVersion

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

        return [
            "protocolVersion": version,
            "capabilities": ["tools": [String: Any]()],
            "serverInfo": ["name": "fuhrpark", "version": appVersion],
            "instructions": MCPToolCatalog.serverInstructions
        ]
    }

    private func handleToolCall(params: [String: Any], id: Any) {
        guard let name = params["name"] as? String else {
            send(error: -32602, message: "Feld „name“ fehlt.", id: id)
            return
        }
        let arguments = params["arguments"] as? [String: Any] ?? [:]

        do {
            send(result: toolResult(try MCPToolCatalog.run(name: name, arguments: arguments)), id: id)
        } catch {
            // Fachliche Fehler gehen bewusst als Werkzeugergebnis mit
            // `isError` zurück statt als JSON-RPC-Fehler: So sieht das Modell
            // den Text und kann darauf reagieren (etwa ein Kennzeichen
            // korrigieren), statt nur ein Protokollproblem gemeldet zu bekommen.
            send(result: toolResult(["fehler": error.localizedDescription], isError: true), id: id)
        }
    }

    /// Verpackt die Nutzlast als Textblock. Der Text ist kompaktes JSON –
    /// niemals eingerückt, sonst enthielte die Zeile Zeilenumbrüche und würde
    /// die NDJSON-Rahmung zerstören.
    private func toolResult(_ payload: [String: Any], isError: Bool = false) -> [String: Any] {
        let text: String
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes]),
           let encoded = String(data: data, encoding: .utf8) {
            text = encoded
        } else {
            text = #"{"fehler":"Das Ergebnis konnte nicht serialisiert werden."}"#
        }

        return [
            "content": [["type": "text", "text": text]],
            "isError": isError
        ]
    }

    // MARK: - Versand

    private func send(result: [String: Any], id: Any) {
        emit(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private func send(error code: Int, message: String, id: Any) {
        emit(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    private func emit(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: message,
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) else {
            transport.log("Antwort konnte nicht serialisiert werden.")
            return
        }
        transport.send(data)
    }
}
