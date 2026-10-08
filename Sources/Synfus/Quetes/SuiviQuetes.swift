import Foundation

/// Le suivi de quêtes du jeu lu par l'OCR : les quêtes qu'il montre, dans
/// l'ordre de l'écran, et l'étape en cours quand ses objectifs la désignent
/// sans ambiguïté. Pur : les lignes et les quêtes sont fournies.
///
/// Le suivi aligne, pour chaque quête, son titre — en gras décoratif, que
/// Vision écorche plus que le reste, suivi d'icônes (groupe, donjon) lues
/// parfois comme des lettres — puis ses objectifs, une épingle devant, souvent
/// sur deux lignes. Une ligne de titre **est** un nom de quête à quelques
/// fautes près, elle ne fait pas que le contenir : sans quoi un objectif qui
/// cite une quête passerait pour elle.
enum SuiviQuetes {
    struct Reconnue: Equatable, Sendable {
        let id: Int
        /// Le rang de l'étape que désignent les objectifs lus, si une seule
        /// s'y reconnaît mieux que les autres.
        let etape: Int?
    }

    /// Ce que le panneau propose au plus.
    static let limite = 10
    /// En deçà, un nom se compare sans faute admise : il se trouverait par
    /// hasard.
    static let longueurFloue = 5
    /// Ce qu'une ligne de titre peut porter au-delà du nom : les icônes à
    /// sa droite, lues comme une ou deux lettres.
    static let surplusTitre = 4
    /// En deçà, un nom cité par un objectif (PNJ, objet, monstre) est trop
    /// commun pour désigner une étape.
    static let longueurRenvoi = 6

    private struct Nom {
        let quete: Quete
        let langue: Langue
        let forme: Ressemblance.Forme
    }

    static func reconnaitre(_ lignes: [String], dans quetes: Quetes) -> [Reconnue] {
        let noms = noms(quetes)
        var groupes: [(titre: Nom, objectifs: [String])] = []
        // `nil` : les lignes lues n'appartiennent à aucune quête retenue —
        // l'en-tête du suivi, ou une quête vue deux fois ou au-delà de la limite.
        var courant: Int?
        for ligne in lignes {
            let texte = Ressemblance.normaliser(ligne)
            guard !texte.isEmpty else { continue }
            if let titre = titre(Ressemblance.Forme(texte), parmi: noms) {
                if groupes.count < limite, !groupes.contains(where: { $0.titre.quete.id == titre.quete.id }) {
                    groupes.append((titre, []))
                    courant = groupes.count - 1
                } else {
                    courant = nil
                }
            } else if let courant {
                groupes[courant].objectifs.append(texte)
            }
        }
        return groupes.map {
            Reconnue(id: $0.titre.quete.id, etape: etape($0.titre.quete, langue: $0.titre.langue,
                                                         objectifs: $0.objectifs, dans: quetes))
        }
    }

    /// Les noms de toutes les quêtes, dans chaque langue de l'app : celle du
    /// jeu peut différer de celle de l'interface.
    private static func noms(_ quetes: Quetes) -> [Nom] {
        quetes.quetes.flatMap { quete in
            var vus: Set<String> = []
            return Langue.allCases.compactMap { langue -> Nom? in
                guard let brut = quete.noms[langue.rawValue] else { return nil }
                let nom = Ressemblance.normaliser(brut)
                guard nom.count >= 3, vus.insert(nom).inserted else { return nil }
                return Nom(quete: quete, langue: langue, forme: Ressemblance.Forme(nom))
            }
        }
    }

    /// Le nom que la ligne porte, au plus près ; à écart égal, le plus long
    /// (« La voie du guerrier » plutôt que « La voie »).
    private static func titre(_ texte: Ressemblance.Forme, parmi noms: [Nom]) -> Nom? {
        var meilleur: (nom: Nom, ecart: Int)?
        for candidat in noms {
            let longueur = candidat.forme.longueur
            let tolerance = longueur < longueurFloue ? 0 : longueur / 4
            guard texte.longueur <= longueur + tolerance + surplusTitre,
                  longueur <= texte.longueur + tolerance,
                  !candidat.forme.tropLoin(de: texte, tolerance: tolerance)
            else { continue }
            let ecart = tolerance == 0
                ? (texte.scalaires.starts(with: candidat.forme.scalaires)
                    && (texte.longueur == longueur || texte.scalaires[longueur] == 32) ? 0 : 1)
                : Ressemblance.distanceDansTexte(candidat.forme, texte)
            guard ecart <= tolerance else { continue }
            if let actuel = meilleur,
               (actuel.ecart, -actuel.nom.forme.longueur) <= (ecart, -longueur) { continue }
            meilleur = (candidat, ecart)
        }
        return meilleur?.nom
    }

    // MARK: - Étape

    /// L'étape dont les objectifs se lisent le mieux sous le titre : un point
    /// par nom cité retrouvé (PNJ, objet, monstre), deux par objectif retrouvé
    /// en entier. Le texte du suivi n'est pas toujours celui de DofusDB
    /// (« Rapporter 1 âme de… » pour « Ramener à … : x1 … ») : les noms cités
    /// sont le signal le plus sûr. Une égalité — le même PNJ à deux étapes —
    /// ne désigne rien.
    private static func etape(_ quete: Quete, langue: Langue, objectifs: [String], dans quetes: Quetes) -> Int? {
        guard quete.etapes.count > 1, !objectifs.isEmpty else { return nil }
        let bloc = objectifs.joined(separator: " ")
        let points = quete.etapes.map { etape in
            etape.objectifs.reduce(0) { $0 + Self.points($1, langue: langue, bloc: bloc, quetes: quetes) }
        }
        guard let meilleur = points.max(), meilleur > 0, points.filter({ $0 == meilleur }).count == 1
        else { return nil }
        return points.firstIndex(of: meilleur)
    }

    private static func points(_ objectif: ObjectifQuete, langue: Langue, bloc: String, quetes: Quetes) -> Int {
        guard let modele = Lieu.traduit(objectif.textes, langue) else { return 0 }
        var cites: [String] = []
        let complet = Ressemblance.normaliser(Quetes.resoudre(modele) { genre, id in
            let nom = quetes.nomRenvoi(genre, id, en: langue)
            if let nom { cites.append(Ressemblance.normaliser(nom)) }
            return nom
        })
        var total = Set(cites).filter { $0.count >= longueurRenvoi && present($0, dans: bloc) }.count
        if complet.count >= 2 * longueurRenvoi, present(complet, dans: bloc) { total += 2 }
        return total
    }

    private static func present(_ texte: String, dans bloc: String) -> Bool {
        texte.count <= bloc.count + texte.count / 5
            && Ressemblance.distanceDansTexte(texte, bloc) <= texte.count / 5
    }
}
