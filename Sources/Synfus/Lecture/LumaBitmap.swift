import CoreGraphics
import Foundation

/// Une image en niveaux de gris, en mémoire, ligne par ligne — ce que la
/// lecture de l'écran mesure. Une struct de valeurs : elle traverse les
/// frontières d'isolation et se fabrique en test sans CoreGraphics.
struct LumaBitmap: Sendable, Equatable {
    let width: Int
    let height: Int
    /// `height` lignes de `width` octets, 0 = noir.
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Rendu en gris 8 bits par CoreGraphics — la conversion sRGB → luma est
    /// la sienne, pas la nôtre.
    init?(cgImage: CGImage) {
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { return nil }
        // La mémoire d'un contexte bitmap commence par la ligne du **haut** :
        // pas de retournement — `LumaBitmapTests` le vérifie : une inversion
        // silencieuse ferait mesurer le bas de la zone pour son haut.
        self.init(width: width, height: height, pixels: pixels)
    }

    subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
    }
}
