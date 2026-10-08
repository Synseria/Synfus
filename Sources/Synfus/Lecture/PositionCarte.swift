import CoreGraphics
import Foundation

/// La position du perso — les coordonnées de sa carte —, décodée des lignes
/// que l'OCR lit en haut à gauche de la fenêtre. Pur : on lui donne du texte,
/// il rend une position, sans rien lire lui-même (comme `WindowTitle`).
///
/// Le jeu affiche, sous le nom de la zone :
///
///     Montagne des Koalaks (Village des Éleveurs)
///     -16, 1 - Niveau 1
///
/// La première ligne qui commence par deux entiers séparés d'une virgule porte
/// la position ; la ligne qui la précède, si elle a des lettres, nomme la zone.
struct PositionCarte: Equatable, Sendable {
    let x: Int
    let y: Int
    /// Le nom de la zone, tel que lu — l'OCR le tronque parfois, il n'est là
    /// que pour être montré.
    let zone: String?

    var coordonnees: String { Coordonnees.texte(x, y) }

    /// Au-delà, ce n'est pas une coordonnée de carte mais une erreur de lecture.
    static let borne = 200

    /// Les tirets que l'OCR substitue au signe moins — mesuré : « →16 » pour
    /// « -16 » en pleine résolution.
    private static let moins: Set<Character> = ["-", "−", "–", "—", "→", "~", "‐", "‑"]

    static func lire(_ lignes: [String]) -> PositionCarte? {
        for (rang, ligne) in lignes.enumerated() {
            guard let (x, y) = coordonnees(dans: ligne) else { continue }
            let zone = rang > 0 ? nomDeZone(lignes[rang - 1]) : nil
            return PositionCarte(x: x, y: y, zone: zone)
        }
        return nil
    }

    /// « -16, 1 - Niveau 1 » → (-16, 1). La ligne doit **commencer** par la
    /// paire : ailleurs, deux nombres séparés d'une virgule sont une phrase.
    static func coordonnees(dans ligne: String) -> (Int, Int)? {
        var reste = Substring(ligne.trimmingCharacters(in: .whitespaces))
        guard let x = entier(&reste) else { return nil }
        sauterBlancs(&reste)
        // La virgule, que l'OCR lit parfois en point.
        guard let separateur = reste.first, separateur == "," || separateur == "." else { return nil }
        reste = reste.dropFirst()
        sauterBlancs(&reste)
        guard let y = entier(&reste), abs(x) <= borne, abs(y) <= borne else { return nil }
        return (x, y)
    }

    private static func entier(_ texte: inout Substring) -> Int? {
        var negatif = false
        if let premier = texte.first, moins.contains(premier) {
            negatif = true
            texte = texte.dropFirst()
            sauterBlancs(&texte)
        }
        let chiffres = texte.prefix { $0.isASCII && $0.isNumber }
        guard !chiffres.isEmpty, chiffres.count <= 3, let valeur = Int(chiffres) else { return nil }
        texte = texte.dropFirst(chiffres.count)
        return negatif ? -valeur : valeur
    }

    private static func sauterBlancs(_ texte: inout Substring) {
        texte = texte.drop { $0 == " " }
    }

    private static func nomDeZone(_ ligne: String) -> String? {
        // Le point final est celui d'un nom tronqué par l'OCR ; la parenthèse
        // fermante, elle, appartient au nom.
        var propre = ligne.trimmingCharacters(in: .whitespaces)
        while let dernier = propre.last, ".…,;:".contains(dernier) { propre.removeLast() }
        guard propre.count >= 3, propre.contains(where: \.isLetter) else { return nil }
        return propre
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
