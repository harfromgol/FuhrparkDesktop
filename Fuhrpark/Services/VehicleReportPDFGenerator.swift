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
        let pageStarts = pageStartOffsets(for: reportView.sections)
        let totalHeight = pageStarts.totalHeight

        let renderer = ImageRenderer(content: reportView)

        let filename = "\(vehicle.licensePlate ?? "Fahrzeug")_\(timestamp()).pdf"
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard let consumer = CGDataConsumer(url: url as CFURL) else {
            throw ExportError.consumerCreationFailed
        }

        var thrown: Error?
        renderer.render { _, drawContent in
            var mediaBox = CGRect(origin: .zero, size: pageSize)
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                thrown = ExportError.contextCreationFailed
                return
            }

            // SwiftUI zeichnet über diese API in den unveränderten (nicht
            // gespiegelten) Koordinaten des CGContext – Inhalt-Offset 0 landet
            // also am UNTEREN Rand des Gesamtinhalts, nicht am oberen. Ohne
            // Berücksichtigung von `totalHeight` würde Seite 1 daher das
            // Seitenende zeigen.
            let pageCount = pageStarts.offsets.count
            for (page, pageTop) in pageStarts.offsets.enumerated() {
                // Wie weit reicht der Inhalt auf DIESER Seite tatsächlich?
                // `contentAreaHeight` ist nur die Obergrenze – beginnt die
                // nächste Seite (wegen eines nicht mehr passenden Abschnitts)
                // früher, muss die Seite hier ebenso früh enden, sonst
                // schneidet der feste Rahmen trotz korrekt berechnetem
                // Umbruch weiterhin mitten in den nächsten Abschnitt.
                // 1pt Sicherheitsabstand, sonst schneidet der Clip exakt auf
                // Höhe der (0.5pt breiten) Rahmenlinie des nächsten
                // Abschnitts und lässt einen Haarriss durchscheinen.
                let nextTop = page + 1 < pageStarts.offsets.count ? pageStarts.offsets[page + 1] - 1 : pageTop + contentAreaHeight
                let visibleHeight = min(contentAreaHeight, nextTop - pageTop)
                let contentArea = CGRect(
                    x: 0,
                    y: bottomMargin + contentAreaHeight - visibleHeight,
                    width: pageSize.width,
                    height: visibleHeight
                )

                context.beginPDFPage(nil)
                context.saveGState()
                // Ohne diesen Clip zeichnet SwiftUI den kompletten (nur
                // verschobenen) Inhalt weiter bis zum Seitenrand – eine Karte,
                // die bis in den unteren Rand reicht, würde sich sonst mit der
                // Fußzeile überlappen.
                context.clip(to: contentArea)
                context.translateBy(
                    x: 0,
                    y: pageTop - totalHeight + bottomMargin + contentAreaHeight
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

    /// Ermittelt, an welchem Inhalts-Offset (von oben gemessen) jede Seite
    /// beginnt – und zwar an Abschnittsgrenzen, nicht in gleichmäßigen
    /// `contentAreaHeight`-Schritten wie in der ersten Version. Jeder
    /// Abschnitt (Karte) wird dafür einzeln über einen eigenen
    /// `ImageRenderer` (`.nsImage?.size`) vermessen; passt der nächste
    /// Abschnitt nicht mehr auf die aktuelle
    /// Seite, beginnt er auf einer neuen Seite, statt mitten in einer
    /// Karte/Zeile zerschnitten zu werden. Ein einzelner Abschnitt, der
    /// bereits für sich allein höher als eine Seite ist, wird davon
    /// ausgenommen (bekannte Einschränkung, in dieser App praktisch nicht
    /// relevant, da alle Karten deutlich kleiner als eine Seite sind).
    @MainActor
    private static func pageStartOffsets(for sections: [AnyView]) -> (offsets: [CGFloat], totalHeight: CGFloat) {
        let heights = sections.map { section in
            ImageRenderer(content: section.frame(width: VehiclePDFReportView.contentWidth)).nsImage?.size.height ?? 0
        }
        guard !heights.isEmpty else { return ([0], 0) }

        let spacing = VehiclePDFReportView.sectionSpacing
        var tops: [CGFloat] = []
        var cursor: CGFloat = 0
        for height in heights {
            tops.append(cursor)
            cursor += height + spacing
        }
        let totalHeight = cursor - spacing

        var offsets: [CGFloat] = [0]
        var currentPageStart: CGFloat = 0
        for (index, top) in tops.enumerated() {
            let bottom = top + heights[index]
            if bottom - currentPageStart > contentAreaHeight, top > currentPageStart {
                currentPageStart = top
                offsets.append(top)
            }
        }

        return (offsets, totalHeight)
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
