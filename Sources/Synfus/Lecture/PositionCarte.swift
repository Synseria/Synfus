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
    /// Le nom de la zone, tel que lu — l'OCR le tronque parfois : montré, et
    /// lu seulement pour sa région (`horsDuMondeDesDouze`).
    let zone: String?
    /// Tranché une fois, à la lecture : les distances de la palette et de la
    /// barre le redemandent pour chaque entrée, et la règle compare une
    /// trentaine de noms sans accents ni casse (`ItineraireZaap`).
    let horsDuMondeDesDouze: Bool

    init(x: Int, y: Int, zone: String?) {
        self.x = x
        self.y = y
        self.zone = zone
        horsDuMondeDesDouze = ItineraireZaap.horsDuMondeDesDouze(zone)
    }

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
