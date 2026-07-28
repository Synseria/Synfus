import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Générateur des images de l'icône. Compilé par `Tools/generate-app-icons.sh`
// AVEC la source réelle de l'app (`Sources/Synfus/SynfusMark.swift`) : le bundle
// et l'app dessinent donc rigoureusement la même marque, il n'y a pas de second
// dessin à maintenir.

/// Une définition de l'`iconset` : nom de fichier, côté en pixels, cadrage.
private struct Slot {
    let filename: String
    let pixels: Int
    let shape: SynfusMark.Shape
}

private let slots: [Slot] = [
    .init(filename: "icon_16x16.png", pixels: 16, shape: .rounded),
    .init(filename: "icon_16x16@2x.png", pixels: 32, shape: .rounded),
    .init(filename: "icon_32x32.png", pixels: 32, shape: .rounded),
    .init(filename: "icon_32x32@2x.png", pixels: 64, shape: .rounded),
    .init(filename: "icon_128x128.png", pixels: 128, shape: .rounded),
    .init(filename: "icon_128x128@2x.png", pixels: 256, shape: .rounded),
    .init(filename: "icon_256x256.png", pixels: 256, shape: .rounded),
    .init(filename: "icon_256x256@2x.png", pixels: 512, shape: .rounded),
    .init(filename: "icon_512x512.png", pixels: 512, shape: .rounded),
    .init(filename: "icon_512x512@2x.png", pixels: 1024, shape: .rounded),
]

private func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw NSError(domain: "AppIconExport", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Destination PNG refusée : \(url.path)",
        ])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "AppIconExport", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Écriture PNG échouée : \(url.path)",
        ])
    }
}

@main
enum AppIconExport {
    /// Arguments : `<dossier iconset> <PNG de référence>`.
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            fail("usage: AppIconExport <Synfus.iconset> <Synfus.png>", code: 2)
        }
        let iconset = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let reference = URL(fileURLWithPath: arguments[2])

        do {
            try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
            for slot in slots {
                guard let image = SynfusMark.image(pixelSize: slot.pixels, shape: slot.shape) else {
                    throw NSError(domain: "AppIconExport", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "Rendu impossible à \(slot.pixels) px",
                    ])
                }
                try write(image, to: iconset.appendingPathComponent(slot.filename))
            }
            // PNG de référence, hors iconset : ce que l'on regarde pour juger le
            // dessin, et ce que le README peut montrer.
            guard let grand = SynfusMark.image(pixelSize: 1024, shape: .rounded) else {
                throw NSError(domain: "AppIconExport", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Rendu 1024 px impossible",
                ])
            }
            try write(grand, to: reference)
            print("  \(slots.count) définitions + \(reference.lastPathComponent)")
        } catch {
            fail(error.localizedDescription, code: 1)
        }
    }

    private static func fail(_ message: String, code: Int32) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(code)
    }
}
