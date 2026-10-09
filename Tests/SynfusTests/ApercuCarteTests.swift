import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Synfus

/// Où se pose la vue agrandie d'une carte : à côté de la fenêtre de sa
/// vignette, sinon à gauche de la souris, toujours dans l'écran. Et la taille
/// à laquelle ses images se décodent.
struct ApercuCarteTests {
    private let ecran = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let taille = NSSize(width: 638, height: 438)

    private func x(fenetre: NSRect?, souris: NSPoint = NSPoint(x: 1000, y: 450)) -> CGFloat {
        ApercuCarte.cadre(taille: taille, fenetre: fenetre, souris: souris, ecran: ecran).minX
    }

    @Test("À gauche de la fenêtre s'il y a la place, à droite sinon")
    func cotes() {
        #expect(x(fenetre: NSRect(x: 700, y: 300, width: 360, height: 480)) == 54)
        #expect(x(fenetre: NSRect(x: 100, y: 300, width: 360, height: 480)) == 468)
    }

    @Test("Sans place à côté de la fenêtre, ni de fenêtre connue : à gauche de la souris, dans l'écran")
    func souris() {
        let palette = NSRect(x: 390, y: 400, width: 660, height: 400)
        #expect(x(fenetre: palette) == 338)  // 1000 − 3 × 8 − 638
        #expect(x(fenetre: nil, souris: NSPoint(x: 300, y: 450)) == 0)
    }

    @Test("À hauteur de la souris, sans sortir de l'écran")
    func hauteur() {
        let haut = ApercuCarte.cadre(taille: taille, fenetre: nil, souris: NSPoint(x: 1000, y: 890), ecran: ecran)
        #expect(haut.maxY == ecran.maxY)
        let milieu = ApercuCarte.cadre(taille: taille, fenetre: nil, souris: NSPoint(x: 1000, y: 450), ecran: ecran)
        #expect(milieu.midY == 450)
    }

    /// Un JPEG de 300 × 150, dessiné en mémoire.
    private static func jpeg() throws -> Data {
        let contexte = try #require(CGContext(data: nil, width: 300, height: 150, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        contexte.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.4, alpha: 1))
        contexte.fill(CGRect(x: 0, y: 0, width: 300, height: 150))
        let image = try #require(contexte.makeImage())
        let sortie = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(sortie, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return sortie as Data
    }

    @Test("Une image de DofusDB décodée réduite à son côté, jamais agrandie ; entière sans côté")
    func decodage() throws {
        let donnees = try Self.jpeg()
        let reduite = try #require(ImagesDofusDB.decoder(donnees, cote: 64))
        #expect(reduite.width == 64 && reduite.height == 32)
        #expect(ImagesDofusDB.decoder(donnees, cote: 1000)?.width == 300)
        #expect(ImagesDofusDB.decoder(donnees, cote: nil).map { [$0.width, $0.height] } == [300, 150])
        #expect(ImagesDofusDB.decoder(Data("pas une image".utf8), cote: 64) == nil)
    }
}
