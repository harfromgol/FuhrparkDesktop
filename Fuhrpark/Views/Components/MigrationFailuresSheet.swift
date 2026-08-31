import SwiftUI

/// Listet Dokumente auf, die beim Wechsel des Arbeitsverzeichnisses nicht
/// automatisch übernommen werden konnten. Gemeinsam genutzt von
/// `DocumentsView` und der Sektion „Dokumente“ im Einstellungsfenster
/// (`SettingsView`) – beide lösen den Wechsel über `WorkingDirectoryChange`
/// aus und zeigen bei Fehlschlägen dieselbe Liste.
struct MigrationFailuresSheet: View {
    let failures: [DocumentMigration.Failure]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Einige Dokumente konnten nicht automatisch übernommen werden")
                .font(.headline)
                .padding(20)
            List(failures, id: \.documentID) { failure in
                VStack(alignment: .leading, spacing: 2) {
                    Text(failure.filename)
                        .font(.subheadline.bold())
                    Text(failure.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("OK") { onDismiss() }
                    .pointerStyle(.link)
            }
            .padding(16)
        }
        .frame(width: 420, height: 360)
    }
}
