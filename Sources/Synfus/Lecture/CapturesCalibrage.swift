import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Les captures du calibrage, une par genre de lecture : le contenu du jeu au
/// moment où l'élément était à l'écran — un combat, une chasse, le suivi de
/// quêtes ouvert —, pour recalibrer plus tard sans attendre qu'il revienne.
/// Visuels du jeu : dans les caches de l'utilisateur, jamais dans le dépôt
/// (CGU Dofus, art. 13.2).
///
/// Le contenu y est à l'échelle de la lecture (`ZoneEcran.hauteurReference`) :
/// une zone découpée dedans est, au pixel près, ce que le tour capturerait.
enum CapturesCalibrage {
    struct Capture {
        let image: CGImage
        let date: Date
    }

    /// `~/Library/Caches/Synfus/Calibrage`
    static let dossier = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "Synfus/Calibrage", directoryHint: .isDirectory)

    static func fichier(_ genre: GenreLecture) -> URL {
        dossier.appending(path: "\(genre.rawValue).png", directoryHint: .notDirectory)
    }

    /// Le seul PNG de la lecture : la capture qui reste sur disque. Le tour
    /// passe la sienne à l'OCR telle quelle.
    static func garder(_ image: CGImage, pour genre: GenreLecture) throws {
        guard let donnees = png(image) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try donnees.write(to: fichier(genre), options: .atomic)
    }

    static func png(_ image: CGImage) -> Data? {
        let donnees = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(donnees, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? donnees as Data : nil
    }

    static func gardee(_ genre: GenreLecture) -> Capture? {
        let url = fichier(genre)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return Capture(image: image, date: date ?? .distantPast)
    }

    /// Une image redessinée dans sa propre mémoire : une découpe partage les
    /// pixels de l'image entière, et la garder la garderait tout entière.
    static func copie(_ image: CGImage) -> CGImage? {
        guard let contexte = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                       bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        contexte.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return contexte.makeImage()
    }

    /// La zone découpée dans une capture du contenu entier.
    static func decouper(_ zone: ZoneEcran, dans image: CGImage) -> CGImage? {
        image.cropping(to: zone.pixels(dans: CGSize(width: image.width, height: image.height)))
    }
}
