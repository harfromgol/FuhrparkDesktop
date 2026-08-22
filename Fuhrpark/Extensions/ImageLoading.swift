import CoreImage
import ImageIO

/// Lädt Bilddaten EXIF-sicher als aufrechtes `CGImage`.
enum ImageLoading {
    /// `NSImage.size` beruht auf eingebetteten DPI-Metadaten statt auf
    /// echten Pixelmaßen, und `NSImage` dreht JPEGs nicht automatisch nach
    /// ihrem EXIF-Orientierungs-Tag – ein Foto aus der Fotos-App/Kamera käme
    /// sonst seitlich verdreht heraus. Deshalb hier über `CGImageSource`
    /// laden (liefert reale Pixelmaße) und die Orientierung einmalig über
    /// Core Image „einbrennen“, damit alle nachfolgende Zuschnitt-Geometrie
    /// mit echten, aufrechten Pixelmaßen rechnen kann.
    static func normalizedCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = props?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        guard let orientation = CGImagePropertyOrientation(rawValue: raw), orientation != .up else {
            return cgImage
        }
        let oriented = CIImage(cgImage: cgImage).oriented(orientation)
        return CIContext().createCGImage(oriented, from: oriented.extent)
    }
}
