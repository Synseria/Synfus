/// Les habitudes de la palette : combien de fois chaque entrée a été choisie, et laquelle l'a été le
/// plus récemment. Pur ; gardé sur le Mac (`Preferences.paletteFrequentation`), jamais envoyé.
struct FrequentationPalette: Codable, Equatable, Sendable {
    struct Compte: Codable, Equatable, Sendable {
        var fois: Int
        /// Le rang du dernier choix parmi tous : plus grand, plus récent.
        var dernier: Int
    }

    private(set) var comptes: [String: Compte]

    /// Au-delà, le moins choisi est oublié : la sauvegarde ne grossit pas avec les années.
    static let taille = 300

    init(_ comptes: [String: Compte] = [:]) {
        self.comptes = comptes
    }

    /// Écrite comme la table elle-même : `{"lieu:2738": {"fois": 3, "dernier": 12}}`.
    init(from decoder: any Decoder) throws {
        comptes = try decoder.singleValueContainer().decode([String: Compte].self)
    }

    func encode(to encoder: any Encoder) throws {
        var conteneur = encoder.singleValueContainer()
        try conteneur.encode(comptes)
    }

    /// Ce qui compte pour une entrée : sa `cle` quand elle s'étiquette (un PNJ compte une fois pour
    /// toutes ses cases, un zaap autant cherché par `/zaap` que par `/travel`), son `id` sinon —
    /// l'un et l'autre tirés des identifiants DofusDB, les mêmes dans toutes les langues.
    /// `nil` pour ce qui ne mène à rien du jeu : commande, variable, geste, copie, invitation.
    static func cle(de entree: EntreePalette) -> String? {
        switch entree.effet {
        case .ouvrirQuete, .ouTrouver, .donjon: return entree.cle ?? entree.id
        // Une case tapée n'a pas de `cle` : elle ne devient pas une habitude, comme un `/travel x,y`.
        case .trajet, .copier: return entree.cle
        case .completer, .action, .basculer: return nil
        }
    }

    func compte(de entree: EntreePalette) -> Compte? {
        guard !comptes.isEmpty, let cle = Self.cle(de: entree) else { return nil }
        return comptes[cle]
    }

    /// Un choix de plus ; au-delà de `taille`, le moins choisi s'en va, le plus ancien à égalité —
    /// jamais celui qu'on vient de choisir.
    mutating func noter(_ cle: String) {
        let rang = (comptes.values.map(\.dernier).max() ?? 0) + 1
        comptes[cle] = Compte(fois: (comptes[cle]?.fois ?? 0) + 1, dernier: rang)
        while comptes.count > Self.taille {
            let oublie = comptes.filter { $0.key != cle }
                .min { ($0.value.fois, $0.value.dernier) < ($1.value.fois, $1.value.dernier) }
            guard let oublie else { return }
            comptes[oublie.key] = nil
        }
    }
}
