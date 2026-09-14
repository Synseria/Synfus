import CoreGraphics
import Foundation
import ImageIO

/// Une image en niveaux de gris, en mémoire, ligne par ligne — la matière
/// première de la reconnaissance. Une struct de valeurs : elle traverse les
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

    init(width: Int, height: Int, fill: UInt8 = 0) {
        self.init(width: width, height: height, pixels: Array(repeating: fill, count: width * height))
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
        // CoreGraphics dessine l'origine en bas : on remet la première ligne en haut.
        var flipped = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            flipped.replaceSubrange(y * width..<(y + 1) * width,
                                    with: pixels[(height - 1 - y) * width..<(height - y) * width])
        }
        self.init(width: width, height: height, pixels: flipped)
    }

    /// Un PNG (ou tout format lu par ImageIO) du disque.
    init?(contentsOf url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        self.init(cgImage: image)
    }

    subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
    }

    /// Une sous-image, bornée à l'image.
    func cropped(to rect: CGRect) -> LumaBitmap {
        let x0 = max(0, Int(rect.minX)), y0 = max(0, Int(rect.minY))
        let x1 = min(width, Int(rect.maxX.rounded())), y1 = min(height, Int(rect.maxY.rounded()))
        guard x1 > x0, y1 > y0 else { return LumaBitmap(width: 0, height: 0, pixels: []) }
        var out: [UInt8] = []
        out.reserveCapacity((x1 - x0) * (y1 - y0))
        for y in y0..<y1 { out.append(contentsOf: pixels[y * width + x0..<y * width + x1]) }
        return LumaBitmap(width: x1 - x0, height: y1 - y0, pixels: out)
    }

    /// Redimensionnée par moyenne de zones — ce qu'il faut pour comparer deux
    /// imagettes de tailles différentes, sans dépendre de CoreGraphics.
    func resized(to side: Int) -> LumaBitmap {
        guard width > 0, height > 0, side > 0 else { return LumaBitmap(width: 0, height: 0, pixels: []) }
        var out = [UInt8](repeating: 0, count: side * side)
        for ty in 0..<side {
            let y0 = ty * height / side, y1 = max(y0 + 1, (ty + 1) * height / side)
            for tx in 0..<side {
                let x0 = tx * width / side, x1 = max(x0 + 1, (tx + 1) * width / side)
                var sum = 0
                for y in y0..<y1 { for x in x0..<x1 { sum += Int(pixels[y * width + x]) } }
                out[ty * side + tx] = UInt8(sum / ((y1 - y0) * (x1 - x0)))
            }
        }
        return LumaBitmap(width: side, height: side, pixels: out)
    }

    /// Dessine un rectangle plein — pour fabriquer des images de test.
    mutating func fill(_ rect: CGRect, with value: UInt8) {
        var p = pixels
        for y in max(0, Int(rect.minY))..<min(height, Int(rect.maxY)) {
            for x in max(0, Int(rect.minX))..<min(width, Int(rect.maxX)) { p[y * width + x] = value }
        }
        self = LumaBitmap(width: width, height: height, pixels: p)
    }
}
