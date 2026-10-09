import Foundation

/// Le suivi de quêtes du jeu lu par l'OCR : les quêtes qu'il montre, dans
/// l'ordre de l'écran, l'étape en cours quand ses objectifs la désignent
/// sans ambiguïté, et ce qu'ils disent des objectifs de cette étape
/// (`SuiviObjectifs`). Pur : les lignes et les quêtes sont fournies.
///
/// Le suivi aligne, pour chaque quête, son titre — en gras décoratif, que
/// Vision écorche plus que le reste, suivi d'icônes (groupe, donjon) lues
/// parfois comme des lettres — puis ses objectifs, une épingle devant, souvent
/// sur deux lignes. Une ligne de titre **est** un nom de quête à quelques
/// fautes près, qui l'ouvre, elle ne fait pas que le contenir : sans quoi un
/// objectif qui cite une quête passerait pour elle.
enum SuiviQuetes {
    struct Reconnue: Equatable, Sendable {
        let id: Int
        /// Le rang de l'étape que désignent les objectifs lus, si une seule
        /// s'y reconnaît mieux que les autres ; jamais pour une quête d'une
        /// seule étape.
        let etape: Int?
        /// L'étape est établie (`SuiviObjectifs.Lecture.sure`), pas seulement
        /// la plus probable : le panneau y avance.
        let etapeSure: Bool
        /// Les objectifs de l'étape que le suivi montre, donc encore à faire,
        /// dans l'ordre de l'écran.
        let aFaire: [Int]
        /// Ceux que le suivi tient pour faits ; vide quand la lecture est
        /// douteuse (`SuiviObjectifs`).
        let faits: [Int]
        /// Ceux que le suivi tait : pas encore ouverts, ou faits hors de
        /// l'ordre. Seulement jusqu'à la coupure, et quand toutes les lignes
        /// se sont lues (`SuiviObjectifs`).
        let nonMontres: [Int]

        init(id: Int, etape: Int?, etapeSure: Bool = false, aFaire: [Int] = [], faits: [Int] = [],
             nonMontres: [Int] = []) {
            self.id = id
            self.etape = etape
            self.etapeSure = etape != nil && etapeSure
            self.aFaire = aFaire
            self.faits = faits
            self.nonMontres = nonMontres
        }
    }

    /// Une lecture du suivi : les quêtes reconnues, et la place que chacune
    /// tient à l'écran — ce qui dit si une quête absente a pu être poussée
    /// hors de la zone ou absorbée par sa voisine (`HistoriqueSuivi`).
    struct Lu: Equatable, Sendable {
        let reconnues: [Reconnue]
        /// Les lignes d'objectifs sous chaque quête, dans l'ordre de `reconnues`.
        let lignes: [Int]
        /// Les lignes lues avant le premier titre : l'en-tête du suivi, ou les
        /// objectifs d'une quête dont le titre s'est mal lu.
        let entete: Int
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

    fileprivate struct Nom: Sendable {
        let quete: Quete
        let langue: Langue
        let forme: Ressemblance.Forme
    }

    /// Les noms de toutes les quêtes, dans chaque langue de l'app — celle du
    /// jeu peut différer de celle de l'interface —, prêts à comparer. Deux
    /// mille quêtes dans trois langues : bâti une fois par jeu de quêtes
    /// (`LectureSuivi`), pas à chaque lecture.
    struct Index: Sendable {
        let quetes: Quetes
        fileprivate let noms: [Nom]

        init(_ quetes: Quetes) {
            self.quetes = quetes
            noms = quetes.quetes.flatMap { quete in
                var vus: Set<String> = []
                return Langue.allCases.compactMap { langue -> Nom? in
                    guard let brut = quete.noms[langue.rawValue] else { return nil }
                    let nom = Ressemblance.normaliser(brut)
                    guard nom.count >= 3, vus.insert(nom).inserted else { return nil }
                    return Nom(quete: quete, langue: langue, forme: Ressemblance.Forme(nom))
                }
            }
        }
    }

    /// Un nom que porte une ligne, et à combien de fautes.
    private struct Titre {
        let nom: Nom
        let ecart: Int
    }

    /// Une ligne de titre et les lignes lues dessous.
    private struct Groupe {
        /// Les noms que la ligne porte, le plus près d'abord (`titres`).
        let titres: [Titre]
        var objectifs: [String] = []
    }

    /// `coupe` : le texte lu touche le bas de la zone (`SignatureZone.auBord`),
    /// les objectifs de la dernière quête lue peuvent continuer dessous.
    static func reconnaitre(_ lignes: [String], coupe: Bool = false, dans index: Index) -> Lu {
        var groupes: [Groupe] = []
        var entete = 0
        let textes = lignes.map(Ressemblance.normaliser).filter { !$0.isEmpty }
        for (rang, texte) in textes.enumerated() {
            let titres = titres(Ressemblance.Forme(texte), parmi: index.noms)
            if !titres.isEmpty, !estObjectif(textes[rang...], du: groupes.last, plutotQue: titres, dans: index.quetes) {
                groupes.append(Groupe(titres: titres))
            } else if groupes.isEmpty {
                entete += 1
            } else {
                groupes[groupes.count - 1].objectifs.append(texte)
            }
        }
        let designees = groupes.enumerated().map { rang, groupe in
            designer(groupe, coupee: coupe && rang == groupes.count - 1, dans: index.quetes)
        }
        // Des homonymes indistincts prennent ce que les autres groupes
        // laissent. Une quête vue deux fois, ou au-delà de la limite : ses
        // lignes ne sont à personne.
        let designes = Set(designees.compactMap { if case .quete(let reconnue) = $0 { reconnue.id } else { nil } })
        var reconnues: [Reconnue] = [], comptes: [Int] = []
        for (groupe, designee) in zip(groupes, designees) where reconnues.count < limite {
            let libre = { (id: Int) in !reconnues.contains { $0.id == id } }
            let reconnue: Reconnue? = switch designee {
            case .quete(let reconnue): libre(reconnue.id) ? reconnue : nil
            case .homonymes(let ids): ids.first { libre($0) && !designes.contains($0) }.map { Reconnue(id: $0, etape: nil) }
            }
            guard let reconnue else { continue }
            reconnues.append(reconnue)
            comptes.append(groupe.objectifs.count)
        }
        return Lu(reconnues: reconnues, lignes: comptes, entete: entete)
    }

    /// La ligne qui porte un nom de quête, la première de `suite`, est-elle
    /// un objectif du groupe en cours ? Elle achève un objectif replié
    /// (« L'équipe ment » sous « … récupérer »), ou en commence un que la
    /// quête nommée ne prolonge pas : « Lâcher les gaz », objectif d'une
    /// quête et nom d'une autre, n'en est le titre que si celle-ci explique
    /// la ligne d'après.
    private static func estObjectif(_ suite: ArraySlice<String>, du groupe: Groupe?, plutotQue titres: [Titre],
                                    dans quetes: Quetes) -> Bool {
        guard let groupe, let ligne = suite.first else { return false }
        let fenetre = Array(suite.prefix(SuiviObjectifs.lignesParObjectif))
        let apres = Array(suite.dropFirst().prefix(SuiviObjectifs.lignesParObjectif))
        func lit(_ lignes: [String], _ nom: Nom) -> Bool {
            SuiviObjectifs.lit(lignes, quete: nom.quete, langue: nom.langue, dans: quetes)
        }
        return groupe.titres.map(\.nom).contains { nom in
            SuiviObjectifs.prolonge(groupe.objectifs, par: ligne, quete: nom.quete, langue: nom.langue, dans: quetes)
                || lit(fenetre, nom) && (apres.isEmpty || !titres.contains { lit(apres, $0.nom) })
        }
    }

    /// Ce qu'un groupe désigne : une quête, ou des homonymes que ses
    /// objectifs ne départagent pas.
    private enum Designee {
        case quete(Reconnue)
        case homonymes([Int])
    }

    /// La quête du groupe, et ce que ses objectifs en disent. Plusieurs noms
    /// (homonymes, « Joyeux Nowel » trente-quatre fois ; ou à une faute
    /// près) : celle dont une étape se lit le mieux sous le titre. À égalité,
    /// le nom le mieux lu s'il l'est seul, pour montrer ses objectifs mais
    /// jamais en cocher — cocher l'une pour l'autre serait faux ; sinon
    /// aucune. Aucun objectif lu : le nom le mieux lu, s'il l'est seul.
    private static func designer(_ groupe: Groupe, coupee: Bool, dans quetes: Quetes) -> Designee {
        let candidats = groupe.titres.map(\.nom)
        let lectures = candidats.map {
            SuiviObjectifs.lire(groupe.objectifs, coupee: coupee, quete: $0.quete, langue: $0.langue, dans: quetes)
        }
        let scores = lectures.map { $0?.explique ?? 0 }
        let meilleur = scores.max() ?? 0
        let egaux = meilleur > 0 ? scores.indices.filter { scores[$0] == meilleur }
            : groupe.titres.indices.filter { groupe.titres[$0].ecart == groupe.titres[0].ecart }
        guard let rang = egaux.first, egaux.count == 1 else {
            if let rang = egaux.first, let lue = lectures[rang],
               egaux.dropFirst().allSatisfy({ groupe.titres[$0].ecart > groupe.titres[rang].ecart }) {
                let quete = candidats[rang].quete
                return .quete(Reconnue(id: quete.id, etape: quete.etapes.count > 1 ? lue.etape : nil,
                                       aFaire: lue.aFaire, nonMontres: lue.nonMontres))
            }
            return .homonymes(egaux.map { candidats[$0].quete.id })
        }
        let quete = candidats[rang].quete
        guard let lue = lectures[rang] else {
            let etape = etapeParRenvois(quete, langue: candidats[rang].langue, objectifs: groupe.objectifs, dans: quetes)
            return .quete(Reconnue(id: quete.id, etape: etape))
        }
        return .quete(Reconnue(id: quete.id, etape: quete.etapes.count > 1 ? lue.etape : nil, etapeSure: lue.sure,
                               aFaire: lue.aFaire, faits: lue.faits, nonMontres: lue.nonMontres))
    }

    /// Les noms que la ligne porte, le plus près d'abord, et ceux qu'une
    /// faute d'OCR de plus en ferait lire (`SuiviObjectifs.marge`) : trois
    /// cent soixante-dix « Offrande à … » ne diffèrent que d'un nom court, et
    /// des homonymes, pas du tout — leurs objectifs départagent. Un nom qui
    /// n'est que le début d'un autre, aussi bien lu, s'efface devant lui
    /// (« La voie » devant « La voie du guerrier »).
    private static func titres(_ texte: Ressemblance.Forme, parmi noms: [Nom]) -> [Titre] {
        var trouves: [Titre] = []
        var meilleur: Int?
        for candidat in noms {
            let longueur = candidat.forme.longueur
            let tolerance = longueur < longueurFloue ? 0 : longueur / 4
            // Plus loin que le meilleur nom trouvé, à la marge près, un nom
            // n'est pas retenu : la distance s'arrête là (chaque ligne lue
            // contre six mille noms).
            let borne = min(tolerance, (meilleur ?? tolerance) + SuiviObjectifs.marge)
            guard texte.longueur <= longueur + tolerance + surplusTitre,
                  longueur <= texte.longueur + tolerance,
                  !candidat.forme.tropLoin(de: texte, tolerance: borne)
            else { continue }
            let ecart = tolerance == 0
                ? (texte.scalaires.starts(with: candidat.forme.scalaires)
                    && (texte.longueur == longueur || texte.scalaires[longueur] == 32) ? 0 : 1)
                : Ressemblance.distanceAuDebut(candidat.forme, texte, auPlus: borne)
            guard let ecart, ecart <= tolerance else { continue }
            trouves.append(Titre(nom: candidat, ecart: ecart))
            meilleur = min(meilleur ?? ecart, ecart)
        }
        guard let meilleur else { return [] }
        let proches = trouves.filter { $0.ecart <= meilleur + SuiviObjectifs.marge }
        return proches.enumerated()
            .filter { _, court in
                !proches.contains { long in long.ecart <= court.ecart && Self.debut(court.nom.forme, de: long.nom.forme) }
            }
            .sorted { ($0.element.ecart, -$0.element.nom.forme.longueur, $0.offset)
                < ($1.element.ecart, -$1.element.nom.forme.longueur, $1.offset) }
            .map(\.element)
    }

    /// `court` ouvre-t-il `long`, mot pour mot ?
    private static func debut(_ court: Ressemblance.Forme, de long: Ressemblance.Forme) -> Bool {
        long.longueur > court.longueur && long.scalaires.starts(with: court.scalaires) && long.scalaires[court.longueur] == 32
    }

    // MARK: - Étape

    /// Faute d'objectif lu en entier (`SuiviObjectifs`), l'étape dont les
    /// noms cités (PNJ, objet, monstre) se lisent le mieux sous le titre : un
    /// point par nom retrouvé, deux par objectif retrouvé en entier. Le texte
    /// du suivi peut être reformulé (« Rapporter 1 âme de… » pour « Ramener à
    /// … : x1 … ») : les noms cités résistent. Une égalité — le même PNJ à
    /// deux étapes — ne désigne rien.
    private static func etapeParRenvois(_ quete: Quete, langue: Langue, objectifs: [String], dans quetes: Quetes) -> Int? {
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
