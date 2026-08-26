import SwiftUI

/// Eine Zeile in der Dokumente-Liste. Klick öffnet die Datei mit der
/// Standard-App; das Kontextmenü bietet „Im Finder anzeigen“ und „Entfernen“.
struct DocumentRow: View {
    @ObservedObject var document: Dokument

    /// Wird hochgezählt, sobald sich das Arbeitsverzeichnis geändert hat.
    ///
    /// Nötig, weil `WorkingDirectoryStore` auf UserDefaults sitzt und SwiftUI
    /// Änderungen daran nicht von selbst bemerkt: Ohne diesen Wert behielte die
    /// Zeile ihren alten Zustand, bis die Ansicht aus einem anderen Grund neu
    /// gezeichnet wird.
    let workingDirectoryRevision: Int

    let onDelete: () -> Void
    let onReassign: () -> Void
    let onError: (String) -> Void

    /// Empfänger der zugeordneten Ausgaben, auf eine Zeile eingedampft.
    /// Bei mehreren steht hinter dem ersten die Zahl der übrigen; die
    /// vollständige Liste liefert der Tooltip.
    private var empfaengerKurz: String? {
        let namen = document.sortedExpenses.compactMap { $0.recipient }.filter { !$0.isEmpty }
        guard let erster = namen.first else { return nil }
        return namen.count > 1 ? "\(erster) +\(namen.count - 1)" : erster
    }

    private var empfaengerVollstaendig: String {
        let ausgaben = document.sortedExpenses
        if !ausgaben.isEmpty {
            return ausgaben
                .map { "\($0.recipient ?? "") – \($0.purpose ?? "")" }
                .joined(separator: "\n")
        }
        let notizen = document.sortedNotizen
        guard !notizen.isEmpty else { return "Keiner Ausgabe oder Notiz zugeordnet" }
        return notizen.map { $0.text ?? "" }.joined(separator: "\n")
    }

    /// Hinweis, falls die Datei gerade nicht erreichbar ist – sonst `nil`.
    ///
    /// Der Ablagepfad wird bewusst nicht mehr angezeigt: Seit alle Belege im
    /// selben Arbeitsverzeichnis liegen, stand in jeder Zeile derselbe lange
    /// Pfad, ergänzt um den technischen Unterordner. Wo die Dateien liegen,
    /// zeigt das Zahnrad-Menü; hier zählt nur noch, ob etwas fehlt.
    private var problemHinweis: String? {
        guard WorkingDirectoryStore.isConfigured else {
            return "Kein Arbeitsverzeichnis festgelegt"
        }
        guard let path = document.path,
              (try? DocumentStorage.resolvedURL(forRelativePath: path)) != nil
        else {
            return "Datei nicht gefunden"
        }
        return nil
    }

    var body: some View {
        Button {
            do {
                try document.open()
            } catch {
                onError(error.localizedDescription)
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .foregroundStyle(.secondary)
                        Text(document.filename)
                            .font(.subheadline.bold())
                    }
                    HStack(spacing: 6) {
                        if let vehicle = document.vehicle {
                            Text(vehicle.licensePlate ?? "")
                        }
                        if let empfaengerKurz {
                            Text("· \(empfaengerKurz)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(empfaengerVollstaendig)
                    if let problemHinweis {
                        Label(problemHinweis, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let createdAt = document.createdAt {
                        Text(FieldValidator.string(from: createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !document.categoriesDisplay.isEmpty {
                        Text(document.categoriesDisplay)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .contextMenu {
            Button("Zuordnung bearbeiten…", action: onReassign)
            Button("Im Finder anzeigen") {
                do {
                    try document.reveal()
                } catch {
                    onError(error.localizedDescription)
                }
            }
            Button("Entfernen", role: .destructive, action: onDelete)
        }
        Divider()
    }
}
