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

    static func garder(_ png: Data, pour genre: GenreLecture) throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try png.write(to: fichier(genre), options: .atomic)
    }

    static func gardee(_ genre: GenreLecture) -> Capture? {
        let url = fichier(genre)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return Capture(image: image, date: date ?? .distantPast)
    }

    /// La zone découpée dans une capture du contenu entier, en PNG.
    static func decouper(_ zone: ZoneEcran, dans image: CGImage) -> Data? {
        let rect = zone.pixels(dans: CGSize(width: image.width, height: image.height))
        guard let coupe = image.cropping(to: rect) else { return nil }
        let donnees = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(donnees, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, coupe, nil)
        return CGImageDestinationFinalize(destination) ? donnees as Data : nil
    }
}
