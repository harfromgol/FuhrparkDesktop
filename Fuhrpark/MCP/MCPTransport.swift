import Foundation

/// stdio-Transport des MCP-Servers: newline-getrennte JSON-Nachrichten
/// (NDJSON), genau eine Nachricht pro Zeile, ohne eingebettete Zeilenumbrüche.
final class MCPTransport {

    /// Dublette des echten stdout. Ausschließlich hierüber gehen
    /// Protokollnachrichten.
    private let protocolOut: Int32

    /// Sichert den echten stdout und biegt Datei-Deskriptor 1 auf stderr um.
    ///
    /// Das ist die zentrale Absicherung des Protokollstroms: Alles, was
    /// irgendein Code – eigener, Foundations oder Core Datas – nach stdout
    /// schreibt, landet danach harmlos auf stderr. Eine versehentlich
    /// eingestreute Zeile kann die Protokollnachrichten damit strukturell nicht
    /// mehr zerstören; es bleibt nicht bloß eine Frage der Disziplin.
    init() {
        protocolOut = dup(1)
        dup2(2, 1)
    }

    /// Nächste Zeile von stdin, oder `nil` bei EOF. EOF ist das reguläre
    /// Abschaltsignal: Der Client schließt den Eingabestrom und erwartet, dass
    /// sich der Server daraufhin von selbst beendet.
    func nextLine() -> String? {
        Swift.readLine(strippingNewline: true)
    }

    /// Verschickt eine Protokollnachricht als genau eine Zeile.
    func send(_ payload: Data) {
        var line = payload
        line.append(0x0A)
        write(line, to: protocolOut)
    }

    /// Diagnoseausgabe nach stderr – für den Protokollstrom unschädlich.
    /// MCP-Clients dürfen stderr mitschreiben oder verwerfen und sollen daraus
    /// nicht auf einen Fehler schließen.
    func log(_ message: String) {
        write(Data(("[fuhrpark-mcp] " + message + "\n").utf8), to: 2)
    }

    private func write(_ data: Data, to descriptor: Int32) {
        data.withUnsafeBytes { buffer in
            guard var pointer = buffer.baseAddress else { return }
            var remaining = buffer.count
            while remaining > 0 {
                let written = Darwin.write(descriptor, pointer, remaining)
                // Alles <= 0 heißt: Die Gegenstelle ist weg (typischerweise
                // EPIPE). Dann gibt es nichts mehr zu retten – stillschweigend
                // aufgeben, statt in einer Schleife zu hängen.
                guard written > 0 else { return }
                pointer = pointer.advanced(by: written)
                remaining -= written
            }
        }
    }
}
