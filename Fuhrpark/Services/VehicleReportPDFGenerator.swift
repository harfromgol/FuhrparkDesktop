import SwiftUI
import AppKit
import CoreText

/// Erzeugt aus `VehiclePDFReportView` ein mehrseitiges A4-PDF und öffnet es
/// in Vorschau.app. Nutzt `ImageRenderer.render(rasterizationScale:renderer:)`:
/// dessen Callback liefert die natürliche Inhaltsgröße plus einen
/// `(CGContext) -> Void`-Zeichenblock, der beliebig oft mit verschobenen
/// Kontexten aufgerufen werden kann – die dokumentierte Technik für
/// mehrseitige Vektor-PDFs aus SwiftUI (Text wird dabei als echter PDF-Text
/// gezeichnet, nicht gerastert).
enum VehicleReportPDFGenerator {
    private static let pageSize = CGSize(width: 595.28, height: 841.89) // A4 bei 72dpi
    /// Weißraum oben/unten auf JEDER Seite – die Paginierung schneidet den
    /// fortlaufenden Inhalt sonst bündig an der Seitenkante ab. Die Ränder
    /// werden deshalb hier (nicht als Padding in `VehiclePDFReportView`)
    /// verwaltet, damit sie auf jeder Seite gleich groß sind, nicht nur am
    /// Anfang/Ende des Gesamtinhalts.
    private static let topMargin: CGFloat = 48
    private static let bottomMargin: CGFloat = 60
    private static let contentAreaHeight = pageSize.height - topMargin - bottomMargin

    @MainActor
    static func generate(vehicle: Vehicle, enabledCards: Set<StatisticsCard>) throws -> URL {
        let reportView = VehiclePDFReportView(vehicle: vehicle, enabledCards: enabledCards)
        let renderer = ImageRenderer(content: reportView)

        let filename = "\(vehicle.licensePlate ?? "Fahrzeug")_\(timestamp()).pdf"
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard let consumer = CGDataConsumer(url: url as CFURL) else {
            throw ExportError.consumerCreationFailed
        }

        var thrown: Error?
        renderer.render { size, drawContent in
            var mediaBox = CGRect(origin: .zero, size: pageSize)
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                thrown = ExportError.contextCreationFailed
                return
            }

            // Naive Paginierung ohne Seitenumbruch-Vermeidung: eine Karte kann
            // dabei mitten auf einer Seitengrenze zerschnitten werden – wie bei
            // einem normal ausgedruckten Dokument.
            //
            // SwiftUI zeichnet über diese API in den unveränderten (nicht
            // gespiegelten) Koordinaten des CGContext – Inhalt-y=0 landet also
            // am UNTEREN Rand des Gesamtinhalts, nicht am oberen. Ohne
            // Berücksichtigung der vollen Inhaltshöhe (`size.height`) würde
            // Seite 1 daher das Seitenende zeigen. Die Verschiebung bezieht
            // sich deshalb auf `size.height`, nicht nur auf den Seitenindex,
            // und auf `contentAreaHeight` statt der vollen Seitenhöhe, damit
            // pro Seite Platz für Kopf-/Fußrand bleibt.
            let pageCount = max(1, Int(ceil(size.height / contentAreaHeight)))
            let contentArea = CGRect(x: 0, y: bottomMargin, width: pageSize.width, height: contentAreaHeight)
            for page in 0..<pageCount {
                context.beginPDFPage(nil)
                context.saveGState()
                // Ohne diesen Clip zeichnet SwiftUI den kompletten (nur um
                // `size.height` verschobenen) Inhalt weiter bis zum Seitenrand
                // – eine Karte, die bis in den unteren Rand reicht, würde sich
                // sonst mit der Fußzeile überlappen.
                context.clip(to: contentArea)
                context.translateBy(
                    x: 0,
                    y: CGFloat(page + 1) * contentAreaHeight - size.height + bottomMargin
                )
                drawContent(context)
                context.restoreGState()
                drawFooter(in: context, page: page, pageCount: pageCount)
                context.endPDFPage()
            }
            context.closePDF()
        }
        if let thrown { throw thrown }
        return url
    }

    /// Zeichnet „Seite X von Y" mittig in den unteren Rand – bewusst NICHT
    /// innerhalb des mit `saveGState`/`restoreGState` geklammerten,
    /// verschobenen Koordinatensystems des Seiteninhalts, sondern in den
    /// unveränderten Seitenkoordinaten, damit die Position auf jeder Seite
    /// gleich bleibt.
    private static func drawFooter(in context: CGContext, page: Int, pageCount: Int) {
        let text = "Seite \(page + 1) von \(pageCount)"
        let attributedString = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.gray
        ])
        let line = CTLineCreateWithAttributedString(attributedString)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        context.saveGState()
        context.textPosition = CGPoint(
            x: (pageSize.width - bounds.width) / 2,
            y: (bottomMargin - bounds.height) / 2
        )
        CTLineDraw(line, context)
        context.restoreGState()
    }

    /// Öffnet die PDF-Datei gezielt mit Vorschau.app statt der Standard-App.
    /// Als `async throws` statt eines Closure-Callbacks gebaut, damit der
    /// completionHandler-Sprung zurück auf den Aufrufer (der die Fehlermeldung
    /// in ein `@State` schreibt) nicht als über Actor-Grenzen gesendeter,
    /// nicht-`Sendable`-Closure vom Swift-6-Concurrency-Checker abgelehnt wird.
    @MainActor
    static func openInPreview(_ url: URL) async throws {
        guard let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") else {
            if !NSWorkspace.shared.open(url) {
                throw ExportError.previewNotFound
            }
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open([url], withApplicationAt: previewURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter.string(from: Date())
    }

    enum ExportError: LocalizedError {
        case consumerCreationFailed
        case contextCreationFailed
        case previewNotFound

        var errorDescription: String? {
            switch self {
            case .consumerCreationFailed: "PDF-Datei konnte nicht angelegt werden."
            case .contextCreationFailed: "PDF-Inhalt konnte nicht erzeugt werden."
            case .previewNotFound: "Vorschau.app wurde nicht gefunden und die PDF-Datei konnte auch nicht mit der Standard-App geöffnet werden."
            }
        }
    }
}
