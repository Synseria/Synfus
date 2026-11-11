import CoreGraphics
import Foundation
import Testing
@testable import Synfus

/// Le choix de l'icône de l'app : sa sauvegarde et le rendu de chaque variante.
struct IconeAppTests {

    @Test("Une icône s'écrit en motif et fond, et se relit")
    func allerRetour() throws {
        let ecrite = try JSONEncoder().encode(IconeApp(motif: .couvee, fond: .aube))
        let objet = try JSONSerialization.jsonObject(with: ecrite) as? [String: String]
        #expect(objet == ["motif": "couvee", "fond": "aube"])
        for icone in IconeApp.toutes {
            #expect(try JSONDecoder().decode(IconeApp.self, from: JSONEncoder().encode(icone)) == icone)
        }
    }

    @Test("Un motif ou un fond inconnu reprend le défaut, champ par champ")
    func valeurInconnue() throws {
        let lue = try JSONDecoder().decode(IconeApp.self, from: Data(#"{"motif":"phenix","fond":"aube"}"#.utf8))
        #expect(lue == IconeApp(motif: IconeApp.parDefaut.motif, fond: .aube))
        let vide = try JSONDecoder().decode(IconeApp.self, from: Data("{}".utf8))
        #expect(vide == .parDefaut)
    }

    @Test("Huit variantes, le défaut parmi elles")
    func toutes() {
        #expect(Set(IconeApp.toutes).count == 8)
        #expect(IconeApp.toutes.first == .duBundle)
        #expect(IconeApp.toutes.contains(.parDefaut))
    }

    /// L'opacité de chaque pixel d'un rendu, relu dans un bitmap connu.
    private func alphas(_ image: CGImage) throws -> [UInt8] {
        let cote = image.width
        var pixels = [UInt8](repeating: 0, count: cote * cote * 4)
        let espace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { tampon in
            let ctx = try #require(CGContext(data: tampon.baseAddress, width: cote, height: cote, bitsPerComponent: 8,
                                             bytesPerRow: cote * 4, space: espace,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: cote, height: cote))
        }
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    @Test("Chaque variante rend une image pleine en 16 et en 1024 px, les coins vides",
          arguments: IconeApp.toutes, [16, 1024])
    func rendu(icone: IconeApp, cote: Int) throws {
        let image = try #require(SynfusMark.image(pixelSize: cote, icone: icone))
        #expect(image.width == cote && image.height == cote)
        let opacite = try alphas(image)
        let pleins = opacite.filter { $0 > 200 }.count
        #expect(Double(pleins) / Double(opacite.count) > 0.2, "\(icone) en \(cote) px : \(pleins) pixels pleins")
        #expect(opacite[0] == 0 && opacite[opacite.count - 1] == 0, "\(icone) en \(cote) px : un coin est peint")
    }
}
