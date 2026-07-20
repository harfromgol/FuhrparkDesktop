import SwiftUI

/// Eine Zeile in der Dokumente-Liste. Klick öffnet die Datei mit der
/// Standard-App; das Kontextmenü bietet „Im Finder anzeigen“ und „Entfernen“.
struct DocumentRow: View {
    @ObservedObject var document: Dokument
    let onDelete: () -> Void

    var body: some View {
        Button {
            document.open()
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
                    Text(document.path ?? "")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
            Button("Im Finder anzeigen") { document.reveal() }
            Button("Entfernen", role: .destructive, action: onDelete)
        }
        Divider()
    }
}
