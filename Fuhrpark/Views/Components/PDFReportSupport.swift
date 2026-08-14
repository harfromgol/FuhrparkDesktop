import SwiftUI

/// Gemeinsame Seitengeometrie aller PDF-Berichte (siehe `ReportPDFGenerator`).
/// Ein Bericht ist an fester Breite (A4) mit festem horizontalem Rand
/// aufgebaut; oben/unten übernimmt `ReportPDFGenerator` den Rand einheitlich
/// auf JEDER Seite, nicht nur am Anfang/Ende des Gesamtinhalts.
enum PDFReportLayout {
    static let pageWidth: CGFloat = 595.28 // A4 bei 72dpi
    static let horizontalPadding: CGFloat = 24
    /// Breite, mit der `ReportPDFGenerator` jeden Abschnitt einzeln vermisst
    /// – muss der tatsächlichen Breite innerhalb der Padding-VStack
    /// entsprechen, sonst weichen Einzel- und Gesamtmessung voneinander ab.
    static let contentWidth = pageWidth - horizontalPadding * 2
    /// Muss mit dem `spacing` der Berichts-VStack übereinstimmen – wird für
    /// die Seitenumbruch-Berechnung in `ReportPDFGenerator` gebraucht.
    static let sectionSpacing: CGFloat = 16
    /// Inneres Padding von `PDFReportCard` – wird für die Zeilenumbruch-
    /// Berechnung in `ReportPDFGenerator` gebraucht: eine isoliert (mit 0
    /// Zeilen) vermessene Karte enthält dieses Padding direkt nach dem
    /// Titel/Spaltenköpfen, in der echten Karte mit Zeilen sitzt es aber
    /// erst nach der letzten Zeile. Ohne Korrektur um genau dieses Padding
    /// würde jeder berechnete Zeilenumbruch zu weit in den Inhalt
    /// hineinragen (siehe `ReportPDFGenerator.pageStartOffsets`).
    static let cardPadding: CGFloat = 14
}

/// Ein Abschnitt für die Seitenumbruch-Berechnung in `ReportPDFGenerator`:
/// die Ansicht selbst (immer mit allen Zeilen, wie im Bericht sichtbar)
/// sowie – nur bei Tabellen-Karten mit unterschiedlich vielen Zeilen –
/// zusätzliche Zeileninformationen, damit ein Umbruch nötigenfalls an einer
/// Zeilengrenze INNERHALB der Karte gesetzt werden kann, statt nur an der
/// Kartengrenze. Ohne das könnte eine Karte, die durch viele Zeilen höher
/// als eine Seite wird, mitten in einer Zeile zerschnitten werden.
struct PDFReportSection {
    let view: AnyView
    let rowInfo: RowInfo?

    struct RowInfo {
        let rowCount: Int
        /// Dieselbe Karte, aber mit null Zeilen – für die separate Messung
        /// von Kopf- (Titel/Spaltenköpfe) vs. Zeilenhöhe.
        let chromeOnly: AnyView
    }
}

/// Einfacher, gerahmter Abschnitt ohne Liquid Glass – das druckfreundliche
/// Gegenstück zu `GlassCard`.
struct PDFReportCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(PDFReportLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.35)))
    }
}
