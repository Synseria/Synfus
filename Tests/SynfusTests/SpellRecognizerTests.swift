import Testing
import Foundation
@testable import Synfus

/// La reconnaissance par corrélation, sur des icônes fabriquées : des formes
/// simples suffisent à vérifier que la bonne ressort, avec une marge, et que
/// la luminosité n'y change rien.
struct SpellRecognizerTests {

    /// Une « icône » : un motif géométrique sur fond sombre.
    private func icon(_ kind: Int, side: Int = 64, brightness: UInt8 = 220) -> LumaBitmap {
        var image = LumaBitmap(width: side, height: side, fill: 40)
        let s = CGFloat(side)
        switch kind {
        case 0: image.fill(CGRect(x: s * 0.2, y: s * 0.2, width: s * 0.6, height: s * 0.6), with: brightness)
        case 1: image.fill(CGRect(x: 0, y: s * 0.4, width: s, height: s * 0.2), with: brightness)
        case 2: image.fill(CGRect(x: s * 0.4, y: 0, width: s * 0.2, height: s), with: brightness)
        default:
            image.fill(CGRect(x: 0, y: 0, width: s * 0.5, height: s * 0.5), with: brightness)
            image.fill(CGRect(x: s * 0.5, y: s * 0.5, width: s * 0.5, height: s * 0.5), with: brightness)
        }
        return image
    }

    private var candidates: [SpellRecognizer.Candidate] {
        (0..<4).map { SpellRecognizer.candidate(id: 100 + $0, nom: "Sort \($0)", icon: icon($0)) }
    }

    @Test("La bonne icône ressort, nettement devant les autres")
    func bonneIcone() throws {
        // La case est plus grande que l'icône de référence, avec un cadre.
        var cell = LumaBitmap(width: 88, height: 88, fill: 200)
        let inner = icon(2, side: 80)
        for y in 0..<80 { for x in 0..<80 {
            cell.fill(CGRect(x: 4 + x, y: 4 + y, width: 1, height: 1), with: inner[x, y])
        } }
        let match = try #require(SpellRecognizer.identify(cell: cell, among: candidates))
        #expect(match.id == 102)
        #expect(match.isConfident)
    }

    @Test("Un sort grisé — même dessin, plus sombre — est reconnu pareil")
    func griseReconnu() throws {
        let dim = icon(1, brightness: 90)
        let match = try #require(SpellRecognizer.identify(cell: dim, among: candidates))
        #expect(match.id == 101)
        #expect(match.isConfident)
    }

    @Test("Une case vide n'a pas de forme : aucune confiance")
    func caseVide() throws {
        let empty = LumaBitmap(width: 64, height: 64, fill: 50)
        let match = try #require(SpellRecognizer.identify(cell: empty, among: candidates))
        #expect(!match.isConfident)
    }

    @Test("La corrélation d'une image avec elle-même vaut 1, avec son négatif −1")
    func correlation() {
        let a = icon(0)
        let negative = LumaBitmap(width: a.width, height: a.height, pixels: a.pixels.map { 255 - $0 })
        #expect(abs(SpellRecognizer.correlation(a, a) - 1) < 1e-9)
        #expect(abs(SpellRecognizer.correlation(a, negative) + 1) < 1e-9)
    }
}
