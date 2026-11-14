import Foundation

/// Les gestes de Synfus que la palette sait faire, tapés en toutes lettres.
enum ActionPalette: Equatable, Sendable {
    case rangerFenetres, lancerSession, equipeSuivante, inviterEquipe, quetes, chasse, reglages
    /// L'aide au combat contre ce boss : le nom du boss se tape aussi.
    case boss(CibleBoss, nom: String)

    /// Les gestes de toujours ; l'aide aux boss de donjon s'y ajoute avec
    /// leur liste (`RecherchePalette.divers`).
    static var toutes: [ActionPalette] {
        [.rangerFenetres, .lancerSession, .equipeSuivante, .inviterEquipe, .quetes, .chasse]
            + Boss.allCases.map { .boss(.special($0), nom: BossVue.nom($0)) } + [.reglages]
    }

    var titre: String {
        switch self {
        case .rangerFenetres: return L("palette.action.ranger")
        case .lancerSession: return L("palette.action.session")
        case .equipeSuivante: return L("palette.action.equipe")
        case .inviterEquipe: return L("palette.action.inviter")
        case .quetes: return L("palette.action.quetes")
        case .chasse: return L("palette.action.chasse")
        case .boss(_, let nom): return L("palette.action.boss", nom)
        case .reglages: return L("palette.action.reglages")
        }
    }
}

/// Ce que Tab fait défiler : la famille de résultats montrée — les zaaps sont
/// des lieux, PNJ, monstres et boss des créatures —, ou ce qui est sur la case
/// du perso (`ici`) : quêtes qui y commencent, PNJ, lieux.
enum FiltrePalette: CaseIterable, Sendable {
    case tout, lieux, quetes, creatures, objets, ici

    var titre: String {
        switch self {
        case .tout: return L("palette.filtre.tout")
        case .lieux: return L("palette.filtre.lieux")
        case .quetes: return L("palette.filtre.quetes")
        case .creatures: return L("palette.filtre.creatures")
        case .objets: return L("palette.filtre.objets")
        case .ici: return L("palette.filtre.ici")
        }
    }

    func garde(_ entree: EntreePalette) -> Bool {
        switch self {
        case .tout: return true
        case .lieux: return entree.genre == .zaap || entree.genre == .lieu
        case .quetes: return entree.genre == .quete
        case .creatures: return entree.genre == .pnj || entree.genre == .monstre
        case .objets: return entree.genre == .objet
        case .ici: return entree.ici
        }
    }

    /// Le suivant (Tab) ou le précédent (⇧Tab), en boucle.
    func suivant(_ pas: Int) -> FiltrePalette {
        let tous = Self.allCases
        return tous[(tous.firstIndex(of: self)! + pas + tous.count) % tous.count]
    }
}

/// L'ordre des résultats : « Auto » (`ScorePalette`), ou un tri explicite
/// après les zaaps, qui y passent toujours devant.
enum TriPalette: String, CaseIterable, Sendable {
    case auto, proximite, alphabetique, type

    var titre: String {
        switch self {
        case .auto: return L("commun.auto")
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
    enum Genre: Equatable, Sendable {
        case zaap, lieu, commande, variable, perso, action, recent, quete, pnj, monstre, objet

        /// Monstres et objets se cherchent par milliers : dans « Tout », après
        /// le reste, pour ne pas noyer zaaps et lieux.
        var enDernier: Bool { self == .monstre || self == .objet }
    }

    enum Effet: Equatable, Sendable {
        /// Pose le texte dans le presse-papiers et ferme.
        case copier(String)
        /// Remplace la recherche, la palette reste ouverte (`/w ` à compléter).
        case completer(String)
        /// Ouvre la quête dans son panneau : étapes, objectifs, ressources.
        case ouvrirQuete(Int)
        /// Déplie sous la ligne où trouver le monstre ou l'objet (`OuTrouverVue`).
        case ouTrouver(OuTrouver.Sujet)
        /// Déplie sous la ligne la fiche du donjon (`FicheDonjonVue`) : un
        /// donjon de la carte ou l'un de ses boss.
        case donjon(Int)
        /// Copie le trajet vers la case, zaap compris s'il vaut le coup —
        /// calculé seulement pour l'entrée choisie (`texte(de:)`).
        case trajet(x: Int, y: Int, sousZone: Int?)
        case action(ActionPalette)

        /// Entrée déplie quelque chose sous la ligne plutôt que de copier.
        var sePlie: Bool {
            switch self {
            case .ouTrouver, .donjon: return true
            case .copier, .completer, .ouvrirQuete, .trajet, .action: return false
            }
        }
    }

    let id: String
    let genre: Genre
    let titre: String
    var sousTitre: String?
    /// Nom, lieu et trajet en entier : l'infobulle d'une entrée coupée.
    var complet: String { [titre, sousTitre, itineraire].compactMap(\.self).joined(separator: " · ") }
    var etiquette: String?
    /// À droite : coordonnées, commande copiée.
    var detail: String?
    var favori = false
    /// Les cartes depuis le perso devant, à pied, quand elles veulent dire
    /// quelque chose : départage deux résultats aussi bons. Pas celles du
    /// trajet : tout ce qui jouxte un zaap y paraîtrait à une carte.
    var distance: Int?
    /// Le trajet copié, dit en clair : « via Coin des Bouftous · 6 cartes »,
    /// « 6 cartes à pied ». Jamais cherché.
    var itineraire: String?
    /// La catégorie DofusDB d'un lieu (`CategorieLieu`) : le tri par type.
    var categorie: Int?
    /// Ce qu'une étiquette ou un favori désigne (`Zaap.cle`, `Lieu.cle`) ;
    /// `nil` pour ce qui ne s'étiquette pas.
    var cle: String?
    /// La carte du jeu de l'entrée, dont la liste montre la vue.
    var carte: Int?
    /// Le pictogramme d'un lieu (`Lieu.gfx`), à la place du symbole.
    var pictogramme: Int?
    /// Sur la case du perso : une quête qui y commence, un PNJ, un lieu.
    var ici = false
    /// Sa carte n'est pas en extérieur : le trajet mène devant le bâtiment.
    var interieur = false
    /// Le symbole propre à l'entrée (une commande, une variable) ; `nil` : celui de son genre.
    var symbole: String?
    let effet: Effet

    /// La fiche d'un boss de donjon (`RecherchePalette.boss`) ou l'aide à son combat.
    var estBoss: Bool {
        switch effet {
        case .donjon: return genre == .monstre
        case .action(.boss): return true
        default: return false
        }
    }

    /// Après le reste : les monstres et objets par milliers, sauf les boss, qu'on cherche exprès.
    var enDernier: Bool { genre.enDernier && !estBoss }
}

/// Ce que la recherche doit savoir du monde, figé à l'ouverture.
struct ContextePalette: Sendable {
    var langue: Langue = .fr
    /// Le perso dont la position est celle-ci : d'où partent les trajets.
    var perso: String?
    var position: PositionCarte?
    /// Les zaaps actifs, et d'où partir vers une case (`ItineraireZaap.zaap(vers:)`).
    var zaaps = ZaapsSitues.vide
    /// Le réseau de `zaaps`, une seule source : il situe aussi ce qui est ici.
    var reseau: ReseauSousZones { zaaps.reseau }
    var lieux: [Lieu] = []
    var interieurs = CartesInterieures.vide
    var etiquettes: [String: String] = [:]
    var favoris: Set<String> = []
    /// Les derniers textes copiés depuis la palette, le plus récent d'abord.
    var recents: [String] = []
    var gainMinimal = ItineraireZaap.gainParDefaut
    var zaapDuJeu = true
    var intercalees: [String] = []
    /// `/invite A; /invite B` pour l'équipe active, déjà composé.
    var invitationEquipe: String?
    var invitations: [(nom: String, commande: String)] = []
    /// `nil` tant qu'elles ne sont pas téléchargées.
    var quetes: Quetes?
    /// `nil` tant qu'ils ne sont pas téléchargés.
    var donjons: Donjons?
    /// Les habitudes, que le tri « Auto » fait remonter.
    var frequentation = FrequentationPalette()
}

/// La recherche de la palette. Pure : un texte et un contexte, des entrées
/// triées. Les préfixes choisissent le mode — `/zaap`, `/travel`, `/invite`,
/// `/` (commandes), `%` (variables) — ; sans préfixe, tout se cherche, dans
/// la famille du filtre, rangé par le tri.
enum RecherchePalette {
    static let limite = 200

    static func entrees(_ requete: String, _ contexte: ContextePalette,
                        filtre: FiltrePalette = .tout, tri: TriPalette = .auto) -> [EntreePalette] {
        entrees(requete, IndexPalette(contexte), filtre: filtre, tri: tri)
    }

    static func entrees(_ requete: String, _ index: IndexPalette,
                        filtre: FiltrePalette = .tout, tri: TriPalette = .auto) -> [EntreePalette] {
        let texte = requete.trimmingCharacters(in: .whitespaces)
        func classer(_ fiches: [Fiche], _ mots: [String]) -> [EntreePalette] {
            RecherchePalette.classer(fiches, mots, tri: tri, frequentation: index.contexte.frequentation)
        }
        if texte.isEmpty {
            // La grille : tous les favoris d'abord — zaaps, lieux, PNJ —, puis
            // les autres zaaps du plus proche ; sauf filtre sur une famille,
            // montrée entière.
            if filtre == .tout { return index.accueil }
            return classer(index.tout.filter { filtre.garde($0.entree) }, [])
        }
        if texte.hasPrefix("%") { return variables(texte) }
        if let cible = ItineraireZaap.caseTapee(texte) {
            return [versUneCase(cible, index.contexte)].filter(filtre.garde)
        }
        guard texte.hasPrefix("/") else {
            return classer(index.tout.filter { filtre.garde($0.entree) }, mots(texte))
        }
        let (commande, reste) = separer(texte)
        switch commande {
        case "/zaap": return classer(index.zaaps, mots(reste))
        case "/travel":
            if let cible = ItineraireZaap.cible(dans: "/travel " + reste) {
                let copie = trajet(vers: cible, sousZone: nil, index.contexte)
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
        case .trajet(let x, let y, let sousZone): return trajet(vers: (x, y), sousZone: sousZone, contexte)
        case .completer, .action, .ouvrirQuete, .ouTrouver, .donjon: return nil
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
                carte: zaap.idCarte, effet: .copier(ItineraireZaap.zaap(zaap)))
        }
    }

    /// Un zaap cherché par `/travel` : le trajet vers lui, comme vers un lieu.
    static func zaapsCommeLieux(_ contexte: ContextePalette) -> [EntreePalette] {
        zaapsTries(contexte).map { zaap in
            let sousZone = contexte.reseau.sousZone(du: zaap)
            let vers = versCase((zaap.x, zaap.y), sousZone: sousZone,
                                dansLesDouze: zaap.monde == Zaap.mondeDesDouze || sousZone != nil, contexte)
            return EntreePalette(
                id: "travel:" + zaap.cle, genre: .lieu, titre: L("palette.zaap", zaap.nom(en: contexte.langue)),
                sousTitre: zaap.zone(en: contexte.langue), etiquette: contexte.etiquettes[zaap.cle],
                detail: Coordonnees.texte(zaap.x, zaap.y), favori: contexte.favoris.contains(zaap.cle),
                distance: vers.distance, itineraire: itineraire(vers.trajet, contexte.langue), cle: zaap.cle,
                carte: zaap.idCarte, effet: vers.effet)
        }
    }

    /// Sans rien taper : les favoris, les plus choisis puis les plus proches
    /// (`ScorePalette`), puis les autres zaaps. Un PNJ n'y paraît qu'à sa
    /// position habituelle.
    static func accueil(_ contexte: ContextePalette, zaaps: [EntreePalette], lieux: [EntreePalette]) -> [EntreePalette] {
        let favorisPNJ = pnjs(contexte, seulement: contexte.favoris.filter { $0.hasPrefix(PNJ.prefixeCle) })
        let favoris = (zaaps + lieux + favorisPNJ).filter(\.favori)
        let scores = favoris.map {
            ScorePalette($0, correspondance: nil, compte: contexte.frequentation.compte(de: $0))
        }
        let ordre = favoris.indices.sorted { ScorePalette.avant(scores[$0], scores[$1]) ?? ($0 < $1) }
        return ordre.map { favoris[$0] } + zaaps.filter { !$0.favori }
    }

    /// Favoris d'abord, puis du plus proche au plus loin.
    private static func zaapsTries(_ contexte: ContextePalette) -> [Zaap] {
        let proches = CatalogueZaaps.parDistance(contexte.zaaps.liste, depuis: contexte.position)
        return proches.filter { contexte.favoris.contains($0.cle) } + proches.filter { !contexte.favoris.contains($0.cle) }
    }

    static func lieux(_ contexte: ContextePalette) -> [EntreePalette] {
        contexte.lieux.filter { !$0.estZaap }.map { lieu in
            let vers = versLieu(lieu, contexte)
            // Un donjon déplie sa fiche, qui copie aussi son trajet.
            let donjon = lieu.categorie == CategorieLieu.donjon.rawValue ? contexte.donjons?.donjon(de: lieu) : nil
            let lieuDit = [lieu.sousZone(en: contexte.langue), lieu.zone(en: contexte.langue)]
                .compactMap { $0 }.joined(separator: " · ")
            return EntreePalette(
                id: lieu.cle, genre: .lieu, titre: lieu.nom(en: contexte.langue), sousTitre: lieuDit,
                etiquette: contexte.etiquettes[lieu.cle], detail: Coordonnees.texte(lieu.x, lieu.y),
                favori: contexte.favoris.contains(lieu.cle), distance: vers.distance,
                itineraire: itineraire(vers.trajet, contexte.langue), categorie: lieu.categorie, cle: lieu.cle,
                carte: lieu.idCarte, pictogramme: lieu.gfx,
                ici: contexte.position.map { QuetesIci.ici(PNJ.Position(x: lieu.x, y: lieu.y), sousZone: lieu.idSousZone,
                                                          perso: $0, reseau: contexte.reseau) } ?? false,
                interieur: contexte.interieurs.contient(lieu.idCarte), effet: donjon.map { .donjon($0.id) } ?? vers.effet)
        }
    }

    /// Les boss de donjon : leur nom déplie la fiche de leur donjon, la même
    /// que le donjon cherché par son nom.
    static func boss(_ contexte: ContextePalette) -> [EntreePalette] {
        guard let donjons = contexte.donjons else { return [] }
        return donjons.nomsBoss.compactMap { id, noms in
            guard let nom = Lieu.traduit(noms, contexte.langue), let donjon = donjons.donjon(boss: id) else { return nil }
            let lieu = Lieu.traduit(donjon.noms, contexte.langue) ?? "?"
            return EntreePalette(id: "boss:\(id)", genre: .monstre, titre: nom, sousTitre: L("palette.boss", lieu),
                                 effet: .donjon(donjon.id))
        }
        .alphabetiques()
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
                                     sousTitre: commande.description, detail: commande.argument,
                                     symbole: commande.symbole, effet: effet)
            }
    }

    private static func variables(_ texte: String) -> [EntreePalette] {
        let tape = normaliser(texte).trimmingCharacters(in: CharacterSet(charactersIn: "%"))
        return VariableJeu.allCases
            .filter { tape.isEmpty || $0.rawValue.hasPrefix(tape) }
            .map { EntreePalette(id: "var:" + $0.rawValue, genre: .variable, titre: $0.texte,
                                 sousTitre: $0.description, symbole: $0.symbole, effet: .copier($0.texte)) }
    }

    /// Les gestes et les dernières copies : ce que `tout` ajoute aux zaaps,
    /// lieux, quêtes et PNJ.
    static func divers(_ contexte: ContextePalette) -> [EntreePalette] {
        let actions = (ActionPalette.toutes + aideAuxBoss(contexte)).map {
            EntreePalette(id: "action:\($0)", genre: .action, titre: $0.titre, effet: .action($0))
        }
        return actions + recents(contexte)
    }

    /// L'aide au combat de chaque boss de donjon dont l'aide ne connaît pas
    /// la mécanique — les autres sont déjà dans `ActionPalette.toutes`.
    static func aideAuxBoss(_ contexte: ContextePalette) -> [ActionPalette] {
        guard let donjons = contexte.donjons else { return [] }
        return donjons.nomsBoss.compactMap { id, noms -> ActionPalette? in
            guard let donjon = donjons.donjon(boss: id), let nom = Lieu.traduit(noms, contexte.langue) else { return nil }
            let cible = CibleBoss.boss(id, donjon: donjon.id)
            return cible.special == nil ? .boss(cible, nom: nom) : nil
        }
        .sorted { $0.titre.localizedStandardCompare($1.titre) == .orderedAscending }
    }

    // MARK: - Quêtes et PNJ

    static func quetes(_ contexte: ContextePalette) -> [EntreePalette] {
        (contexte.quetes?.quetes ?? []).map { quete in
            EntreePalette(id: "quete:\(quete.id)", genre: .quete, titre: Lieu.traduit(quete.noms, contexte.langue) ?? "?",
                          sousTitre: L("palette.quete.resume", nombre: quete.etapes.count, quete.niveau, quete.etapes.count),
                          ici: contexte.position.map { QuetesIci.commenceIci(quete, perso: $0, reseau: contexte.reseau) } ?? false,
                          effet: .ouvrirQuete(quete.id))
        }
    }

    /// Les monstres et les objets que citent les quêtes, du catalogue déjà
    /// téléchargé ; Entrée déplie où les trouver.
    static func monstres(_ contexte: ContextePalette) -> [EntreePalette] {
        (contexte.quetes?.monstres ?? [:]).compactMap { id, noms in
            // Un boss de donjon a sa fiche (`boss`), où trouver compris : le donjon.
            guard let numero = Int(id), contexte.donjons?.donjon(boss: numero) == nil,
                  let nom = Lieu.traduit(noms, contexte.langue) else { return nil }
            return EntreePalette(id: "monstre:\(id)", genre: .monstre, titre: nom,
                                 effet: .ouTrouver(.monstre(numero)))
        }
        .alphabetiques()
    }

    static func objets(_ contexte: ContextePalette) -> [EntreePalette] {
        guard let quetes = contexte.quetes else { return [] }
        return quetes.objets.compactMap { id, noms in
            guard let numero = Int(id), let nom = Lieu.traduit(noms, contexte.langue) else { return nil }
            let famille = quetes.famillesObjets[id].flatMap { quetes.familles[String($0)] }.flatMap { Lieu.traduit($0, contexte.langue) }
            return EntreePalette(id: "objet:\(id)", genre: .objet, titre: nom, sousTitre: famille,
                                 effet: .ouTrouver(.objet(numero)))
        }
        .alphabetiques()
    }

    /// Un PNJ par position connue, avec sa zone : celle que le plus de quêtes
    /// citent est dite habituelle, les autres « aussi ici ». `seulement` : ces
    /// PNJ (`PNJ.cle`), à leur position habituelle.
    static func pnjs(_ contexte: ContextePalette, seulement: Set<String>? = nil) -> [EntreePalette] {
        guard let quetes = contexte.quetes else { return [] }
        let inconnu = L("palette.pnj")
        let choisis = seulement.map { cles in quetes.pnjs.filter { cles.contains($0.cle) } } ?? quetes.pnjs
        return choisis.flatMap { pnj in
            pnj.passages.prefix(seulement == nil ? .max : 1).enumerated().map { rang, passage in
                let position = passage.position
                let sousZone = passage.sousZone.flatMap { quetes.sousZones[String($0)] }
                let lieu = sousZone.map {
                    [Lieu.traduit($0.noms, contexte.langue), Lieu.traduit($0.zone, contexte.langue)]
                        .compactMap { $0 }.joined(separator: " · ")
                } ?? inconnu
                let nombre = passage.quetes
                let sousTitre = rang == 0 && pnj.passages.count > 1
                    ? L("palette.pnj.habituel", nombre: nombre, lieu, nombre)
                    : rang == 0 ? L("palette.pnj.cite", nombre: nombre, lieu, nombre) : L("palette.pnj.aussi", nombre: nombre, lieu, nombre)
                let vers = versCase((position.x, position.y), sousZone: passage.sousZone,
                                    dansLesDouze: passage.dansLesDouze(contexte.reseau), contexte)
                return EntreePalette(id: "pnj:\(pnj.id):\(position.x),\(position.y)", genre: .pnj,
                                     titre: Lieu.traduit(pnj.noms, contexte.langue) ?? "?", sousTitre: sousTitre,
                                     etiquette: contexte.etiquettes[pnj.cle],
                                     detail: Coordonnees.texte(position.x, position.y),
                                     favori: contexte.favoris.contains(pnj.cle),
                                     distance: vers.distance,
                                     itineraire: itineraire(vers.trajet, contexte.langue), cle: pnj.cle, carte: passage.carte,
                                     ici: contexte.position.map {
                                         QuetesIci.ici(position, sousZone: passage.sousZone, perso: $0, reseau: contexte.reseau)
                                     } ?? false,
                                     interieur: contexte.interieurs.contient(passage.carte),
                                     effet: vers.effet)
            }
        }
    }

    /// Les dernières copies : au-dessus des zaaps quand rien n'est tapé, et
    /// cherchées comme le reste.
    static func recents(_ contexte: ContextePalette) -> [EntreePalette] {
        contexte.recents.enumerated().map {
            EntreePalette(id: "recent:\($0.offset)", genre: .recent, titre: $0.element,
                          effet: .copier($0.element))
        }
    }

    static let nombreDeRecents = 8

    /// Le texte copié passe en tête ; un doublon remonte au lieu de se répéter.
    static func noterRecent(_ texte: String, dans recents: [String]) -> [String] {
        Array(([texte] + recents.filter { $0 != texte }).prefix(nombreDeRecents))
    }

    // MARK: - Trajets

    private static func trajet(vers cible: (x: Int, y: Int), sousZone: Int?, _ contexte: ContextePalette) -> String {
        let travel = ItineraireZaap.travel(vers: cible)
        return ItineraireZaap.reecrire(travel, sousZone: sousZone, depuis: contexte.position,
                                       gainMinimal: contexte.gainMinimal, zaaps: contexte.zaaps,
                                       zaapDuJeu: contexte.zaapDuJeu, intercalees: contexte.intercalees) ?? travel
    }

    /// Le trajet que `trajet(vers:)` copiera — la même décision (`ItineraireZaap.trajet`).
    static func trajetVers(_ cible: (x: Int, y: Int), sousZone: Int?, _ contexte: ContextePalette) -> ItineraireZaap.Trajet? {
        ItineraireZaap.trajet(vers: cible, sousZone: sousZone, depuis: contexte.position,
                              gainMinimal: contexte.gainMinimal, zaaps: contexte.zaaps, zaapDuJeu: contexte.zaapDuJeu)
    }

    /// « Aller en [x,y] » : la case tapée seule, trajet compris.
    private static func versUneCase(_ cible: (x: Int, y: Int), _ contexte: ContextePalette) -> EntreePalette {
        let vers = versCase(cible, sousZone: nil, dansLesDouze: true, contexte)
        return EntreePalette(id: "case:\(cible.x),\(cible.y)", genre: .lieu,
                             titre: L("palette.allerEn", Coordonnees.texte(cible.x, cible.y)),
                             distance: vers.distance, itineraire: itineraire(vers.trajet, contexte.langue), effet: vers.effet)
    }

    /// Ce qu'une entrée vers ce lieu montre et fait : sa ligne, et l'entrée
    /// d'un donjon dans sa fiche.
    static func versLieu(_ lieu: Lieu, _ contexte: ContextePalette)
        -> (trajet: ItineraireZaap.Trajet?, distance: Int?, effet: EntreePalette.Effet) {
        versCase((lieu.x, lieu.y), sousZone: lieu.idSousZone, dansLesDouze: !contexte.reseau.horsDesDouze(lieu.idSousZone),
                 contexte)
    }

    /// Ce qu'une entrée qui mène à une case montre et fait — un seul chemin
    /// pour les zaaps cherchés par `/travel`, les lieux et les PNJ. Hors du
    /// Monde des Douze, le `/travel` seul, sans distance ni zaap : ses
    /// coordonnées recoupent celles d'Amakna, un zaap d'Amakna y mènerait à tort.
    private static func versCase(_ cible: (x: Int, y: Int), sousZone: Int?, dansLesDouze: Bool,
                                 _ contexte: ContextePalette)
        -> (trajet: ItineraireZaap.Trajet?, distance: Int?, effet: EntreePalette.Effet) {
        guard dansLesDouze else { return (nil, nil, .copier(ItineraireZaap.travel(vers: cible))) }
        return (trajetVers(cible, sousZone: sousZone, contexte),
                ItineraireZaap.aPied(depuis: contexte.position, vers: cible, dansLesDouze: true),
                .trajet(x: cible.x, y: cible.y, sousZone: sousZone))
    }

    static func itineraire(_ trajet: ItineraireZaap.Trajet?, _ langue: Langue) -> String? {
        guard let trajet else { return nil }
        guard let zaap = trajet.zaap else { return L("palette.trajet.aPied", nombre: trajet.cartes, trajet.cartes) }
        if trajet.cartes == 0 { return L("palette.trajet.zaapSeul", zaap.nom(en: langue)) }
        return L("palette.trajet.via", nombre: trajet.cartes, zaap.nom(en: langue), trajet.cartes)
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

    /// Sous ce nombre de résultats exacts, la recherche tolère une faute de
    /// frappe : chaque frappe sur les milliers de fiches n'en paie pas le coût.
    static let seuilTolerance = 8

    /// Une fiche retenue, son score calculé une fois : `premiers` compare souvent.
    private struct Retenue {
        let rang: Int
        let score: ScorePalette
    }

    /// Garde les entrées dont chaque mot tapé trouve un écho, puis les range :
    /// les monstres et objets en dernier (`enDernier`), puis « Auto »
    /// (`ScorePalette`), ou les zaaps devant, les favoris en tête de chaque
    /// famille et le tri explicite, à égalité la meilleure correspondance.
    /// Trop peu d'échos exacts : les échos à une faute près (`approchees`)
    /// viennent après eux. Seules les `limite` premières sont rangées
    /// (`premiers`) : une lettre en retient des milliers.
    private static func classer(_ fiches: [Fiche], _ mots: [String], tri: TriPalette,
                                frequentation: FrequentationPalette) -> [EntreePalette] {
        let habitudes = tri == .auto ? frequentation : FrequentationPalette()
        func retenue(_ rang: Int, _ points: Int) -> Retenue {
            let entree = fiches[rang].entree
            return Retenue(rang: rang, score: ScorePalette(entree, correspondance: mots.isEmpty ? nil : points,
                                                           compte: habitudes.compte(de: entree)))
        }
        var exactes: [Retenue] = []
        exactes.reserveCapacity(fiches.count)
        for (rang, fiche) in fiches.enumerated() {
            var points = 0
            let garde = mots.allSatisfy { mot in
                let echo = fiche.champs.points(mot)
                points += echo
                return echo > 0
            }
            if garde { exactes.append(retenue(rang, points)) }
        }
        let avant = { (a: Retenue, b: Retenue) -> Bool in
            let (fa, fb) = (fiches[a.rang], fiches[b.rang])
            let (ea, eb) = (fa.entree, fb.entree)
            if ea.enDernier != eb.enDernier { return eb.enDernier }
            if tri == .auto { return ScorePalette.avant(a.score, b.score) ?? (a.rang < b.rang) }
            if (ea.genre == .zaap) != (eb.genre == .zaap) { return ea.genre == .zaap }
            if ea.favori != eb.favori { return ea.favori }
            if let ordre = RecherchePalette.comparer(fa, fb, tri) { return ordre }
            let (pa, pb) = (a.score.correspondance ?? 0, b.score.correspondance ?? 0)
            if pa != pb { return pa > pb }
            return a.rang < b.rang
        }
        var rangees = premiers(exactes, limite, avant: avant)
        if exactes.count < seuilTolerance {
            let gardees = Set(exactes.map(\.rang))
            let tolerees = approchees(fiches, mots, sauf: gardees).map { retenue($0.rang, $0.points) }
            rangees += premiers(tolerees, limite - rangees.count, avant: avant)
        }
        return rangees.map { fiches[$0.rang].entree }
    }

    /// Les fiches dont chaque mot tapé trouve un écho, exact ou à une faute
    /// près (`Champs.approche`), au moins un approché ; `sauf` : celles déjà
    /// retenues par l'exact.
    private static func approchees(_ fiches: [Fiche], _ mots: [String], sauf gardees: Set<Int>)
        -> [(rang: Int, points: Int)] {
        let motifs = mots.map { mot in
            (mot: mot, fautes: Champs.tolerance(mot), forme: Ressemblance.Forme(mot))
        }
        guard motifs.contains(where: { $0.fautes != nil }) else { return [] }
        var retenues: [(rang: Int, points: Int)] = []
        for (rang, fiche) in fiches.enumerated() where !gardees.contains(rang) {
            var points = 0, approche = false
            let garde = motifs.allSatisfy { motif in
                let echo = fiche.champs.points(motif.mot)
                if echo > 0 { points += echo; return true }
                guard let fautes = motif.fautes, fiche.champs.approche(motif.forme, tolerance: fautes) else { return false }
                points += Champs.pointsApproches
                approche = true
                return true
            }
            if garde, approche { retenues.append((rang, points)) }
        }
        return retenues
    }

    /// Les `limite` premiers d'`elements` selon `avant` : ce que donnerait
    /// `sorted(by: avant).prefix(limite)` pour un ordre total, sans trier ce
    /// qui ne sera pas montré. Une insertion dichotomique dans les retenus ;
    /// un élément qui ne bat pas le dernier ne coûte qu'une comparaison.
    static func premiers<Element>(_ elements: [Element], _ limite: Int,
                                  avant: (Element, Element) -> Bool) -> [Element] {
        guard limite > 0 else { return [] }
        guard elements.count > limite else { return elements.sorted(by: avant) }
        var retenus: [Element] = []
        retenus.reserveCapacity(limite + 1)
        for element in elements {
            if retenus.count == limite, !avant(element, retenus[limite - 1]) { continue }
            // Après ceux qu'il ne précède pas : à égalité, l'ordre d'arrivée.
            var bas = 0, haut = retenus.count
            while bas < haut {
                let milieu = (bas + haut) / 2
                if avant(element, retenus[milieu]) { haut = milieu } else { bas = milieu + 1 }
            }
            retenus.insert(element, at: bas)
            if retenus.count > limite { retenus.removeLast() }
        }
        return retenus
    }

    /// Un tri explicite ; `nil` à égalité, et pour « Auto », que `ScorePalette` range.
    private static func comparer(_ a: Fiche, _ b: Fiche, _ tri: TriPalette) -> Bool? {
        switch tri {
        case .auto:
            return nil
        case .proximite:
            return comparerDistances(a.entree, b.entree)
        case .alphabetique:
            let (ca, cb) = (a.champs.cleAlphabetique, b.champs.cleAlphabetique)
            return ca == cb ? comparerDistances(a.entree, b.entree) : ca < cb
        case .type:
            let (ta, tb) = (rangDeType(a.entree), rangDeType(b.entree))
            return ta != tb ? ta < tb : comparerDistances(a.entree, b.entree)
        }
    }

    private static func comparerDistances(_ a: EntreePalette, _ b: EntreePalette) -> Bool? {
        ScorePalette.plusProche(a.distance, b.distance)
    }

    /// Persos, puis lieux par catégorie (temples, hôtels de vente, ateliers…),
    /// puis gestes et copies.
    private static func rangDeType(_ entree: EntreePalette) -> Int {
        switch entree.genre {
        case .zaap: return 0
        case .perso: return 1
        case .quete: return 120
        case .pnj: return 130
        case .monstre: return 140
        case .objet: return 150
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
        /// Le titre rangé comme `localizedStandardCompare` le rangerait — sans
        /// casse ni accents, les nombres par leur valeur —, comparé par `<` :
        /// le tri alphabétique ne compare plus de textes localisés à chaque frappe.
        let cleAlphabetique: String
        /// Les mots du titre et du lieu bout à bout, séparés d'un caractère
        /// qu'aucun mot tapé ne contient : un seul passage pour un mot cherché
        /// au milieu d'un autre.
        private let interieur: String
        /// Les mots du titre et de l'étiquette, prêts pour la borne basse de
        /// `Ressemblance` : une fiche trop loin d'un mot approché s'écarte sans
        /// calculer de distance.
        private let forme: Ressemblance.Forme

        /// Tout ce dont les champs dépendent : une entrée qui garde sa clé garde ses champs.
        static func cle(_ entree: EntreePalette) -> String {
            [entree.id, entree.titre, entree.etiquette ?? "", entree.sousTitre ?? "",
             entree.categorie.map(String.init) ?? ""].joined(separator: "\u{1F}")
        }

        init(_ entree: EntreePalette) {
            self.init(titre: entree.titre, etiquette: entree.etiquette, lieu: entree.sousTitre,
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
            cleAlphabetique = Self.cleAlphabetique(nom)
            interieur = (self.titre + self.lieu).joined(separator: "\u{1F}")
            forme = Ressemblance.Forme((self.titre + self.etiquette).joined(separator: " "))
        }

        /// Chaque suite de chiffres calée à droite sur `chiffres` : « 9 » avant « 10 ».
        static func cleAlphabetique(_ normalise: String) -> String {
            var cle = "", nombre = ""
            func verser() {
                guard !nombre.isEmpty else { return }
                cle += String(repeating: "0", count: max(chiffres - nombre.count, 0)) + nombre
                nombre = ""
            }
            for caractere in normalise {
                if caractere.isASCII, caractere.isNumber { nombre.append(caractere) } else { verser(); cle.append(caractere) }
            }
            verser()
            return cle
        }

        private static let chiffres = 6

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
            if mot.count >= 3, interieur.contains(mot) { return 20 }
            return 0
        }

        /// Moins que tout écho exact.
        static let pointsApproches = 10

        /// Un mot plus court ressemble à trop d'autres pour tolérer une faute.
        static let lettresTolerees = 4

        /// Les fautes qu'un mot tapé tolère : une, deux à partir de huit lettres ;
        /// `nil` sous `lettresTolerees`.
        static func tolerance(_ mot: String) -> Int? {
            let lettres = mot.count
            guard lettres >= lettresTolerees else { return nil }
            return lettres >= 8 ? 2 : 1
        }

        /// Un mot du titre ou de l'étiquette commence à `tolerance` fautes près
        /// par le mot tapé : « funoro » répond à « Founoroshi ».
        func approche(_ motif: Ressemblance.Forme, tolerance: Int) -> Bool {
            guard !motif.tropLoin(de: forme, tolerance: tolerance) else { return false }
            func repond(_ mot: String) -> Bool {
                mot.count >= Self.lettresTolerees
                    && Ressemblance.distanceAuDebut(motif, Ressemblance.Forme(mot), auPlus: tolerance) != nil
            }
            return titre.contains(where: repond) || etiquette.contains(where: repond)
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

private extension Array where Element == EntreePalette {
    /// Par titre, comme le tri alphabétique : une famille listée sans rien
    /// taper se parcourt dans l'ordre — un dictionnaire n'en a pas.
    func alphabetiques() -> [EntreePalette] {
        map { (RecherchePalette.Champs.cleAlphabetique(RecherchePalette.normaliser($0.titre)), $0) }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
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
    /// La grille, quand rien n'est tapé.
    private(set) lazy var accueil = RecherchePalette.accueil(contexte, zaaps: zaaps.map(\.entree),
                                                            lieux: lieux.map(\.entree))
    private(set) lazy var monstres = fiches(RecherchePalette.boss(contexte) + RecherchePalette.monstres(contexte))
    private(set) lazy var objets = fiches(RecherchePalette.objets(contexte))
    /// Sans préfixe : zaaps, lieux, quêtes, PNJ, gestes, dernières copies,
    /// monstres et objets.
    private(set) lazy var tout = zaaps + lieux + quetes + pnjs + fiches(RecherchePalette.divers(contexte)) + monstres + objets

    /// Les champs de toutes les fiches, à garder pour l'index suivant.
    static func champs(de contexte: ContextePalette, connus: [String: RecherchePalette.Champs] = [:])
        -> [String: RecherchePalette.Champs] {
        let index = IndexPalette(contexte, connus: connus)
        return Dictionary((index.tout + index.zaapsCommeLieux).map { (RecherchePalette.Champs.cle($0.entree), $0.champs) },
                          uniquingKeysWith: { a, _ in a })
    }
}
