import Foundation

/// Le texte de l'atelier de forgemagie tel que l'OCR le rend : l'en-tête
/// (« reliquat : 0 ») et les lignes de l'historique (« Échec », « 3 Chance »
/// en vert, « -10 Chance » en rouge — un gain s'écrit sans « + »). Pur.
enum TexteFM {
    /// Une entrée de l'historique, la plus récente en bas.
    enum Entree: Equatable, Sendable {
        case echec
        /// Une ligne qui a changé de `points` (négatif : une perte).
        case ligne(points: Int, nom: String)
        /// Du puits gagné ou consommé.
        case reliquat(Double)
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
        if plie.wholeMatch(of: /e?chec|failure|fracaso/) != nil { return .echec }
        // L'OCR lit le signe moins en tiret long, ou le colle au nombre.
        guard let match = texte.wholeMatch(of: /([+\-−–]?)\s*(\d+(?:[.,]\d+)?)\s+(\p{L}[\p{L}\s'%.-]*)/) else { return nil }
        let negatif = !match.1.isEmpty && match.1 != "+"
        let nom = String(match.3).trimmingCharacters(in: .whitespaces)
        if nom.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) == "reliquat",
           let valeur = Double(match.2.replacing(",", with: ".")) {
            return .reliquat(negatif ? -valeur : valeur)
        }
        guard let points = Int(match.2) else { return nil }
        return .ligne(points: negatif ? -points : points, nom: nom)
    }

    /// Les entrées lisibles d'une colonne d'historique, de haut en bas.
    static func historique(_ lignes: [String]) -> [Entree] { lignes.compactMap(entree) }
}
