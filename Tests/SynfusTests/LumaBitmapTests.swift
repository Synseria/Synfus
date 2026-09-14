import Testing
import CoreGraphics
import Foundation
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
}
