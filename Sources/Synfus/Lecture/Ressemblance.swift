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

    /// Un texte normalisé prêt à comparer, à préparer une fois par nom
    /// connu : comparer des milliers de noms à chaque ligne lue ne coûte
    /// alors presque que la borne basse (`tropLoin`).
    struct Forme: Sendable {
        let scalaires: [UInt32]
        /// Combien de chaque lettre (a-z), chiffre, espace, autre.
        private let compte: [Int]

        init(_ normalise: String) {
            scalaires = normalise.unicodeScalars.map(\.value)
            var compte = [Int](repeating: 0, count: Self.cases)
            for valeur in scalaires { compte[Self.casier(valeur)] += 1 }
            self.compte = compte
        }

        var longueur: Int { scalaires.count }

        private static let cases = 38

        private static func casier(_ valeur: UInt32) -> Int {
            switch valeur {
            case 97...122: return Int(valeur - 97)
            case 48...57: return 26 + Int(valeur - 48)
            case 32: return 36
            default: return 37
            }
        }

        /// `distanceDansTexte(self, texte)` dépasse-t-elle sûrement
        /// `tolerance` ? Chaque caractère du motif absent du texte coûte au
        /// moins une édition.
        func tropLoin(de texte: Forme, tolerance: Int) -> Bool {
            var manque = 0
            for indice in 0..<Self.cases where compte[indice] > texte.compte[indice] {
                manque += compte[indice] - texte.compte[indice]
                if manque > tolerance { return true }
            }
            return false
        }
    }

    static func distanceDansTexte(_ motif: String, _ texte: String) -> Int {
        distanceDansTexte(Forme(motif), Forme(texte))
    }

    /// Le moins d'éditions (insertion, suppression, substitution d'un
    /// caractère) pour trouver `motif` quelque part dans `texte` : le début et
    /// la fin du texte sont gratuits (alignement semi-global de Sellers).
    static func distanceDansTexte(_ motif: Forme, _ texte: Forme) -> Int {
        let m = motif.scalaires, t = texte.scalaires
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

    /// `distanceDansTexte`, seulement si elle ne dépasse pas `auPlus` : la
    /// coupure d'Ukkonen ne calcule que les lignes du motif encore sous la
    /// borne, k colonnes au lieu de m — des milliers d'objectifs voisins
    /// (« Rapporter 1 âme de … ») par lecture du suivi.
    static func distanceDansTexte(_ motif: Forme, _ texte: Forme, auPlus k: Int) -> Int? {
        let m = motif.scalaires
        guard m.count > k else { return distanceDansTexte(motif, texte) }
        var colonne = Array(0...m.count)
        // La dernière ligne du motif dont la valeur tient sous la borne ; au-delà,
        // toutes la dépassent (une ligne vaut au plus son rang).
        var derniere = k
        var meilleur = k + 1
        for caractere in texte.scalaires {
            var diagonale = 0
            let limite = min(derniere + 1, m.count)
            for i in 1...limite {
                // Une ligne non calculée à la colonne précédente dépassait la borne.
                let gauche = i > derniere ? k + 1 : colonne[i]
                let valeur = min(diagonale + (m[i - 1] == caractere ? 0 : 1), gauche + 1, colonne[i - 1] + 1)
                diagonale = gauche
                colonne[i] = valeur
            }
            derniere = limite
            while colonne[derniere] > k { derniere -= 1 }
            if derniere == m.count { meilleur = min(meilleur, colonne[m.count]) }
        }
        return meilleur <= k ? meilleur : nil
    }
}
