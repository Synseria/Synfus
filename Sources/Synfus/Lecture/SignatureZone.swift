import CoreGraphics
import Foundation

/// Ce qui décide de relancer l'OCR : le texte clair, et pour le bouton de
/// combat, sa couleur — le même « Fin de tour » blanc passe du gris à la
/// couleur sans qu'un pixel clair ne bouge.
struct SignatureZone: Equatable, Sendable {
    let empreinte: EmpreinteTexte
    /// Part colorée de la zone entière, pour les zones où la couleur compte.
    let couleur: Double?

    func semblable(a autre: SignatureZone) -> Bool {
        guard empreinte.semblable(a: autre.empreinte) else { return false }
        guard let couleur, let autre = autre.couleur else { return true }
        return (couleur >= LectureCombat.seuilSignature) == (autre >= LectureCombat.seuilSignature)
    }
}

/// Empreinte de ce qui est **écrit** dans une imagette : les seuls pixels
/// clairs — le texte du jeu est blanc cerné de sombre —, réduits à une grille.
///
/// C'est elle qui rend la lecture en continu gratuite : la position ne change
/// qu'au changement de carte, et une capture dont l'empreinte n'a pas bougé
/// ne repasse pas par l'OCR. Le décor qui bouge derrière le texte (feuillage,
/// persos qui passent) est sombre ou coloré, il ne franchit pas le seuil.
struct EmpreinteTexte: Equatable, Sendable {
    static let colonnes = 96
    static let lignes = 24
    /// Luminance au-delà de laquelle un pixel compte comme du texte.
    static let seuil: UInt8 = 225
    /// Part de pixels clairs qui allume une case.
    static let remplissage = 0.08
    /// Cases qui peuvent différer sans que le texte ait changé.
    static let tolerance = 6

    let cases: [Bool]

    init(cases: [Bool]) { self.cases = cases }

    init(_ image: LumaBitmap) {
        let (w, h) = (image.width, image.height)
        var cases = [Bool](repeating: false, count: Self.colonnes * Self.lignes)
        guard w > 0, h > 0 else { self.init(cases: cases); return }
        for cy in 0..<Self.lignes {
            let y0 = cy * h / Self.lignes, y1 = max(y0 + 1, (cy + 1) * h / Self.lignes)
            for cx in 0..<Self.colonnes {
                let x0 = cx * w / Self.colonnes, x1 = max(x0 + 1, (cx + 1) * w / Self.colonnes)
                var clairs = 0
                for y in y0..<min(y1, h) {
                    for x in x0..<min(x1, w) where image.pixels[y * w + x] >= Self.seuil { clairs += 1 }
                }
                let aire = (min(y1, h) - y0) * (min(x1, w) - x0)
                cases[cy * Self.colonnes + cx] = Double(clairs) >= Double(aire) * Self.remplissage
            }
        }
        self.init(cases: cases)
    }

    /// Même texte, au bruit près.
    func semblable(a autre: EmpreinteTexte) -> Bool {
        guard cases.count == autre.cases.count else { return false }
        return zip(cases, autre.cases).lazy.filter { $0 != $1 }.count <= Self.tolerance
    }
}
