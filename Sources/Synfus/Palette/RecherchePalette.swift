import Foundation

/// Les gestes de Synfus que la palette sait faire, tapés en toutes lettres.
enum ActionPalette: CaseIterable, Sendable {
    case rangerFenetres, lancerSession, equipeSuivante, inviterEquipe, chasse, reglages

    var titre: String {
        switch self {
        case .rangerFenetres: return L("palette.action.ranger")
        case .lancerSession: return L("palette.action.session")
        case .equipeSuivante: return L("palette.action.equipe")
        case .inviterEquipe: return L("palette.action.inviter")
        case .chasse: return L("palette.action.chasse")
        case .reglages: return L("palette.action.reglages")
        }
    }
}

/// Ce que Tab fait défiler : la famille de résultats montrée.
enum FiltrePalette: CaseIterable, Sendable {
    case tout, zaaps, lieux, quetes, pnj

    var titre: String {
        switch self {
        case .tout: return L("palette.filtre.tout")
        case .zaaps: return L("palette.filtre.zaaps")
        case .lieux: return L("palette.filtre.lieux")
        case .quetes: return L("palette.filtre.quetes")
        case .pnj: return L("palette.filtre.pnj")
        }
    }

    func garde(_ genre: EntreePalette.Genre) -> Bool {
        switch self {
        case .tout: return true
        case .zaaps: return genre == .zaap
        case .lieux: return genre == .lieu
        case .quetes: return genre == .quete
        case .pnj: return genre == .pnj
        }
    }

    /// Le suivant (Tab) ou le précédent (⇧Tab), en boucle.
    func suivant(_ pas: Int) -> FiltrePalette {
        let tous = Self.allCases
        return tous[(tous.firstIndex(of: self)! + pas + tous.count) % tous.count]
    }
}

/// L'ordre des résultats, après les zaaps qui passent toujours devant.
enum TriPalette: String, CaseIterable, Codable, Sendable {
    case proximite, alphabetique, type

    var titre: String {
        switch self {
        case .proximite: return L("palette.tri.proximite")
        case .alphabetique: return L("palette.tri.alphabetique")
        case .type: return L("palette.tri.type")
        }
    }

    var suivant: TriPalette {
        let tous = Self.allCases
        return tous[(tous.firstIndex(of: self)! + 1) % tous.count]
    }
}

/// Une ligne de la palette, et ce qu'Entrée en fait.
struct EntreePalette: Equatable, Identifiable, Sendable {
    enum Genre: Equatable, Sendable { case zaap, lieu, commande, variable, perso, action, recent, quete, pnj }

    enum Effet: Equatable, Sendable {
        /// Pose le texte dans le presse-papiers et ferme.
        case copier(String)
        /// Remplace la recherche, la palette reste ouverte (`/w ` à compléter).
        case completer(String)
        /// Ouvre la quête dans son panneau : étapes, objectifs, ressources.
        case ouvrirQuete(Int)
        /// Copie le trajet vers la case, zaap compris s'il vaut le coup —
        /// calculé seulement pour l'entrée choisie (`texte(de:)`).
        case trajet(x: Int, y: Int)
        case action(ActionPalette)
    }

    let id: String
    let genre: Genre
    let titre: String
    var sousTitre: String?
    var etiquette: String?
    /// À droite : coordonnées, commande copiée.
    var detail: String?
    var favori = false
    /// Les cartes depuis le perso devant, quand elles veulent dire quelque
    /// chose : départage deux résultats aussi bons.
    var distance: Int?
    /// La catégorie DofusDB d'un lieu (`CategorieLieu`) : le tri par type.
    var categorie: Int?
    /// Le texte cherché après le titre, quand le sous-titre en dit plus
    /// qu'il n'en faut chercher (la distance d'un lieu) ; sinon le sous-titre.
    var recherche: String?
    /// Ce qu'une étiquette ou un favori désigne (`Zaap.cle`, `Lieu.cle`) ;
    /// `nil` pour ce qui ne s'étiquette pas.
    var cle: String?
    let effet: Effet
}

/// Ce que la recherche doit savoir du monde, figé à l'ouverture.
struct ContextePalette: Sendable {
    var langue: Langue = .fr
    var position: PositionCarte?
    /// Les zaaps actifs.
    var zaaps: [Zaap] = []
    /// D'où partir vers une case : `ItineraireZaap.zaap(vers:)`.
    var reseau = ReseauSousZones.vide
    var lieux: [Lieu] = []
    var etiquettes: [String: String] = [:]
    var favoris: Set<String> = []
    /// Les derniers textes copiés depuis la palette, le plus récent d'abord.
    var recents: [String] = []
    var gainMinimal = ItineraireZaap.gainParDefaut
    /// `/invite A; /invite B` pour l'équipe active, déjà composé.
    var invitationEquipe: String?
    var invitations: [(nom: String, commande: String)] = []
    /// `nil` tant qu'elles ne sont pas téléchargées.
    var quetes: Quetes?
}

/// La recherche de la palette. Pure : un texte et un contexte, des entrées
/// triées. Les préfixes choisissent le mode — `/zaap`, `/travel`, `/invite`,
/// `/` (commandes), `%` (variables) — ; sans préfixe, tout se cherche, dans
/// la famille du filtre. Les zaaps passent toujours devant, puis le tri.
enum RecherchePalette {
    static let limite = 200

    static func entrees(_ requete: String, _ contexte: ContextePalette,
                        filtre: FiltrePalette = .tout, tri: TriPalette = .proximite) -> [EntreePalette] {
        entrees(requete, IndexPalette(contexte), filtre: filtre, tri: tri)
    }

    static func entrees(_ requete: String, _ index: IndexPalette,
                        filtre: FiltrePalette = .tout, tri: TriPalette = .proximite) -> [EntreePalette] {
        let texte = requete.trimmingCharacters(in: .whitespaces)
        func classer(_ fiches: [Fiche], _ mots: [String]) -> [EntreePalette] {
            RecherchePalette.classer(fiches, mots, tri: tri)
        }
        if texte.isEmpty {
            // La grille des zaaps, favoris d'abord puis du plus proche — sauf
            // filtre sur une autre famille, montrée entière.
            if filtre == .tout || filtre == .zaaps { return index.zaaps.map(\.entree) }
            return classer(index.tout.filter { filtre.garde($0.entree.genre) }, [])
        }
        if texte.hasPrefix("%") { return variables(texte) }
        guard texte.hasPrefix("/") else {
            return classer(index.tout.filter { filtre.garde($0.entree.genre) }, mots(texte))
        }
        let (commande, reste) = separer(texte)
        switch commande {
        case "/zaap": return classer(index.zaaps, mots(reste))
        case "/travel":
            if let cible = ItineraireZaap.cible(dans: "/travel " + reste) {
                let copie = trajet(vers: cible, index.contexte)
                return [EntreePalette(id: "travel", genre: .lieu, titre: copie, detail: Coordonnees.texte(cible.x, cible.y),
                                      effet: .copier(copie))]
            }
            return classer(index.lieux + index.zaapsCommeLieux, mots(reste))
        case "/invite": return classer(fiches(invitations(index.contexte)), mots(reste))
        case "/quete", "/quête": return classer(index.quetes, mots(reste))
        case "/pnj": return classer(index.pnjs, mots(reste))
        default: return commandes(texte)
        }
    }

    /// Le texte qu'Entrée copiera — `nil` pour ce qui ne copie rien.
    static func texte(de effet: EntreePalette.Effet, _ contexte: ContextePalette) -> String? {
        switch effet {
        case .copier(let texte): return texte
        case .trajet(let x, let y): return trajet(vers: (x, y), contexte)
        case .completer, .action, .ouvrirQuete: return nil
        }
    }

    static func fiches(_ entrees: [EntreePalette], connus: [String: Champs] = [:]) -> [Fiche] {
        entrees.map { Fiche(entree: $0, champs: connus[Champs.cle($0)] ?? Champs($0)) }
    }

    // MARK: - Modes

    /// Les zaaps, favoris d'abord puis du plus proche au plus loin.
    static func zaaps(_ contexte: ContextePalette) -> [EntreePalette] {
        zaapsTries(contexte).map { zaap in
            EntreePalette(
                id: "zaap:" + zaap.cle, genre: .zaap, titre: zaap.nom(en: contexte.langue),
                sousTitre: zaap.zone(en: contexte.langue), etiquette: contexte.etiquettes[zaap.cle],
                detail: Coordonnees.texte(zaap.x, zaap.y), favori: contexte.favoris.contains(zaap.cle),
                distance: CatalogueZaaps.distance(de: zaap, depuis: contexte.position), cle: zaap.cle,
                effet: .copier(ItineraireZaap.zaap(zaap)))
        }
    }

    /// Un zaap cherché par `/travel` : le trajet vers lui, comme vers un lieu.
    static func zaapsCommeLieux(_ contexte: ContextePalette) -> [EntreePalette] {
        zaapsTries(contexte).map { zaap in
            EntreePalette(
                id: "travel:" + zaap.cle, genre: .lieu, titre: L("palette.zaap", zaap.nom(en: contexte.langue)),
                sousTitre: zaap.zone(en: contexte.langue), etiquette: contexte.etiquettes[zaap.cle],
                detail: Coordonnees.texte(zaap.x, zaap.y), favori: contexte.favoris.contains(zaap.cle),
                distance: CatalogueZaaps.distance(de: zaap, depuis: contexte.position), cle: zaap.cle,
                effet: .trajet(x: zaap.x, y: zaap.y))
        }
    }

    /// Favoris d'abord, puis du plus proche au plus loin.
    private static func zaapsTries(_ contexte: ContextePalette) -> [Zaap] {
        let proches = CatalogueZaaps.parDistance(contexte.zaaps, depuis: contexte.position)
        return proches.filter { contexte.favoris.contains($0.cle) } + proches.filter { !contexte.favoris.contains($0.cle) }
    }

    static func lieux(_ contexte: ContextePalette) -> [EntreePalette] {
        contexte.lieux.filter { !$0.estZaap }.map { lieu in
            let distance = distanceVers(lieu, contexte)
            let lieuDit = [lieu.sousZone(en: contexte.langue), lieu.zone(en: contexte.langue)]
                .compactMap { $0 }.joined(separator: " · ")
            let sousTitre = distance.map { L("palette.aCartes", lieuDit, $0) } ?? lieuDit
            return EntreePalette(
                id: lieu.cle, genre: .lieu, titre: lieu.nom(en: contexte.langue), sousTitre: sousTitre,
                etiquette: contexte.etiquettes[lieu.cle], detail: Coordonnees.texte(lieu.x, lieu.y),
                favori: contexte.favoris.contains(lieu.cle), distance: distance, categorie: lieu.categorie, recherche: lieuDit, cle: lieu.cle,
                effet: lieu.monde == Zaap.mondeDesDouze ? .trajet(x: lieu.x, y: lieu.y)
                                                        : .copier(ItineraireZaap.travel(vers: (lieu.x, lieu.y))))
        }
    }

    private static func invitations(_ contexte: ContextePalette) -> [EntreePalette] {
        var entrees: [EntreePalette] = []
        if let equipe = contexte.invitationEquipe {
            entrees.append(EntreePalette(id: "invite:equipe", genre: .action, titre: L("palette.action.inviter"),
                                         detail: equipe, effet: .copier(equipe)))
        }
        entrees += contexte.invitations.map {
            EntreePalette(id: "invite:" + $0.nom, genre: .perso, titre: $0.nom, detail: $0.commande,
                          effet: .copier($0.commande))
        }
        return entrees
    }

    /// Les commandes dont le texte commence par ce qui est tapé.
    private static func commandes(_ texte: String) -> [EntreePalette] {
        let tape = normaliser(texte)
        return CommandeJeu.allCases
            .filter { normaliser($0.texte).hasPrefix(tape) || tape.hasPrefix(normaliser($0.texte) + " ") }
            .map { commande in
                let effet: EntreePalette.Effet = commande.argument == nil
                    ? .copier(commande.texte) : .completer(commande.texte + " ")
                return EntreePalette(id: "cmd:" + commande.texte, genre: .commande, titre: commande.texte,
                                     sousTitre: commande.description, detail: commande.argument, effet: effet)
            }
    }

    private static func variables(_ texte: String) -> [EntreePalette] {
        let tape = normaliser(texte).trimmingCharacters(in: CharacterSet(charactersIn: "%"))
        return VariableJeu.allCases
            .filter { tape.isEmpty || $0.rawValue.hasPrefix(tape) }
            .map { EntreePalette(id: "var:" + $0.rawValue, genre: .variable, titre: $0.texte,
                                 sousTitre: $0.description, effet: .copier($0.texte)) }
    }

    /// Les gestes et les dernières copies : ce que `tout` ajoute aux zaaps,
    /// lieux, quêtes et PNJ.
    static func divers(_ contexte: ContextePalette) -> [EntreePalette] {
        let actions = ActionPalette.allCases.map {
            EntreePalette(id: "action:\($0)", genre: .action, titre: $0.titre, effet: .action($0))
        }
        return actions + recents(contexte)
    }

    // MARK: - Quêtes et PNJ

    static func quetes(_ contexte: ContextePalette) -> [EntreePalette] {
        (contexte.quetes?.quetes ?? []).map { quete in
            EntreePalette(id: "quete:\(quete.id)", genre: .quete, titre: Lieu.traduit(quete.noms, contexte.langue) ?? "?",
                          sousTitre: L("palette.quete.resume", quete.niveau, quete.etapes.count),
                          effet: .ouvrirQuete(quete.id))
        }
    }

    /// Un PNJ par position connue, avec sa zone : celle que le plus de quêtes
    /// citent est dite habituelle, les autres « aussi ici ».
    static func pnjs(_ contexte: ContextePalette) -> [EntreePalette] {
        guard let quetes = contexte.quetes else { return [] }
        let inconnu = L("palette.pnj")
        return quetes.pnjs.flatMap { pnj in
            pnj.passages.enumerated().map { rang, passage in
                let position = passage.position
                let sousZone = passage.sousZone.flatMap { quetes.sousZones[String($0)] }
                let lieu = sousZone.map {
                    [Lieu.traduit($0.noms, contexte.langue), Lieu.traduit($0.zone, contexte.langue)]
                        .compactMap { $0 }.joined(separator: " · ")
                } ?? inconnu
                let sousTitre = rang == 0 && pnj.passages.count > 1
                    ? L("palette.pnj.habituel", lieu, passage.quetes)
                    : rang == 0 ? L("palette.pnj.cite", lieu, passage.quetes) : L("palette.pnj.aussi", lieu, passage.quetes)
                return EntreePalette(id: "pnj:\(pnj.id):\(position.x),\(position.y)", genre: .pnj,
                                     titre: Lieu.traduit(pnj.noms, contexte.langue) ?? "?", sousTitre: sousTitre,
                                     detail: Coordonnees.texte(position.x, position.y), distance: distance(vers: position, contexte),
                                     effet: .trajet(x: position.x, y: position.y))
            }
        }
    }

    private static func distance(vers position: PNJ.Position, _ contexte: ContextePalette) -> Int? {
        guard let depuis = contexte.position, !ItineraireZaap.horsDuMondeDesDouze(depuis.zone) else { return nil }
        return ItineraireZaap.distance((depuis.x, depuis.y), (position.x, position.y))
    }

    /// Les dernières copies : au-dessus des zaaps quand rien n'est tapé, et
    /// cherchées comme le reste.
    static func recents(_ contexte: ContextePalette) -> [EntreePalette] {
        contexte.recents.enumerated().map {
            EntreePalette(id: "recent:\($0.offset)", genre: .recent, titre: $0.element,
                          sousTitre: L("palette.recent"), effet: .copier($0.element))
        }
    }

    static let nombreDeRecents = 8

    /// Le texte copié passe en tête ; un doublon remonte au lieu de se répéter.
    static func noterRecent(_ texte: String, dans recents: [String]) -> [String] {
        Array(([texte] + recents.filter { $0 != texte }).prefix(nombreDeRecents))
    }

    // MARK: - Trajets

    private static func trajet(vers cible: (x: Int, y: Int), _ contexte: ContextePalette) -> String {
        let travel = ItineraireZaap.travel(vers: cible)
        return ItineraireZaap.reecrire(travel, depuis: contexte.position, gainMinimal: contexte.gainMinimal,
                                       zaaps: contexte.zaaps, reseau: contexte.reseau) ?? travel
    }

    private static func distanceVers(_ lieu: Lieu, _ contexte: ContextePalette) -> Int? {
        guard let position = contexte.position, !ItineraireZaap.horsDuMondeDesDouze(position.zone),
              lieu.monde == Zaap.mondeDesDouze
        else { return nil }
        return ItineraireZaap.distance((position.x, position.y), (lieu.x, lieu.y))
    }

    // MARK: - Correspondance

    /// Les mots qu'un nom de lieu fait aussi répondre : les raccourcis des joueurs.
    private static let surnoms: [(motif: String, mots: [String])] = [
        ("forgemage", ["fm", "forgemagie"]),
        ("hotel de vente", ["hdv"]),
        ("consommables", ["conso"]),
        ("ressources", ["res", "ressource"]),
        ("equipements", ["equipement", "equip"]),
        ("bijoutiers", ["bijou", "bijoutier"]),
        ("cordonniers", ["cordo", "cordonnier"]),
        ("faconneurs", ["faco", "faconneur"]),
        ("tailleurs", ["tailleur"]),
        ("forgerons", ["forgeron"]),
        ("sculpteurs", ["sculpteur"]),
        ("alchimistes", ["alchi", "alchimiste"]),
        ("zaap", ["zaap"]),
    ]

    private static let motsDeCategorie: [Int: [String]] = [
        CategorieLieu.temple.rawValue: ["temple", "classe"],
        CategorieLieu.hotelDeVente.rawValue: ["hdv"],
        CategorieLieu.atelier.rawValue: ["atelier", "craft"],
        CategorieLieu.donjon.rawValue: ["donjon", "dj"],
        CategorieLieu.transport.rawValue: ["transport"],
    ]

    /// Garde les entrées dont chaque mot tapé trouve un écho, puis les range :
    /// les zaaps devant, les favoris en tête de chaque famille, puis le tri ;
    /// à égalité, la meilleure correspondance (étiquette, nom, zone).
    private static func classer(_ fiches: [Fiche], _ mots: [String], tri: TriPalette) -> [EntreePalette] {
        let retenues = fiches.enumerated().compactMap { rang, fiche -> (entree: EntreePalette, score: Int, rang: Int)? in
            var score = 0
            for mot in mots {
                let points = fiche.champs.points(mot)
                guard points > 0 else { return nil }
                score += points
            }
            return (fiche.entree, score, rang)
        }
        return retenues
            .sorted { a, b in
                let (ea, eb) = (a.entree, b.entree)
                if (ea.genre == .zaap) != (eb.genre == .zaap) { return ea.genre == .zaap }
                if ea.favori != eb.favori { return ea.favori }
                if let ordre = comparer(ea, eb, tri) { return ordre }
                if a.score != b.score { return a.score > b.score }
                return a.rang < b.rang
            }
            .prefix(limite)
            .map(\.entree)
    }

    /// `nil` à égalité.
    private static func comparer(_ a: EntreePalette, _ b: EntreePalette, _ tri: TriPalette) -> Bool? {
        switch tri {
        case .proximite:
            return comparerDistances(a, b)
        case .alphabetique:
            let ordre = a.titre.localizedStandardCompare(b.titre)
            return ordre == .orderedSame ? comparerDistances(a, b) : ordre == .orderedAscending
        case .type:
            let (ta, tb) = (rangDeType(a), rangDeType(b))
            return ta != tb ? ta < tb : comparerDistances(a, b)
        }
    }

    private static func comparerDistances(_ a: EntreePalette, _ b: EntreePalette) -> Bool? {
        switch (a.distance, b.distance) {
        case let (da?, db?) where da != db: return da < db
        case (_?, nil): return true
        case (nil, _?): return false
        default: return nil
        }
    }

    /// Persos, puis lieux par catégorie (temples, hôtels de vente, ateliers…),
    /// puis gestes et copies.
    private static func rangDeType(_ entree: EntreePalette) -> Int {
        switch entree.genre {
        case .zaap: return 0
        case .perso: return 1
        case .quete: return 120
        case .pnj: return 130
        case .lieu: return 10 + (entree.categorie ?? 99)
        case .action: return 200
        case .recent: return 300
        case .commande, .variable: return 400
        }
    }

    /// Une entrée et ses textes normalisés, prêts pour la recherche.
    struct Fiche: Sendable {
        let entree: EntreePalette
        let champs: Champs
    }

    /// Les textes d'une entrée, normalisés une fois — c'est ce qui coûte (une
    /// centaine de millisecondes pour tout le jeu) : `IndexPalette` les garde
    /// d'une ouverture à l'autre, par `cle`.
    struct Champs: Sendable {
        let etiquette: [String]
        let titre: [String]
        let lieu: [String]
        let surnoms: [String]

        /// Tout ce dont les champs dépendent : une entrée qui garde sa clé garde ses champs.
        static func cle(_ entree: EntreePalette) -> String {
            [entree.id, entree.titre, entree.etiquette ?? "", entree.recherche ?? entree.sousTitre ?? "",
             entree.categorie.map(String.init) ?? ""].joined(separator: "\u{1F}")
        }

        init(_ entree: EntreePalette) {
            self.init(titre: entree.titre, etiquette: entree.etiquette, lieu: entree.recherche ?? entree.sousTitre,
                      categorie: entree.categorie)
        }

        /// Aussi pour les listes des réglages, qui filtrent selon la même règle.
        init(titre: String, etiquette: String? = nil, lieu: String? = nil, categorie: Int? = nil) {
            self.etiquette = RecherchePalette.mots(etiquette ?? "")
            let nom = RecherchePalette.normaliser(titre)
            self.titre = RecherchePalette.decouper(nom)
            self.lieu = RecherchePalette.mots(lieu ?? "")
            surnoms = RecherchePalette.surnoms.filter { nom.contains($0.motif) }.flatMap(\.mots)
                + (categorie.flatMap { RecherchePalette.motsDeCategorie[$0] } ?? [])
        }

        /// Chaque mot tapé trouve un écho.
        func garde(_ mots: [String]) -> Bool {
            mots.allSatisfy { points($0) > 0 }
        }

        func points(_ mot: String) -> Int {
            if etiquette.contains(mot) { return 100 }
            if etiquette.contains(where: { $0.hasPrefix(mot) }) { return 80 }
            if titre.contains(where: { $0.hasPrefix(mot) }) { return 60 }
            if surnoms.contains(mot) { return 50 }
            if lieu.contains(where: { $0.hasPrefix(mot) }) { return 40 }
            if mot.count >= 3, (titre + lieu).contains(where: { $0.contains(mot) }) { return 20 }
            return 0
        }
    }

    // MARK: - Texte

    static func normaliser(_ texte: String) -> String {
        texte.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
    }

    /// Les mots d'un texte, normalisés ; l'apostrophe sépare (« d'Amakna »).
    static func mots(_ texte: String) -> [String] {
        decouper(normaliser(texte))
    }

    static func decouper(_ normalise: String) -> [String] {
        normalise.split(whereSeparator: { $0.isWhitespace || "'·,()-".contains($0) }).map(String.init)
    }

    private static func separer(_ texte: String) -> (commande: String, reste: String) {
        guard let espace = texte.firstIndex(of: " ") else { return (normaliser(texte), "") }
        return (normaliser(String(texte[..<espace])),
                String(texte[texte.index(after: espace)...]).trimmingCharacters(in: .whitespaces))
    }
}

/// Les fiches d'un contexte, construites une fois puis cherchées à chaque
/// frappe : normaliser des milliers de noms (quêtes, PNJ) à chaque lettre
/// rendrait la palette poussive.
final class IndexPalette {
    let contexte: ContextePalette
    /// Les champs déjà normalisés, d'un index précédent ou de la préchauffe.
    let connus: [String: RecherchePalette.Champs]

    init(_ contexte: ContextePalette, connus: [String: RecherchePalette.Champs] = [:]) {
        self.contexte = contexte
        self.connus = connus
    }

    private func fiches(_ entrees: [EntreePalette]) -> [RecherchePalette.Fiche] {
        RecherchePalette.fiches(entrees, connus: connus)
    }

    private(set) lazy var zaaps = fiches(RecherchePalette.zaaps(contexte))
    private(set) lazy var zaapsCommeLieux = fiches(RecherchePalette.zaapsCommeLieux(contexte))
    private(set) lazy var lieux = fiches(RecherchePalette.lieux(contexte))
    private(set) lazy var quetes = fiches(RecherchePalette.quetes(contexte))
    private(set) lazy var pnjs = fiches(RecherchePalette.pnjs(contexte))
    /// Sans préfixe : zaaps, lieux, quêtes, PNJ, gestes, dernières copies.
    private(set) lazy var tout = zaaps + lieux + quetes + pnjs + fiches(RecherchePalette.divers(contexte))

    /// Les champs de toutes les fiches, à garder pour l'index suivant.
    static func champs(de contexte: ContextePalette, connus: [String: RecherchePalette.Champs] = [:])
        -> [String: RecherchePalette.Champs] {
        let index = IndexPalette(contexte, connus: connus)
        return Dictionary((index.tout + index.zaapsCommeLieux).map { (RecherchePalette.Champs.cle($0.entree), $0.champs) },
                          uniquingKeysWith: { a, _ in a })
    }
}
