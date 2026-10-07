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
/// `/` (commandes), `%` (variables) — ; sans préfixe, tout se cherche.
enum RecherchePalette {
    static let limite = 60

    static func entrees(_ requete: String, _ contexte: ContextePalette) -> [EntreePalette] {
        let texte = requete.trimmingCharacters(in: .whitespaces)
        if texte.isEmpty { return zaaps(contexte) }
        if texte.hasPrefix("%") { return variables(texte) }
        guard texte.hasPrefix("/") else {
            return classer(tout(contexte), mots(texte), contexte)
        }
        let (commande, reste) = separer(texte)
        switch commande {
        case "/zaap": return classer(zaaps(contexte), mots(reste), contexte)
        case "/travel":
            if let cible = ItineraireZaap.cible(dans: "/travel " + reste) {
                let copie = trajet(vers: cible, contexte)
                return [EntreePalette(id: "travel", genre: .lieu, titre: copie, detail: "\(cible.x),\(cible.y)",
                                      effet: .copier(copie))]
            }
            return classer(lieux(contexte) + zaapsCommeLieux(contexte), mots(reste), contexte)
        case "/invite": return classer(invitations(contexte), mots(reste), contexte)
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
                favori: contexte.favoris.contains(lieu.cle), distance: distance, cle: lieu.cle,
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

    /// Garde les entrées dont chaque mot tapé trouve un écho, les meilleures
    /// d'abord : étiquette, puis nom, puis zone ; favoris et proches devant.
    private static func classer(_ entrees: [EntreePalette], _ mots: [String],
                                _ contexte: ContextePalette) -> [EntreePalette] {
        guard !mots.isEmpty else { return Array(entrees.prefix(limite)) }
        let categories = Dictionary(contexte.lieux.map { ($0.cle, $0.categorie) }, uniquingKeysWith: { a, _ in a })
        return entrees
            .compactMap { entree -> (EntreePalette, Int)? in
                let champs = Champs(entree, categorie: entree.cle.flatMap { categories[$0] })
                var score = 0
                for mot in mots {
                    let points = champs.points(mot)
                    guard points > 0 else { return nil }
                    score += points
                }
                if entree.favori { score += 30 }
                return (entree, score)
            }
            .enumerated()
            .sorted { a, b in
                if a.element.1 != b.element.1 { return a.element.1 > b.element.1 }
                switch (a.element.0.distance, b.element.0.distance) {
                case let (da?, db?) where da != db: return da < db
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.offset < b.offset
                }
            }
            .prefix(limite)
            .map(\.element.0)
    }

    /// Les textes d'une entrée, normalisés une fois.
    private struct Champs {
        let etiquette: [String]
        let titre: [String]
        let lieu: [String]
        let surnoms: [String]

        init(_ entree: EntreePalette, categorie: Int?) {
            etiquette = RecherchePalette.mots(entree.etiquette ?? "")
            titre = RecherchePalette.mots(entree.titre)
            lieu = RecherchePalette.mots(entree.sousTitre ?? "")
            let nom = RecherchePalette.normaliser(entree.titre)
            surnoms = RecherchePalette.surnoms.filter { nom.contains($0.motif) }.flatMap(\.mots)
                + (categorie.flatMap { RecherchePalette.motsDeCategorie[$0] } ?? [])
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
