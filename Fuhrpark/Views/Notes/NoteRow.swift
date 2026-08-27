import SwiftUI

/// Zeile in der Notizen-Liste: Datum/Kennzeichen, gekürzter Text, Büroklammer
/// mit Anzahl bei angehängten Dokumenten. Bearbeiten nur per Kontextmenü
/// (Rechtsklick), kein Öffnen per Linksklick auf die Zeile.
struct NoteRow: View {
    @ObservedObject var notiz: Notiz
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let date = notiz.date {
                        Text(FieldValidator.string(from: date))
                            .font(.subheadline.bold())
                    }
                    if let plate = notiz.vehicle?.licensePlate {
                        Text(plate)
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(notiz.text ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2...3)
            }
            Spacer()
            let documentCount = notiz.sortedDokumente.count
            if documentCount > 0 {
                Label("\(documentCount)", systemImage: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .contextMenu {
            Button("Bearbeiten", action: onEdit)
            Button("Löschen", role: .destructive, action: onDelete)
        }
    }
}
