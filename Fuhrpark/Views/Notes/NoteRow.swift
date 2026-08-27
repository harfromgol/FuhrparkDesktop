import SwiftUI

/// Zeile in der Notizen-Liste: Datum/Kennzeichen, gekürzter Text, Büroklammer
/// mit Anzahl bei angehängten Dokumenten. Bearbeiten nur per Kontextmenü
/// (Rechtsklick), kein Öffnen per Linksklick auf die Zeile. Die Büroklammer
/// ist eigenständig klickbar: bei genau einem Dokument öffnet der Klick es
/// direkt, bei mehreren zeigt er ein Popover zur Auswahl.
struct NoteRow: View {
    @ObservedObject var notiz: Notiz
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isPresentingAttachments = false
    @State private var errorMessage: String?

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
            let documents = notiz.sortedDokumente
            if !documents.isEmpty {
                Button {
                    if documents.count == 1, let only = documents.first {
                        openDocument(only)
                    } else {
                        isPresentingAttachments = true
                    }
                } label: {
                    Label("\(documents.count)", systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .popover(isPresented: $isPresentingAttachments) {
                    attachmentsPopover(documents)
                }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .contextMenu {
            Button("Bearbeiten", action: onEdit)
            Button("Löschen", role: .destructive, action: onDelete)
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }

    private func attachmentsPopover(_ documents: [Dokument]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dokumente")
                .font(.headline)
            ForEach(documents) { document in
                Button {
                    isPresentingAttachments = false
                    openDocument(document)
                } label: {
                    Label(document.filename, systemImage: "doc")
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
        }
        .padding(16)
        .frame(minWidth: 220, alignment: .leading)
    }

    private func openDocument(_ document: Dokument) {
        do {
            try document.open()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
