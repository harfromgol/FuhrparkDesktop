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
    let onError: (String) -> Void

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
                    Text(document.filename)
                        .font(.subheadline.bold())
                    HStack(spacing: 6) {
                        if let vehicle = document.vehicle {
                            Text(vehicle.licensePlate ?? "")
                        }
                        if let expense = document.expense {
                            Text("· \(expense.recipient ?? "")")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
