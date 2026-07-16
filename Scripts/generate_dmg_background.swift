// Erzeugt das Hintergrundbild für das Installations-DMG (AppKit/Core Graphics).
//
// Aufruf (vom Repo-Wurzelverzeichnis):
//   swift Scripts/generate_dmg_background.swift <ausgabeordner>
//
// Ergebnis: background.png (620x420) und background@2x.png (1240x840).
// Motiv: heller, dezenter Verlauf mit einem nach rechts zeigenden Pfeil mittig
// zwischen den beiden Icon-Plätzen (App links, Programme rechts) plus dezente
// Beschriftung – passend zur orangen App-Marke.

import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// Fenster-/Bildmaße in Punkten. Muss zu den Finder-Fensterbounds passen.
let W: CGFloat = 620
let H: CGFloat = 420

// Icon-Mittelpunkte in Finder-Koordinaten (Ursprung oben links, y nach unten).
let appCenterFinder = CGPoint(x: 165, y: 205)
let appsCenterFinder = CGPoint(x: 455, y: 205)

// Umrechnung Finder (oben-links, y↓) -> AppKit (unten-links, y↑)
func toAppKitY(_ yFinder: CGFloat) -> CGFloat { H - yFinder }

func draw(scale: CGFloat) -> Data {
    let pw = Int(W * scale), ph = Int(H * scale)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H) // 1 Einheit == 1 Punkt

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx

    // Hintergrund: sehr dezenter, heller Vertikalverlauf.
    let top = NSColor(srgbRed: 0.985, green: 0.985, blue: 0.99, alpha: 1)
    let bottom = NSColor(srgbRed: 0.91, green: 0.925, blue: 0.945, alpha: 1)
    NSGradient(starting: top, ending: bottom)!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    // Pfeil mittig zwischen den beiden Icon-Plätzen. Der Hintergrund erscheint im
    // Finder-Fenster um die Titelleistenhöhe nach oben versetzt; daher wird der
    // Pfeil bewusst etwas tiefer (Finder-y 236) gezeichnet, damit er auf
    // Icon-Höhe (Finder-y 205) landet.
    let cy = toAppKitY(236)
    let shaftLeft: CGFloat = 250
    let shaftRight: CGFloat = 348
    let tipX: CGFloat = 384
    let shaftHalf: CGFloat = 8   // halbe Schafthöhe
    let headHalf: CGFloat = 22   // halbe Kopfhöhe

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: shaftLeft, y: cy + shaftHalf))
    arrow.line(to: NSPoint(x: shaftRight, y: cy + shaftHalf))
    arrow.line(to: NSPoint(x: shaftRight, y: cy + headHalf))
    arrow.line(to: NSPoint(x: tipX, y: cy))
    arrow.line(to: NSPoint(x: shaftRight, y: cy - headHalf))
    arrow.line(to: NSPoint(x: shaftRight, y: cy - shaftHalf))
    arrow.line(to: NSPoint(x: shaftLeft, y: cy - shaftHalf))
    arrow.close()

    NSColor(srgbRed: 0.93, green: 0.52, blue: 0.10, alpha: 0.92).setFill()
    arrow.fill()

    // Dezente Beschriftung unter dem Pfeil.
    let caption = "In den Programme-Ordner ziehen"
    let capStyle = NSMutableParagraphStyle()
    capStyle.alignment = .center
    let capAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor(srgbRed: 0.45, green: 0.47, blue: 0.5, alpha: 1),
        .paragraphStyle: capStyle
    ]
    let capSize = (caption as NSString).size(withAttributes: capAttrs)
    // Beschriftung an den unteren Rand (Finder-y ~360), damit sie nicht mit den
    // Icons/Labels überlappt.
    (caption as NSString).draw(
        in: NSRect(x: (W - 360) / 2, y: toAppKitY(360), width: 360, height: capSize.height),
        withAttributes: capAttrs)

    // Titel oben zentriert.
    let title = "FuhrparkDesktop"
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .center
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.2, green: 0.22, blue: 0.26, alpha: 1),
        .paragraphStyle: titleStyle
    ]
    let titleSize = (title as NSString).size(withAttributes: titleAttrs)
    (title as NSString).draw(
        in: NSRect(x: 0, y: toAppKitY(52) - titleSize.height / 2, width: W, height: titleSize.height),
        withAttributes: titleAttrs)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, scale) in [("background.png", CGFloat(1)), ("background@2x.png", CGFloat(2))] {
    let data = draw(scale: scale)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(name)")
}
