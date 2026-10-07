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
    case tout, zaaps, lieux, persos

    var titre: String {
        switch self {
        case .tout: return L("palette.filtre.tout")
        case .zaaps: return L("palette.filtre.zaaps")
        case .lieux: return L("palette.filtre.lieux")
        case .persos: return L("palette.filtre.persos")
        }
    }

    func garde(_ genre: EntreePalette.Genre) -> Bool {
        switch self {
        case .tout: return true
        case .zaaps: return genre == .zaap
        case .lieux: return genre == .lieu
        case .persos: return genre == .perso
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
    enum Genre: Equatable, Sendable { case zaap, lieu, commande, variable, perso, action, recent }

    enum Effet: Equatable, Sendable {
        /// Pose le texte dans le presse-papiers et ferme.
        case copier(String)
        /// Remplace la recherche, la palette reste ouverte (`/w ` à compléter).
        case completer(String)
        case basculer(slotKey: String)
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
    var lieux: [Lieu] = []
    var etiquettes: [String: String] = [:]
    var favoris: Set<String> = []
    /// Les derniers textes copiés depuis la palette, le plus récent d'abord.
    var recents: [String] = []
    var persos: [(nom: String, slotKey: String)] = []
    var gainMinimal = ItineraireZaap.gainParDefaut
    /// `/invite A; /invite B` pour l'équipe active, déjà composé.
    var invitationEquipe: String?
    var invitations: [(nom: String, commande: String)] = []
}

/// La recherche de la palette. Pure : un texte et un contexte, des entrées
/// triées. Les préfixes choisissent le mode — `/zaap`, `/travel`, `/invite`,
/// `/` (commandes), `%` (variables) — ; sans préfixe, tout se cherche, dans
/// la famille du filtre. Les zaaps passent toujours devant, puis le tri.
enum RecherchePalette {
    static let limite = 200

    static func entrees(_ requete: String, _ contexte: ContextePalette,
                        filtre: FiltrePalette = .tout, tri: TriPalette = .proximite) -> [EntreePalette] {
        let texte = requete.trimmingCharacters(in: .whitespaces)
        func classer(_ entrees: [EntreePalette], _ mots: [String]) -> [EntreePalette] {
            RecherchePalette.classer(entrees, mots, tri: tri)
        }
        if texte.isEmpty {
            // La grille des zaaps, favoris d'abord puis du plus proche — sauf
            // filtre sur une autre famille, montrée entière.
            if filtre == .tout || filtre == .zaaps { return zaaps(contexte) }
            return classer(tout(contexte).filter { filtre.garde($0.genre) }, [])
        }
        if texte.hasPrefix("%") { return variables(texte) }
        guard texte.hasPrefix("/") else {
            return classer(tout(contexte).filter { filtre.garde($0.genre) }, mots(texte))
        }
        let (commande, reste) = separer(texte)
        switch commande {
        case "/zaap": return classer(zaaps(contexte), mots(reste))
        case "/travel":
            if let cible = ItineraireZaap.cible(dans: "/travel " + reste) {
                let copie = trajet(vers: cible, contexte)
                return [EntreePalette(id: "travel", genre: .lieu, titre: copie, detail: "\(cible.x),\(cible.y)",
                                      effet: .copier(copie))]
            }
            return classer(lieux(contexte) + zaapsCommeLieux(contexte), mots(reste))
        case "/invite": return classer(invitations(contexte), mots(reste))
        default: return commandes(texte)
        }
    }

    // MARK: - Modes

    /// Les zaaps, favoris d'abord puis du plus proche au plus loin.
    private static func zaaps(_ contexte: ContextePalette) -> [EntreePalette] {
        zaapsTries(contexte).map { zaap in
            EntreePalette(
                id: "zaap:" + zaap.cle, genre: .zaap, titre: zaap.nom(en: contexte.langue),
                sousTitre: zaap.zone(en: contexte.langue), etiquette: contexte.etiquettes[zaap.cle],
                detail: "\(zaap.x),\(zaap.y)", favori: contexte.favoris.contains(zaap.cle),
                distance: CatalogueZaaps.distance(de: zaap, depuis: contexte.position), cle: zaap.cle,
                effet: .copier(ItineraireZaap.zaap(zaap)))
        }
    }

    /// Un zaap cherché par `/travel` : le trajet vers lui, comme vers un lieu.
    private static func zaapsCommeLieux(_ contexte: ContextePalette) -> [EntreePalette] {
        zaapsTries(contexte).map { zaap in
            EntreePalette(
                id: "travel:" + zaap.cle, genre: .lieu, titre: L("palette.zaap", zaap.nom(en: contexte.langue)),
                sousTitre: zaap.zone(en: contexte.langue), etiquette: contexte.etiquettes[zaap.cle],
                detail: "\(zaap.x),\(zaap.y)", favori: contexte.favoris.contains(zaap.cle),
                distance: CatalogueZaaps.distance(de: zaap, depuis: contexte.position), cle: zaap.cle,
                effet: .copier(trajet(vers: (zaap.x, zaap.y), contexte)))
        }
    }

    /// Favoris d'abord, puis du plus proche au plus loin.
    private static func zaapsTries(_ contexte: ContextePalette) -> [Zaap] {
        let proches = CatalogueZaaps.parDistance(contexte.zaaps, depuis: contexte.position)
        return proches.filter { contexte.favoris.contains($0.cle) } + proches.filter { !contexte.favoris.contains($0.cle) }
    }

    private static func lieux(_ contexte: ContextePalette) -> [EntreePalette] {
        contexte.lieux.filter { !$0.estZaap }.map { lieu in
            let distance = distanceVers(lieu, contexte)
            let lieuDit = [lieu.sousZone(en: contexte.langue), lieu.zone(en: contexte.langue)]
                .compactMap { $0 }.joined(separator: " · ")
            let sousTitre = distance.map { L("palette.aCartes", lieuDit, $0) } ?? lieuDit
            return EntreePalette(
                id: lieu.cle, genre: .lieu, titre: lieu.nom(en: contexte.langue), sousTitre: sousTitre,
                etiquette: contexte.etiquettes[lieu.cle], detail: "\(lieu.x),\(lieu.y)",
                favori: contexte.favoris.contains(lieu.cle), distance: distance, categorie: lieu.categorie, cle: lieu.cle,
                effet: .copier(lieu.monde == Zaap.mondeDesDouze ? trajet(vers: (lieu.x, lieu.y), contexte)
                                                                : ItineraireZaap.travel(vers: (lieu.x, lieu.y))))
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

    /// Sans préfixe : zaaps, lieux, persos, gestes et dernières copies ensemble.
    private static func tout(_ contexte: ContextePalette) -> [EntreePalette] {
        let persos = contexte.persos.map {
            EntreePalette(id: "perso:" + $0.slotKey, genre: .perso, titre: $0.nom,
                          sousTitre: L("palette.perso"), effet: .basculer(slotKey: $0.slotKey))
        }
        let actions = ActionPalette.allCases.map {
            EntreePalette(id: "action:\($0)", genre: .action, titre: $0.titre, effet: .action($0))
        }
        return zaaps(contexte) + lieux(contexte) + persos + actions + recents(contexte)
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
                                       zaaps: contexte.zaaps) ?? travel
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
    private static func classer(_ entrees: [EntreePalette], _ mots: [String], tri: TriPalette) -> [EntreePalette] {
        let retenues = entrees.enumerated().compactMap { rang, entree -> (entree: EntreePalette, score: Int, rang: Int)? in
            let champs = Champs(entree)
            var score = 0
            for mot in mots {
                let points = champs.points(mot)
                guard points > 0 else { return nil }
                score += points
            }
            return (entree, score, rang)
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
        case .lieu: return 10 + (entree.categorie ?? 99)
        case .action: return 200
        case .recent: return 300
        case .commande, .variable: return 400
        }
    }

    /// Les textes d'une entrée, normalisés une fois.
    private struct Champs {
        let etiquette: [String]
        let titre: [String]
        let lieu: [String]
        let surnoms: [String]

        init(_ entree: EntreePalette) {
            etiquette = RecherchePalette.mots(entree.etiquette ?? "")
            titre = RecherchePalette.mots(entree.titre)
            lieu = RecherchePalette.mots(entree.sousTitre ?? "")
            let nom = RecherchePalette.normaliser(entree.titre)
            surnoms = RecherchePalette.surnoms.filter { nom.contains($0.motif) }.flatMap(\.mots)
                + (entree.categorie.flatMap { RecherchePalette.motsDeCategorie[$0] } ?? [])
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
        normaliser(texte)
            .split(whereSeparator: { $0.isWhitespace || "'·,()-".contains($0) })
            .map(String.init)
    }

    private static func separer(_ texte: String) -> (commande: String, reste: String) {
        guard let espace = texte.firstIndex(of: " ") else { return (normaliser(texte), "") }
        return (normaliser(String(texte[..<espace])),
                String(texte[texte.index(after: espace)...]).trimmingCharacters(in: .whitespaces))
    }
}
