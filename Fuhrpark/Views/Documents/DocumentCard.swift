import SwiftUI

/// Eine Kachel im Dokumente-Fenster: oben die Vorschau des Dokuments, darunter
/// Dateiname, Kennzeichen, Kategorien und Datum – nach dem Vorbild von
/// paperless-ngx. Klick öffnet die Datei mit der Standard-App; das
/// Kontextmenü bietet „Zuordnung bearbeiten…“, „Im Finder anzeigen“ und
/// „Entfernen“.
struct DocumentCard: View {
    @ObservedObject var document: Dokument

    /// Wird hochgezählt, sobald sich das Arbeitsverzeichnis geändert hat.
    ///
    /// Nötig, weil `WorkingDirectoryStore` auf UserDefaults sitzt und SwiftUI
    /// Änderungen daran nicht von selbst bemerkt: Ohne diesen Wert behielte die
    /// Kachel ihre alte Vorschau (oder ihren alten Hinweis), bis die Ansicht
    /// aus einem anderen Grund neu gezeichnet wird.
    let workingDirectoryRevision: Int

    let onDelete: () -> Void
    let onReassign: () -> Void
    let onError: (String) -> Void

    @Environment(\.displayScale) private var displayScale

    /// Stand der Vorschau. Der Hinweis (`problem`) ersetzt die frühere
    /// Zeile mit dem Warndreieck: Wo die Datei fehlt, gibt es auch keine
    /// Vorschau, beides hängt am selben Zugriff.
    private enum PreviewState {
        case loading
        case ready(DocumentThumbnails.Thumbnail)
        case problem(String)
    }

    @State private var previewState = PreviewState.loading
    @State private var isHovering = false

    private static let cornerRadius: CGFloat = 16
    /// Höhe der Vorschau. Bei der üblichen Kachelbreite von 200 pt ist das
    /// etwa die Hälfte der Kachel; ein A4-Blatt wird dabei oben ausgeschnitten.
    private static let previewHeight: CGFloat = 190

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

    /// Wechselt, sobald sich Datei, Arbeitsverzeichnis oder Bildschirmfaktor
    /// ändern – dann wird die Vorschau neu geholt.
    private var previewTaskID: String {
        "\(document.objectID.uriRepresentation())|\(document.path ?? "")|\(workingDirectoryRevision)|\(displayScale)"
    }

    var body: some View {
        Button {
            do {
                try document.open()
            } catch {
                onError(error.localizedDescription)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                preview
                info
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(Color.accentColor.opacity(isHovering ? 0.7 : 0), lineWidth: 2)
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .pointerStyle(.link)
        .help(document.filename)
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
        .task(id: previewTaskID) { await loadPreview() }
    }

    // MARK: - Vorschau

    /// Der Rahmen ist über `Color.clear` fest, das Bild liegt nur als
    /// `overlay` darüber: So bestimmt ein breites Bild nie die Kachelbreite,
    /// es wird bloß beschnitten.
    private var preview: some View {
        Color.clear
            .frame(height: Self.previewHeight)
            .overlay(alignment: .top) { previewContent }
            .background(.quaternary.opacity(0.5))
            .clipped()
    }

    @ViewBuilder
    private var previewContent: some View {
        switch previewState {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let thumbnail) where thumbnail.isPreview && Self.isWide(thumbnail.image):
            // Querformat (Foto, quer gescannter Beleg): ganz zeigen. Füllend
            // würde es links und rechts um etwa ein Drittel beschnitten, und
            // bei einem Foto fehlte dann Wesentliches.
            Image(nsImage: thumbnail.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let thumbnail) where thumbnail.isPreview:
            // Hochformat: füllend und oben ausgerichtet, so sieht man bei
            // einem Blatt den Briefkopf – wie bei paperless-ngx.
            Image(nsImage: thumbnail.image)
                .resizable()
                .scaledToFill()
        case .ready(let thumbnail):
            // Nur das Symbol des Dateityps: verkleinert in der Mitte.
            Image(nsImage: thumbnail.image)
                .resizable()
                .scaledToFit()
                .padding(36)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .problem(let text):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Breiter als hoch genug, dass Füllen zu viel abschneiden würde. Die
    /// Vorschaufläche selbst ist etwa 1,1 : 1; Quadratisches und Hochformat
    /// füllen sie, Querformat (4 : 3 und breiter) wird ganz gezeigt.
    private static func isWide(_ image: NSImage) -> Bool {
        image.size.width / max(image.size.height, 1) > 1.15
    }

    private func loadPreview() async {
        previewState = .loading
        do {
            let thumbnail = try await DocumentThumbnails.thumbnail(for: document, scale: displayScale)
            guard !Task.isCancelled else { return }
            previewState = .ready(thumbnail)
        } catch {
            guard !Task.isCancelled else { return }
            previewState = .problem(Self.problemText(for: error))
        }
    }

    /// Kurzer Hinweis für die Kachel. Die ausführliche Fehlermeldung
    /// bekommt weiterhin, wer die Datei per Klick öffnen will.
    private static func problemText(for error: Error) -> String {
        switch error {
        case DokumentAccessError.workingDirectoryNotConfigured:
            "Kein Arbeitsverzeichnis festgelegt"
        case DokumentAccessError.fileNotFound:
            "Datei nicht gefunden"
        default:
            "Keine Vorschau verfügbar"
        }
    }

    // MARK: - Infos

    private var info: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(document.filename)
                .font(.subheadline.bold())
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)

            HStack(spacing: 4) {
                if let vehicle = document.vehicle {
                    Text(vehicle.licensePlate ?? "")
                }
                if let empfaengerKurz {
                    Text("· \(empfaengerKurz)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .help(empfaengerVollstaendig)

            categoryChips
                .frame(height: 18)

            if let createdAt = document.createdAt {
                Text(FieldValidator.string(from: createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Die ersten zwei Kategorien als Kapseln, weitere als „+n“. Die Zeile
    /// hat eine feste Höhe (siehe `info`), damit alle Kacheln gleich hoch
    /// bleiben, auch ohne Kategorie.
    private var categoryChips: some View {
        let names = document.categoryNames
        return HStack(spacing: 4) {
            ForEach(names.prefix(2), id: \.self) { name in
                chip(name)
            }
            if names.count > 2 {
                chip("+\(names.count - 2)")
                    .fixedSize()
            }
            Spacer(minLength: 0)
        }
        .help(names.joined(separator: ", "))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}
