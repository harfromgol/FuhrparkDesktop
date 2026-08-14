import SwiftUI
import AppKit
import CoreText

/// Erzeugt aus einer Berichts-View (z. B. `VehiclePDFReportView`,
/// `StatisticsPDFReportView`) ein mehrseitiges A4-PDF und öffnet es in
/// Vorschau.app. Nutzt `ImageRenderer.render(rasterizationScale:renderer:)`:
/// dessen Callback liefert die natürliche Inhaltsgröße plus einen
/// `(CGContext) -> Void`-Zeichenblock, der beliebig oft mit verschobenen
/// Kontexten aufgerufen werden kann – die dokumentierte Technik für
/// mehrseitige Vektor-PDFs aus SwiftUI (Text wird dabei als echter PDF-Text
/// gezeichnet, nicht gerastert).
enum ReportPDFGenerator {
    private static let pageSize = CGSize(width: PDFReportLayout.pageWidth, height: 841.89) // A4 bei 72dpi
    /// Weißraum oben/unten auf JEDER Seite – die Paginierung schneidet den
    /// fortlaufenden Inhalt sonst bündig an der Seitenkante ab. Die Ränder
    /// werden deshalb hier (nicht als Padding in der Berichts-View)
    /// verwaltet, damit sie auf jeder Seite gleich groß sind, nicht nur am
    /// Anfang/Ende des Gesamtinhalts.
    private static let topMargin: CGFloat = 48
    private static let bottomMargin: CGFloat = 60
    private static let contentAreaHeight = pageSize.height - topMargin - bottomMargin

    /// - Parameters:
    ///   - reportView: die zu druckende Berichts-View, bereits auf
    ///     `PDFReportLayout.pageWidth` breit.
    ///   - sections: dieselben Abschnitte wie in `reportView`, für die
    ///     Seitenumbruch-Berechnung – siehe `PDFReportSection`.
    ///   - filenamePrefix: Dateiname ohne Zeitstempel/Endung, z. B. das
    ///     Kennzeichen oder „Statistik".
    @MainActor
    static func generate<ReportView: View>(
        _ reportView: ReportView,
        sections: [PDFReportSection],
        filenamePrefix: String
    ) throws -> URL {
        let pageStarts = pageStartOffsets(for: sections)
        let totalHeight = pageStarts.totalHeight

        let renderer = ImageRenderer(content: reportView)

        let filename = "\(filenamePrefix)_\(timestamp()).pdf"
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
    /// beginnt. Umbrüche liegen an Abschnittsgrenzen (Kartenanfang) UND –
    /// bei Tabellen-Karten mit unterschiedlich vielen Zeilen – zusätzlich an
    /// jeder Zeilengrenze innerhalb einer Karte, die für sich allein nicht
    /// mehr auf eine Seite passt. Eine solche Karte wird dann komplett auf
    /// mehrere Seiten verteilt, ohne dass eine einzelne Zeile mittendrin
    /// zerschnitten wird (ihr Rahmen schließt dabei allerdings nicht sauber
    /// ab – kosmetischer Kompromiss für einen in der Praxis sehr seltenen
    /// Fall).
    @MainActor
    private static func pageStartOffsets(
        for sections: [PDFReportSection]
    ) -> (offsets: [CGFloat], totalHeight: CGFloat) {
        func measure(_ view: AnyView) -> CGFloat {
            ImageRenderer(content: view.frame(width: PDFReportLayout.contentWidth)).nsImage?.size.height ?? 0
        }

        struct Measured {
            let height: CGFloat
            /// Offsets ab dem Abschnittsanfang, an denen (zusätzlich zum
            /// Abschnittsanfang selbst) umgebrochen werden darf, ohne eine
            /// Zeile zu zerschneiden – leer bei Abschnitten ohne Zeilen.
            let rowBreaks: [CGFloat]
        }

        let measured: [Measured] = sections.map { section in
            let height = measure(section.view)
            guard let rowInfo = section.rowInfo, rowInfo.rowCount > 1 else {
                return Measured(height: height, rowBreaks: [])
            }
            // Kopf- (Titel/Spaltenköpfe) und Zeilenhöhe lassen sich aus einer
            // Karte nicht direkt auslesen – deshalb dieselbe Karte einmal
            // ohne Zeilen vermessen; die Differenz zur vollen Höhe, geteilt
            // durch die Zeilenanzahl, ergibt die (bei gleich hohen Zeilen
            // exakte) Höhe einer einzelnen Zeile.
            //
            // `chromeHeight` misst dabei eine EIGENSTÄNDIGE, vollständige
            // Karte mit 0 Zeilen – ihr unteres `cardPadding` sitzt also
            // direkt hinter Titel/Spaltenköpfen. In der echten Karte mit
            // Zeilen sitzt dasselbe Padding aber erst hinter der LETZTEN
            // Zeile. Ohne den Abzug von `cardPadding` würde jeder
            // Zeilenumbruch-Kandidat um dieses Padding zu weit in den
            // Inhalt hineinragen und die jeweils nächste Zeile anschneiden.
            let chromeHeight = measure(rowInfo.chromeOnly) - PDFReportLayout.cardPadding
            let rowHeight = (height - PDFReportLayout.cardPadding - chromeHeight) / CGFloat(rowInfo.rowCount)
            guard rowHeight > 0 else { return Measured(height: height, rowBreaks: []) }
            let rowBreaks = (1..<rowInfo.rowCount).map { chromeHeight + CGFloat($0) * rowHeight }
            return Measured(height: height, rowBreaks: rowBreaks)
        }
        guard !measured.isEmpty else { return ([0], 0) }

        let spacing = PDFReportLayout.sectionSpacing
        var tops: [CGFloat] = []
        var cursor: CGFloat = 0
        for m in measured {
            tops.append(cursor)
            cursor += m.height + spacing
        }
        let totalHeight = cursor - spacing

        // Alle Umbruch-Kandidaten sammeln (aufsteigend, da abschnittsweise
        // bereits aufsteigend erzeugt und Abschnitte selbst aufsteigend
        // sind): Zeilengrenzen innerhalb einer Karte, gefolgt vom Anfang des
        // jeweils nächsten Abschnitts.
        var candidates: [CGFloat] = []
        for (index, m) in measured.enumerated() {
            for rowBreak in m.rowBreaks {
                candidates.append(tops[index] + rowBreak)
            }
            if index + 1 < measured.count {
                candidates.append(tops[index + 1])
            }
        }

        // Klassischer Greedy-Umbruch (wie Zeilenumbruch in einem Textsatz):
        // den am weitesten entfernten, noch passenden Kandidaten je Seite
        // suchen; passt nicht einmal der erste, wird trotzdem umgebrochen
        // (Karte bzw. Zeile größer als eine Seite – siehe oben).
        var offsets: [CGFloat] = [0]
        var currentPageStart: CGFloat = 0
        var lastFitting: CGFloat = 0
        var index = 0
        while index < candidates.count {
            let candidate = candidates[index]
            if candidate - currentPageStart <= contentAreaHeight {
                lastFitting = candidate
                index += 1
            } else if lastFitting > currentPageStart {
                currentPageStart = lastFitting
                offsets.append(lastFitting)
            } else {
                currentPageStart = candidate
                offsets.append(candidate)
                lastFitting = candidate
                index += 1
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
