import CoreGraphics
import Foundation
import ImageIO
@testable import Synfus

/// Ce que ScreenCaptureKit rendrait d'une zone, rejoué sur le PNG d'une
/// fenêtre entière en Retina (`~/Library/Logs/Synfus/captures`) : la géométrie
/// de la lecture (`GeometrieCapture`, barre de titre de 28 points), le
/// rééchantillonnage par CoreGraphics.
enum SimulationCapture {
    static func charger(_ chemin: String) -> CGImage? {
        let url = URL(fileURLWithPath: (chemin as NSString).expandingTildeInPath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// La zone capturée seule ; `.entiere` donne le contenu entier.
    static func zone(_ zone: ZoneEcran, dans pleine: CGImage, pleinEcran: Bool) -> CGImage? {
        let points = CGSize(width: CGFloat(pleine.width) / 2, height: CGFloat(pleine.height) / 2)
        let geometrie = GeometrieCapture(fenetre: points, region: zone.rect,
                                         contenu: CaptureContenu(pleinEcran: pleinEcran, normaliser: true),
                                         maxWidth: nil, natif: 2, barreTitre: 28)
        guard let source = geometrie.source,
              let coin = pleine.cropping(to: CGRect(x: source.minX * 2, y: source.minY * 2,
                                                    width: source.width * 2, height: source.height * 2).integral),
              let contexte = CGContext(data: nil, width: geometrie.largeur, height: geometrie.hauteur,
                                       bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        contexte.interpolationQuality = .high
        contexte.draw(coin, in: CGRect(x: 0, y: 0, width: geometrie.largeur, height: geometrie.hauteur))
        return contexte.makeImage()
    }
}
