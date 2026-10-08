import AppKit

/// La page d'une quête sur Dofus pour les noobs. Le site (Weebly) tire
/// l'adresse du titre sans règle fixe : apostrophes et ponctuation tombent,
/// mais une lettre accentuée y devient tantôt sa lettre nue (« pense-bete »),
/// tantôt son entité HTML (« leacuteternelle-moisson »), parfois les deux
/// dans un même titre. D'où des candidats, vérifiés au clic ; à défaut, une
/// recherche sur le site.
enum DofusPourLesNoobs {
    private static let site = "www.dofuspourlesnoobs.com"
    /// Au-delà, 2ⁿ variantes : seules les deux extrêmes sont essayées.
    private static let accentsCombinables = 5

    private static let entites: [Character: String] = [
        "à": "agrave", "â": "acirc", "ä": "auml", "æ": "aelig", "ç": "ccedil",
        "é": "eacute", "è": "egrave", "ê": "ecirc", "ë": "euml", "î": "icirc", "ï": "iuml",
        "ô": "ocirc", "ö": "ouml", "œ": "oelig", "ù": "ugrave", "û": "ucirc", "ü": "uuml", "ÿ": "yuml",
    ]

    /// Les adresses possibles, la plus probable d'abord : lettres nues, puis
    /// de plus en plus d'entités.
    static func candidats(_ nom: String) -> [String] {
        // Le titre en morceaux : du texte fixe, ou une lettre accentuée à deux
        // écritures. Une apostrophe colle les mots, le reste les sépare.
        var morceaux: [(nue: String, entite: String?)] = []
        for lettre in nom.lowercased() {
            if let entite = entites[lettre] {
                let nue = String(lettre).folding(options: .diacriticInsensitive, locale: nil)
                morceaux.append((lettre == "œ" ? "oe" : lettre == "æ" ? "ae" : nue, entite))
            } else if lettre.isASCII, lettre.isLetter || lettre.isNumber {
                morceaux.append((String(lettre), nil))
            } else if "'’ʼ".contains(lettre) {
                continue
            } else {
                let nue = String(lettre).folding(options: .diacriticInsensitive, locale: nil)
                morceaux.append(nue.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } ? (nue, nil) : ("-", nil))
            }
        }
        let variables = morceaux.indices.filter { morceaux[$0].entite != nil }
        let choix: [Set<Int>] = variables.count <= accentsCombinables
            ? (0..<(1 << variables.count))
                .map { masque in Set(variables.indices.filter { masque & (1 << $0) != 0 }.map { variables[$0] }) }
                .sorted { $0.count < $1.count }
            : [[], Set(variables)]
        var vus: Set<String> = []
        return choix.compactMap { entites in
            let brut = morceaux.indices.map { entites.contains($0) ? morceaux[$0].entite ?? "" : morceaux[$0].nue }.joined()
            let slug = brut.split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
            guard !slug.isEmpty, vus.insert(slug).inserted else { return nil }
            return slug
        }
    }

    static func page(_ slug: String) -> URL {
        URL(string: "https://\(site)/\(slug).html")!
    }

    static func recherche(_ nom: String) -> URL {
        var adresse = URLComponents(string: "https://www.google.com/search")!
        adresse.queryItems = [URLQueryItem(name: "q", value: "site:dofuspourlesnoobs.com \(nom)")]
        return adresse.url!
    }

    /// Ouvre la première page qui existe, sinon la recherche.
    @MainActor
    static func ouvrir(_ nom: String) async {
        let url = await premiereExistante(candidats(nom).map(page)) ?? recherche(nom)
        NSWorkspace.shared.open(url)
    }

    /// Toutes à la fois (une requête `HEAD` chacune), la première de la liste
    /// qui répond 200.
    private nonisolated static func premiereExistante(_ urls: [URL]) async -> URL? {
        let trouvees = await withTaskGroup(of: (Int, Bool).self) { groupe in
            for (rang, url) in urls.enumerated() {
                groupe.addTask {
                    var requete = URLRequest(url: url, timeoutInterval: 6)
                    requete.httpMethod = "HEAD"
                    let reponse = try? await URLSession.shared.data(for: requete).1
                    return (rang, (reponse as? HTTPURLResponse)?.statusCode == 200)
                }
            }
            var rangs: Set<Int> = []
            for await (rang, existe) in groupe where existe { rangs.insert(rang) }
            return rangs
        }
        return trouvees.min().map { urls[$0] }
    }
}
