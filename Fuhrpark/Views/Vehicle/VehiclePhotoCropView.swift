import SwiftUI

/// Zuschnitt-Editor: Fahrzeugbild im runden Rahmen verschieben/zoomen,
/// analog zum bekannten Kontakte-Bearbeitungsdialog. Liefert auf „OK“ das
/// fertig zugeschnittene Bild als JPEG-Daten.
struct VehiclePhotoCropView: View {
    let cgImage: CGImage
    let onCropped: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    /// Editor-Kreisdurchmesser (Punkte).
    private let canvasSize: CGFloat = 320
    /// Kantenlänge des exportierten quadratischen JPEGs (Pixel).
    private let exportPixelSize: CGFloat = 480
    private let jpegQuality: CGFloat = 0.85
    private let maxUserZoom: CGFloat = 4

    @State private var committedScale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    @State private var committedOffset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero

    private var imagePixelSize: CGSize {
        CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
    }

    /// „Aspect fill“-Skalierung: das Bild füllt den Kreis exakt, ohne ihn zu
    /// überragen.
    private var baseScale: CGFloat {
        max(canvasSize / imagePixelSize.width, canvasSize / imagePixelSize.height)
    }

    private var effectiveUserScale: CGFloat {
        min(max(committedScale * gestureScale, 1), maxUserZoom)
    }

    private func displayedImageSize(scale: CGFloat) -> CGSize {
        let total = baseScale * scale
        return CGSize(width: imagePixelSize.width * total, height: imagePixelSize.height * total)
    }

    /// Maximal erlaubte Verschiebung je Richtung: Bildhälfte minus Kreishälfte.
    private func maxOffset(for size: CGSize) -> CGSize {
        CGSize(width: max(0, (size.width - canvasSize) / 2),
                height: max(0, (size.height - canvasSize) / 2))
    }

    private var clampedOffset: CGSize {
        let raw = CGSize(width: committedOffset.width + gestureOffset.width,
                          height: committedOffset.height + gestureOffset.height)
        let bound = maxOffset(for: displayedImageSize(scale: effectiveUserScale))
        return CGSize(width: min(max(raw.width, -bound.width), bound.width),
                       height: min(max(raw.height, -bound.height), bound.height))
    }

    /// Der eigentliche Bildausschnitt: exakt dieselbe View wird für die
    /// Live-Vorschau (mit Kreis-Maske) UND den finalen Export (quadratisch,
    /// ohne Maske) verwendet – so kann der Export niemals von der Vorschau
    /// abweichen.
    private func croppedSquareContent(scale: CGFloat, offset: CGSize) -> some View {
        Image(decorative: cgImage, scale: 1, orientation: .up)
            .resizable()
            .frame(width: imagePixelSize.width * baseScale * scale,
                   height: imagePixelSize.height * baseScale * scale)
            .offset(offset)
            .frame(width: canvasSize, height: canvasSize)
            .clipped()
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Fahrzeugbild anpassen")
                .font(.headline)

            croppedSquareContent(scale: effectiveUserScale, offset: clampedOffset)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .contentShape(Circle())
                .gesture(SimultaneousGesture(magnifyGesture, dragGesture))

            Slider(value: sliderZoomBinding, in: 1...maxUserZoom) {
                Text("Zoom")
            }
            .frame(width: canvasSize)
            .help("Zoom (auch ohne Trackpad-Pinch nutzbar)")

            HStack {
                Button("Abbrechen", role: .cancel) { dismiss() }
                    .pointerStyle(.link)
                Spacer()
                Button("OK") { commitCrop() }
                    .buttonStyle(.glassProminent)
                    .pointerStyle(.link)
            }
        }
        .padding(20)
        .frame(width: canvasSize + 40)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in state = value.translation }
            .onEnded { value in
                let raw = CGSize(width: committedOffset.width + value.translation.width,
                                  height: committedOffset.height + value.translation.height)
                let bound = maxOffset(for: displayedImageSize(scale: effectiveUserScale))
                committedOffset = CGSize(width: min(max(raw.width, -bound.width), bound.width),
                                          height: min(max(raw.height, -bound.height), bound.height))
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in state = value }
            .onEnded { value in commitScale(committedScale * value) }
    }

    /// Slider bindet direkt an den festgeschriebenen Zoom – wichtig, da
    /// `MagnificationGesture` auf dem Mac nur per Trackpad-Pinch auslöst und
    /// mit einer gewöhnlichen Maus sonst gar nicht erreichbar wäre.
    private var sliderZoomBinding: Binding<CGFloat> {
        Binding(get: { committedScale }, set: { commitScale($0) })
    }

    /// Nach jeder Zoom-Änderung (Geste ODER Slider) neu clampen: ein beim
    /// alten (größeren) Zoom gültiger Offset kann beim neuen (kleineren)
    /// Zoom außerhalb der Grenzen liegen.
    private func commitScale(_ newValue: CGFloat) {
        committedScale = min(max(newValue, 1), maxUserZoom)
        let bound = maxOffset(for: displayedImageSize(scale: committedScale))
        committedOffset = CGSize(width: min(max(committedOffset.width, -bound.width), bound.width),
                                  height: min(max(committedOffset.height, -bound.height), bound.height))
    }

    @MainActor
    private func commitCrop() {
        let renderScale = exportPixelSize / canvasSize
        let renderer = ImageRenderer(content: croppedSquareContent(scale: effectiveUserScale, offset: clampedOffset))
        renderer.scale = renderScale
        guard let outCGImage = renderer.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: outCGImage)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else { return }
        onCropped(data)
    }
}
