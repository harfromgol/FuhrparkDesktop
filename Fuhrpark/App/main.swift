import Foundation

// Programmeinstieg.
//
// Dasselbe Binary läuft in zwei Betriebsarten: als normale GUI-App und – wenn
// ein MCP-Client es mit `--mcp-stdio` als Kindprozess startet – als
// MCP-Server, der die Fuhrpark-Daten für eine KI lesbar macht.
//
// Die Weiche muss hier stehen, vor jeder AppKit-Initialisierung: Im
// Serverbetrieb darf weder ein Fenster noch ein Dock-Symbol entstehen.
// Weil eine `main.swift` existiert, trägt `FuhrparkDesktopApp` kein `@main`
// mehr – Swift lässt beides nicht gleichzeitig zu.

let mcpArguments = Set(CommandLine.arguments.dropFirst())

if mcpArguments.contains("--mcp-stdio") {
    MCPMain.runServer()
} else if mcpArguments.contains("--mcp-probe") {
    MCPMain.runProbe()
} else {
    FuhrparkDesktopApp.main()
}
