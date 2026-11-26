import Foundation

/// Le texte de l'atelier de forgemagie tel que l'OCR le rend : l'en-tête
/// (« reliquat : 0 ») et les lignes de l'historique (« Échec », « 3 Chance »
/// en vert, « -10 Chance » en rouge — un gain s'écrit sans « + » ; « + reliquat »
/// et « - reliquat », sans nombre). L'icône devant une ligne se lit en
/// caractères parasites (« • », « > », « 3 », « - ») : seul compte le nombre
/// collé au nom, et son signe s'il lui est collé. Pur.
enum TexteFM {
    /// Une entrée de l'historique, la plus récente en bas.
    enum Entree: Equatable, Sendable {
        case echec
        /// Une ligne qui a changé de `points` (négatif : une perte), en
        /// pourcentage pour « 2% Résistance Feu ».
        case ligne(points: Int, nom: String, pourcent: Bool)
        /// Du puits gagné (`true`) ou consommé ; le jeu n'en dit pas la quantité.
        case reliquat(gagne: Bool)
    }

    /// « reliquat : 0 », « Reliquat: 12,5 » ; `nil` sans reliquat lisible.
    static func reliquat(_ lignes: [String]) -> Double? {
        for ligne in lignes {
            let texte = ligne.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            if let match = texte.firstMatch(of: /reliquat\s*[:;.]?\s*(-?\d+(?:[.,]\d+)?)/) {
                return Double(match.1.replacing(",", with: "."))
            }
        }
        return nil
    }

    /// Une ligne de l'historique ; `nil` pour ce qui n'en est pas une
    /// (« Il n'y a pas d'historique actuellement. », pied de colonne).
    static func entree(_ ligne: String) -> Entree? {
        let texte = ligne.trimmingCharacters(in: .whitespaces)
        let plie = texte.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        if plie.wholeMatch(of: /\W*(e?chec|failure|fracaso)\W*/) != nil { return .echec }
        if let signe = plie.wholeMatch(of: /\W*?([+\-−–])\s*(reliquat|remainder|remanente)\W*/) {
            return .reliquat(gagne: signe.1 == "+")
        }
        // Le plus court préfixe parasite d'abord : le nombre retenu est le
        // dernier avant le nom. Le signe compte collé au nombre (« -4 Pods »),
        // pas séparé de lui (« - 7% Critique », une icône).
        guard let match = texte.wholeMatch(of: /.*?([+\-−–]?)(\d+)\s*(%?)\s+(\p{L}[\p{L}\d\s'.-]*)/),
              let points = Int(match.2) else { return nil }
        let negatif = !match.1.isEmpty && match.1 != "+"
        let nom = String(match.4).trimmingCharacters(in: .whitespaces)
        return .ligne(points: negatif ? -points : points, nom: nom, pourcent: !match.3.isEmpty)
    }

    /// Les entrées lisibles d'une colonne d'historique, de haut en bas.
    static func historique(_ lignes: [String]) -> [Entree] { lignes.compactMap(entree) }
}
