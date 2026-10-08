import Foundation

/// Comparer un texte lu (OCR, saisie) à des noms connus malgré les fautes :
/// une forme normalisée commune, et une distance d'édition qui trouve un nom
/// **dans** une ligne. Pur ; partagé par la chasse (indices) et le suivi de
/// quêtes, qui lisent la même police avec les mêmes écorchures.
enum Ressemblance {
    /// Sans accents ni casse, ligatures dépliées, ponctuation réduite à un
    /// espace : « Crâne » et « crane », « Œuf » et « oeuf », « Pense-bête »
    /// et « Pense bete » se valent.
    static func normaliser(_ texte: String) -> String {
        let plie = texte
            .replacingOccurrences(of: "œ", with: "oe").replacingOccurrences(of: "Œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae").replacingOccurrences(of: "Æ", with: "ae")
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
        let mots = plie.split { !($0.isLetter || $0.isNumber) }
        return mots.joined(separator: " ")
    }

    /// Le moins d'éditions (insertion, suppression, substitution d'un
    /// caractère) pour trouver `motif` quelque part dans `texte` : le début et
    /// la fin du texte sont gratuits (alignement semi-global de Sellers).
    static func distanceDansTexte(_ motif: String, _ texte: String) -> Int {
        let m = Array(motif), t = Array(texte)
        guard !m.isEmpty else { return 0 }
        guard !t.isEmpty else { return m.count }
        // Une colonne par caractère du motif ; la ligne 0 vaut 0 partout.
        var precedente = Array(0...m.count)
        var meilleur = precedente[m.count]
        var courante = [Int](repeating: 0, count: m.count + 1)
        for caractere in t {
            courante[0] = 0
            for i in 1...m.count {
                let substitution = precedente[i - 1] + (m[i - 1] == caractere ? 0 : 1)
                courante[i] = min(substitution, precedente[i] + 1, courante[i - 1] + 1)
            }
            meilleur = min(meilleur, courante[m.count])
            swap(&precedente, &courante)
        }
        return meilleur
    }
}
