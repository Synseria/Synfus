import Foundation

/// Comparer un texte lu (OCR, saisie) à des noms connus malgré les fautes :
/// une forme normalisée commune, et une distance d'édition qui trouve un nom
/// **dans** une ligne. Pur ; partagé par la chasse (indices) et le suivi de
/// quêtes, qui lisent la même police avec les mêmes écorchures, et par les
/// fautes de frappe de la palette.
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
        private let paires: Paires

        init(_ normalise: String) {
            scalaires = normalise.unicodeScalars.map(\.value)
            var compte = [Int](repeating: 0, count: Self.cases)
            for valeur in scalaires { compte[Self.casier(valeur)] += 1 }
            self.compte = compte
            var paires = Paires()
            for (gauche, droite) in zip(scalaires, scalaires.dropFirst()) { paires.inserer(gauche, droite) }
            self.paires = paires
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
        /// `tolerance` ? Une édition brise au plus deux paires de caractères
        /// voisins du motif (lemme des q-grammes), et chaque caractère du
        /// motif absent du texte coûte au moins une édition.
        func tropLoin(de texte: Forme, tolerance: Int) -> Bool {
            if paires.absentes(de: texte.paires) > 2 * tolerance { return true }
            var manque = 0
            for indice in 0..<Self.cases where compte[indice] > texte.compte[indice] {
                manque += compte[indice] - texte.compte[indice]
                if manque > tolerance { return true }
            }
            return false
        }
    }

    /// Des paires de caractères voisins, hachées sur 256 bits : une paire
    /// dont le bit manque à l'autre texte n'y est pas. Quatre mots comparés
    /// écartent l'essentiel des six mille noms qu'une ligne lue ne porte pas.
    private struct Paires: Sendable {
        private var bits: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)

        mutating func inserer(_ gauche: UInt32, _ droite: UInt32) {
            let rang = Int((gauche &* 31 &+ droite) & 255)
            let bit = UInt64(1) << UInt64(rang & 63)
            switch rang >> 6 {
            case 0: bits.0 |= bit
            case 1: bits.1 |= bit
            case 2: bits.2 |= bit
            default: bits.3 |= bit
            }
        }

        func absentes(de autre: Paires) -> Int {
            (bits.0 & ~autre.bits.0).nonzeroBitCount + (bits.1 & ~autre.bits.1).nonzeroBitCount
                + (bits.2 & ~autre.bits.2).nonzeroBitCount + (bits.3 & ~autre.bits.3).nonzeroBitCount
        }
    }

    static func distanceDansTexte(_ motif: String, _ texte: String) -> Int {
        distanceDansTexte(Forme(motif), Forme(texte))
    }

    /// Le moins d'éditions (insertion, suppression, substitution d'un
    /// caractère) pour trouver `motif` quelque part dans `texte` : le début et
    /// la fin du texte sont gratuits (alignement semi-global de Sellers).
    static func distanceDansTexte(_ motif: Forme, _ texte: Forme) -> Int {
        distancePleine(motif.scalaires, texte.scalaires, debutGratuit: true)
    }

    /// `distanceDansTexte`, seulement si elle ne dépasse pas `auPlus` : la
    /// coupure d'Ukkonen ne calcule que les lignes du motif encore sous la
    /// borne, k colonnes au lieu de m — des milliers d'objectifs voisins
    /// (« Rapporter 1 âme de … ») par lecture du suivi.
    static func distanceDansTexte(_ motif: Forme, _ texte: Forme, auPlus k: Int) -> Int? {
        distanceBornee(motif, texte, auPlus: k, debutGratuit: true)
    }

    /// `distanceDansTexte(_:_:auPlus:)`, le motif calé au début du texte :
    /// seule la fin du texte est gratuite. Un titre ouvre sa ligne, les
    /// icônes le suivent ; un nom trouvé au milieu d'une ligne (« Charge »
    /// dans « de rechange ») n'en est pas le titre.
    static func distanceAuDebut(_ motif: Forme, _ texte: Forme, auPlus k: Int) -> Int? {
        distanceBornee(motif, texte, auPlus: k, debutGratuit: false)
    }

    private static func distanceBornee(_ motif: Forme, _ texte: Forme, auPlus k: Int, debutGratuit: Bool) -> Int? {
        let m = motif.scalaires
        // Effacer le motif entier coûte m : la borne ne coupe rien.
        guard m.count > k else {
            return distancePleine(m, texte.scalaires, debutGratuit: debutGratuit)
        }
        var colonne = Array(0...m.count)
        // La dernière ligne du motif dont la valeur tient sous la borne ; au-delà,
        // toutes la dépassent (une ligne vaut au plus son rang).
        var derniere = k
        var meilleur = k + 1
        for (rang, caractere) in texte.scalaires.enumerated() {
            // La ligne 0 : sauter le début du texte est gratuit, ou coûte ce qu'il saute.
            var diagonale = colonne[0]
            colonne[0] = debutGratuit ? 0 : rang + 1
            let limite = min(derniere + 1, m.count)
            for i in 1...limite {
                // Une ligne non calculée à la colonne précédente dépassait la borne.
                let gauche = i > derniere ? k + 1 : colonne[i]
                let valeur = min(diagonale + (m[i - 1] == caractere ? 0 : 1), gauche + 1, colonne[i - 1] + 1)
                diagonale = gauche
                colonne[i] = valeur
            }
            derniere = limite
            while derniere >= 0, colonne[derniere] > k { derniere -= 1 }
            // Calé au début, tout dépasse la borne une fois la ligne 0 au-delà.
            guard derniere >= 0 else { break }
            if derniere == m.count { meilleur = min(meilleur, colonne[m.count]) }
        }
        return meilleur <= k ? meilleur : nil
    }

    /// Une colonne par caractère du motif ; la ligne 0 vaut 0 partout quand
    /// le début du texte est gratuit, son rang sinon.
    private static func distancePleine(_ m: [UInt32], _ t: [UInt32], debutGratuit: Bool) -> Int {
        var colonne = Array(0...m.count)
        var meilleur = colonne[m.count]
        for (rang, caractere) in t.enumerated() {
            var diagonale = colonne[0]
            colonne[0] = debutGratuit ? 0 : rang + 1
            for i in stride(from: 1, through: m.count, by: 1) {
                let gauche = colonne[i]
                colonne[i] = min(diagonale + (m[i - 1] == caractere ? 0 : 1), gauche + 1, colonne[i - 1] + 1)
                diagonale = gauche
            }
            meilleur = min(meilleur, colonne[m.count])
        }
        return meilleur
    }
}
