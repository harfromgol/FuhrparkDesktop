// Erzeugt das App-Icon programmatisch (AppKit/Core Graphics) in allen macOS-
// Größen und schreibt die PNGs direkt in den Asset-Katalog.
//
// Aufruf (vom Repo-Wurzelverzeichnis):
//   swift Scripts/generate_app_icon.swift \
//     FuhrparkDesktop/Assets.xcassets/AppIcon.appiconset
//
// Motiv: oranger macOS-Squircle mit dezentem Glass-Glanz und weichem Schatten,
// darauf das SF-Symbol „car.2.fill" (Fuhrpark = Fahrzeugflotte).

import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func draw(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s) // 1 pt == 1 px

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Icon-Körper (macOS-Squircle mit Rand für den Schatten)
    let bodyRatio: CGFloat = 0.805
    let body = s * bodyRatio
    let origin = (s - body) / 2
    let rect = NSRect(x: origin, y: origin, width: body, height: body)
    let radius = body * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // weicher Schlagschatten
    cg.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.shadowBlurRadius = s * 0.03
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    cg.restoreGState()

    // Orange-Verlauf als Hintergrund
    path.addClip()
    let top = NSColor(srgbRed: 1.00, green: 0.72, blue: 0.30, alpha: 1)
    let bottom = NSColor(srgbRed: 0.93, green: 0.47, blue: 0.06, alpha: 1)
    NSGradient(starting: top, ending: bottom)!.draw(in: rect, angle: -90)

    // dezenter Glass-Glanz oben
    let sheen = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.28),
        NSColor.white.withAlphaComponent(0.0)
    ])!
    let sheenRect = NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)
    sheen.draw(in: sheenRect, angle: -90)
    NSGraphicsContext.current?.saveGraphicsState()

    // SF-Symbol „car.2.fill" in Weiß, zentriert
    let pt = s * 0.42
    let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "car.2.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let target = body * 0.60
        let aspect = symbol.size.width / max(symbol.size.height, 1)
        var w = target, h = target
        if aspect >= 1 { h = target / aspect } else { w = target * aspect }
        let symRect = NSRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h)
        symbol.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Katalog-Slots: Dateiname -> Pixelgröße
let files: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for (name, px) in files {
    let data = draw(size: px)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
    try! data.write(to: url)
    print("wrote \(name).png (\(px)px)")
}
