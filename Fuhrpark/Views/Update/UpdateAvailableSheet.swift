import SwiftUI
import AppKit

/// Hinweis auf eine neuere Version. Lädt bewusst nichts herunter, sondern
/// öffnet die Download-Seite im Browser – siehe `UpdateChecker` für den Grund.
struct UpdateAvailableSheet: View {
    let release: AppRelease
    let currentVersion: String
    /// Dieselbe Einstellung wie der Haken im App-Menü – bewusst kein eigener
    /// `@State`, sonst liefen Menü und Hinweis auseinander.
    @Binding var automaticChecks: Bool
    let onSkip: () -> Void
    let onDismiss: () -> Void

    /// „14.08.2026" statt „2026-08-14" – das Manifest führt das Datum in
    /// ISO-Schreibweise, angezeigt wird es wie überall sonst in der App.
    /// Lässt es sich nicht lesen, bleibt es unverändert stehen, statt den
    /// ganzen Hinweis an einem Tippfehler scheitern zu lassen.
    private var publishedText: String {
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.locale = Locale(identifier: "en_US_POSIX")
        guard let date = iso.date(from: release.publishedAt) else { return release.publishedAt }
        return FieldValidator.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !release.notes.isEmpty {
                GlassCard(title: "Neu in dieser Version") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(release.notes, id: \.self) { note in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                Text(note)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }

            Toggle("Beim Start automatisch nach Updates suchen", isOn: $automaticChecks)
                .toggleStyle(.checkbox)
                .font(.subheadline)

            buttons
        }
        .padding(20)
        .frame(width: 440)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text("Neue Version verfügbar")
                    .font(.title2.bold())
                Text("FuhrparkDesktop \(release.version) ist seit dem \(publishedText) verfügbar – du verwendest \(currentVersion).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var buttons: some View {
        HStack {
            Button("Diese Version überspringen") {
                onSkip()
            }
            .pointerStyle(.link)

            Spacer()

            Button("Später") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)
            .pointerStyle(.link)

            Button("Herunterladen") {
                NSWorkspace.shared.open(release.downloadPageURL)
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
            .pointerStyle(.link)
        }
    }
}

#Preview {
    UpdateAvailableSheet(
        release: AppRelease(
            version: "1.8",
            publishedAt: "2026-08-20",
            minimumSystemVersion: "26.0",
            downloadPageURL: URL(string: "https://fuhrpark-macos.gerd-klaus.de/#download")!,
            notes: [
                "Hinweis auf neue Versionen beim Start",
                "PDF-Export für Betankungs- und Ausgabenliste"
            ]
        ),
        currentVersion: "1.7",
        automaticChecks: .constant(true),
        onSkip: { },
        onDismiss: { }
    )
}
