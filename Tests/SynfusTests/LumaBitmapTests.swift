import Testing
import CoreGraphics
import Foundation
import ImageIO
@testable import Synfus

/// La conversion CoreGraphics → gris doit garder la première ligne en haut.
struct LumaBitmapTests {
    @Test("La première ligne de l'image est la première ligne du bitmap")
    func orientation() throws {
        // 4 × 4 en gris : ligne du haut blanche, le reste noir.
        var pixels = [UInt8](repeating: 0, count: 16)
        for x in 0..<4 { pixels[x] = 255 }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: 4, height: 4, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let luma = try #require(LumaBitmap(cgImage: image))
        #expect(luma[0, 0] == 255)
        #expect(luma[0, 3] == 0)
    }

    /// Le tour passe la capture à l'OCR telle quelle ; le calibrage la garde en
    /// PNG et relit ce fichier. L'essai du calibrage ne vaut que si les deux
    /// voient les mêmes pixels.
    @Test("Le PNG du calibrage rend les pixels que le tour lit sur la capture")
    func pngDuCalibrage() throws {
        let (w, h) = (64, 24)
        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        var graine: UInt32 = 7
        for i in stride(from: 0, to: rgba.count, by: 4) {
            graine = graine &* 1_664_525 &+ 1_013_904_223
            rgba[i] = UInt8(truncatingIfNeeded: graine >> 24)
            rgba[i + 1] = UInt8(truncatingIfNeeded: graine >> 16)
            rgba[i + 2] = UInt8(truncatingIfNeeded: graine >> 8)
        }
        let espace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let contexte = try #require(CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                              space: espace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let capture = try #require(contexte.makeImage())
        let png = try #require(CapturesCalibrage.png(capture))
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        let relue = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(LumaBitmap(cgImage: relue) == LumaBitmap(cgImage: capture))
    }
}
