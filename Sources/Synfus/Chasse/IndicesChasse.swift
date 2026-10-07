import Foundation

/// Un indice de chasse au trésor — un repère du décor que l'on cherche de
/// carte en carte. L'identifiant est celui de DofusDB (`point-of-interest`).
struct Indice: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    /// Par code de langue (`fr`, `en`, `es`).
    let noms: [String: String]

    func nom(en langue: Langue) -> String {
        noms[langue.rawValue] ?? noms[Langue.fr.rawValue] ?? noms.values.min() ?? "#\(id)"
    }
}

/// Retrouver un indice d'après un texte : la saisie de l'utilisateur
/// (autocomplétion) ou les lignes de l'OCR. Pur : la liste est fournie.
///
/// Tout se compare sur une forme **normalisée** — sans accents ni casse,
/// ligatures dépliées, ponctuation réduite à des espaces : « Crâne » et
/// « crane », « Œuf » et « oeuf » se valent.
enum IndicesChasse {
    /// En deçà, un nom est trop court pour être cherché à une faute près dans
    /// une ligne : il s'y trouverait par hasard.
    static let longueurFloue = 5

    static func normaliser(_ texte: String) -> String {
        let plie = texte
            .replacingOccurrences(of: "œ", with: "oe").replacingOccurrences(of: "Œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae").replacingOccurrences(of: "Æ", with: "ae")
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
        let mots = plie.split { !($0.isLetter || $0.isNumber) }
        return mots.joined(separator: " ")
    }

    // MARK: - Autocomplétion

    /// Les indices dont le nom, dans `langue`, répond à `saisie` : ceux qui
    /// commencent par elle, puis ceux qui la contiennent, puis — pour une
    /// faute de frappe — ceux qui en sont à peu d'éditions.
    static func rechercher(_ saisie: String, parmi indices: [Indice], langue: Langue, limite: Int = 8) -> [Indice] {
        let motif = normaliser(saisie)
        guard !motif.isEmpty else { return [] }
        var classes: [(rang: Int, nom: String, indice: Indice)] = []
        for indice in indices {
            let nom = indice.nom(en: langue)
            let cible = normaliser(nom)
            let rang: Int
            if cible.hasPrefix(motif) {
                rang = 0
            } else if cible.contains(motif) {
                rang = 1
            } else {
                let tolerance = max(1, motif.count / 4)
                let ecart = distanceDansTexte(motif, cible)
                guard ecart <= tolerance else { continue }
                rang = 1 + ecart
            }
            classes.append((rang, nom, indice))
        }
        return classes
            .sorted { ($0.rang, $0.nom.count, $0.nom) < ($1.rang, $1.nom.count, $1.nom) }
            .prefix(limite)
            .map(\.indice)
    }

    // MARK: - OCR

    /// Les indices lus dans les lignes de l'OCR, dans l'ordre des lignes — le
    /// dernier est l'étape en cours. Tous les noms connus comptent, quelle
    /// que soit la langue de l'interface : celle du jeu peut différer.
    ///
    /// Vision écorche une lettre ou deux (« Pouppe koaiak ») et colle à la
    /// ligne l'icône voisine : le nom est cherché **dans** la ligne, à un
    /// nombre d'éditions borné par sa longueur. Une ligne qui en contient
    /// plusieurs garde le plus long (« Crâne de likrone dans la glace »
    /// contient « Crâne de likrone »).
    static func indicesReconnus(dans lignes: [String], parmi indices: [Indice]) -> [Indice] {
        let noms = indices.flatMap { indice in
            Set(indice.noms.values.map(normaliser)).filter { $0.count >= 3 }.map { (indice, $0) }
        }
        var reconnus: [Indice] = []
        for ligne in lignes {
            let texte = normaliser(ligne)
            guard !texte.isEmpty else { continue }
            var meilleur: (indice: Indice, ecart: Int, longueur: Int)?
            for (indice, nom) in noms {
                let tolerance = nom.count < longueurFloue ? 0 : nom.count / 5
                guard nom.count <= texte.count + tolerance else { continue }
                let ecart = tolerance == 0 ? (texte.contains(nom) ? 0 : 1) : distanceDansTexte(nom, texte)
                guard ecart <= tolerance else { continue }
                if let actuel = meilleur, (actuel.ecart, -actuel.longueur) <= (ecart, -nom.count) { continue }
                meilleur = (indice, ecart, nom.count)
            }
            guard let trouve = meilleur?.indice else { continue }
            reconnus.removeAll { $0.id == trouve.id }
            reconnus.append(trouve)
        }
        return reconnus
    }

    // MARK: - Distance

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
