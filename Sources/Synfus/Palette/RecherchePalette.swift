import Foundation

/// Les gestes de Synfus que la palette sait faire, tapés en toutes lettres.
enum ActionPalette: Equatable, Sendable {
    case rangerFenetres, lancerSession, equipeSuivante, inviterEquipe, quetes, chasse, reglages

    static let toutes: [ActionPalette] = [.rangerFenetres, .lancerSession, .equipeSuivante, .inviterEquipe, .quetes, .chasse, .reglages]

    var titre: String {
        switch self {
        case .rangerFenetres: return L("palette.action.ranger")
        case .lancerSession: return L("palette.action.session")
        case .equipeSuivante: return L("palette.action.equipe")
        case .inviterEquipe: return L("palette.action.inviter")
        case .quetes: return L("palette.action.quetes")
        case .chasse: return L("palette.action.chasse")
        case .reglages: return L("palette.action.reglages")
        }
    }
}

/// Les capsules de la rangée, que Tab fait défiler, dans l'ordre des cas : la même rangée, au même
/// nom, avec ou sans texte tapé — une rangée qui bougerait à la frappe déroute. Chacune est une vue
/// au repos et la portée de la recherche dès qu'on tape. Les zaaps sont des lieux ; un boss est
/// dans les donjons, pas parmi les créatures.
enum FiltrePalette: CaseIterable, Sendable {
    case tout, zaaps, lieux, donjons, pnj, quetes, creatures, objets, almanax

    var titre: String {
        switch self {
        case .tout: return L("palette.filtre.accueil")
        case .zaaps: return L("palette.filtre.zaaps")
        case .almanax: return L("palette.filtre.almanax")
        case .donjons: return L("palette.filtre.donjons")
        case .pnj: return L("palette.filtre.pnj")
        case .lieux: return L("palette.filtre.lieux")
        case .quetes: return L("palette.filtre.quetes")
        case .creatures: return L("palette.filtre.creatures")
        case .objets: return L("palette.filtre.objets")
        }
    }

    /// Rien de tapé, ces vues-là se montrent en cartes.
    var enCartes: Bool {
        switch self {
        case .tout, .zaaps, .donjons, .pnj, .quetes: return true
        case .almanax, .lieux, .creatures, .objets: return false
        }
    }

    /// Les zaaps, les lieux et les donjons viennent de la carte : tant qu'elle manque, une liste vide le dit.
    var dependDeLaCarte: Bool { self == .tout || self == .zaaps || self == .lieux || self == .donjons }

    /// Au repos, les boss n'ont pas de carte : seuls les donjons se montrent ; en recherche, leurs boss
    /// ouvrent la même fiche.
    func garde(_ entree: EntreePalette, enRecherche: Bool) -> Bool {
        switch self {
        case .tout: return true
        case .zaaps: return entree.genre == .zaap
        case .almanax: return false
        case .donjons: return entree.estDonjon && (enRecherche || !entree.estBoss)
        case .pnj: return entree.genre == .pnj
        case .lieux: return entree.genre == .zaap || entree.genre == .lieu
        case .quetes: return entree.genre == .quete
        case .creatures: return entree.genre == .monstre && !entree.estBoss
        case .objets: return entree.genre == .objet
        }
    }

    /// La capsule où l'entrée se range : un boss avec son donjon, un zaap à part des lieux ; `nil` pour
    /// ce qui n'en a pas (perso, geste, copie).
    static func famille(de entree: EntreePalette) -> FiltrePalette? {
        if entree.estDonjon { return .donjons }
        switch entree.genre {
        case .zaap: return .zaaps
        case .lieu: return .lieux
        case .pnj: return .pnj
        case .quete: return .quetes
        case .monstre: return .creatures
        case .objet: return .objets
        case .commande, .variable, .perso, .action, .recent: return nil
        }
    }

    /// « 5 objets de plus » : la ligne de l'Accueil qui mène au reste de la famille.
    func suite(_ reste: Int) -> String {
        switch self {
        case .zaaps: return L("palette.suite.zaaps", nombre: reste, reste)
        case .lieux: return L("palette.suite.lieux", nombre: reste, reste)
        case .donjons: return L("palette.suite.donjons", nombre: reste, reste)
        case .pnj: return L("palette.suite.pnj", nombre: reste, reste)
        case .quetes: return L("palette.suite.quetes", nombre: reste, reste)
        case .creatures: return L("palette.suite.creatures", nombre: reste, reste)
        case .objets: return L("palette.suite.objets", nombre: reste, reste)
        case .tout, .almanax: return L("palette.vide.ailleurs", nombre: reste, reste, titre)
        }
    }

    /// Le tri ne range rien sur l'Accueil ni sur l'almanax, au repos : ni les montrer, ni ⌘T.
    func triAgit(enRecherche: Bool) -> Bool {
        enRecherche || (self != .tout && self != .almanax)
    }

    /// Les tris qui ont un sens ici : au repos, « Type » ne départage rien parmi une seule famille, et
    /// une quête n'a pas de position à comparer.
    func tris(enRecherche: Bool) -> [TriPalette] {
        guard !enRecherche else { return TriPalette.allCases }
        switch self {
        case .zaaps, .donjons, .pnj: return [.auto, .proximite, .alphabetique]
        case .quetes: return [.auto, .alphabetique]
        default: return TriPalette.allCases
        }
    }

    /// Le suivant (Tab) ou le précédent (⇧Tab) de la rangée, en boucle.
    func suivant(_ pas: Int) -> FiltrePalette {
        let rangee = Self.allCases
        let rang = rangee.firstIndex(of: self) ?? 0
        return rangee[(rang + pas + rangee.count) % rangee.count]
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

    /// Le suivant de `choix` (⌘T), en boucle ; le premier si `self` n'y est pas.
    func suivant(dans choix: [TriPalette]) -> TriPalette {
        guard let rang = choix.firstIndex(of: self) else { return choix[0] }
        return choix[(rang + 1) % choix.count]
    }
}

/// Une ligne de la palette, et ce qu'Entrée en fait.
struct EntreePalette: Equatable, Identifiable, Sendable {
    enum Genre: Equatable, Sendable {
        case zaap, lieu, commande, variable, perso, action, recent, quete, pnj, monstre, objet

        /// Monstres et objets se cherchent par milliers : sous « Accueil », après
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
        /// Déplie sous la ligne les cartes des positions du PNJ (`PositionsPNJVue`) : il en a plusieurs.
        case positions(Int)
        /// Copie le trajet vers la case, zaap compris s'il vaut le coup —
        /// calculé seulement pour l'entrée choisie (`texte(de:)`).
        case trajet(x: Int, y: Int, sousZone: Int?)
        case action(ActionPalette)
        /// Met ce perso devant (`DofusClient.slotKey`), comme un clic sur sa pastille.
        case basculer(String)
        /// Passe sur la capsule de la famille, la recherche gardée : ses `reste` lignes que l'Accueil tait.
        case famille(FiltrePalette, reste: Int)

        /// Entrée déplie quelque chose sous la ligne plutôt que de copier.
        var sePlie: Bool {
            switch self {
            case .ouTrouver, .donjon, .positions: return true
            case .copier, .completer, .ouvrirQuete, .trajet, .action, .basculer, .famille: return false
            }
        }
    }

    let id: String
    let genre: Genre
    let titre: String
    var sousTitre: String?
    /// Les lieux des autres positions d'un PNJ : cherchés, jamais montrés.
    var autresLieux: String?
    /// Nom, lieu et trajet en entier : l'infobulle d'une entrée coupée.
    var complet: String { [titre, sousTitre, itineraire].compactMap(\.self).joined(separator: " · ") }
    var etiquette: String?
    /// À droite : coordonnées, commande copiée.
    var detail: String?
    /// À droite aussi, mais un texte et non des coordonnées : « 3 positions ».
    var compte: String?
    var favori = false
    /// Les cartes depuis le perso devant, à pied, quand elles veulent dire
    /// quelque chose : départage deux résultats aussi bons. Pas celles du
    /// trajet : tout ce qui jouxte un zaap y paraîtrait à une carte.
    var distance: Int?
    /// Le trajet copié, dit en clair : « via Coin des Bouftous · 6 cartes »,
    /// « 6 cartes ». Jamais cherché.
    var itineraire: String?
    /// La catégorie DofusDB d'un lieu (`CategorieLieu`) : le tri par type.
    var categorie: Int?
    /// Ce qu'une étiquette ou un favori désigne (`Zaap.cle`, `Lieu.cle`) ;
    /// `nil` pour ce qui ne s'étiquette pas.
    var cle: String?
    /// ⌘E et ⌘D ont prise sur elle : le pied, le menu et les gestes en décident ici seulement.
    var etiquetable: Bool { cle != nil }
    /// La carte du jeu de l'entrée, dont la liste montre la vue.
    var carte: Int?
    /// Le pictogramme d'un lieu (`Lieu.gfx`), à la place du symbole.
    var pictogramme: Int?
    /// Une quête du suivi lu ou épinglée : elle passe devant les autres (`ScorePalette`).
    var suivie = false
    /// Sa carte n'est pas en extérieur : le trajet mène devant le bâtiment.
    var interieur = false
    /// Le PNJ dont l'entrée est la ligne : ses positions se déplient en cartes.
    var pnj: Int?
    /// Le symbole propre à l'entrée (une commande, une variable) ; `nil` : celui de son genre.
    var symbole: String?
    /// La classe d'un perso à basculer : son emblème tient la place du pictogramme.
    var classe: String?
    /// Le raccourci du geste de la ligne, dit au bout de la ligne.
    var touche: String?
    /// Sur la case du perso devant : un repère devant ses coordonnées.
    var ici = false
    let effet: Effet

    /// Un donjon de la carte, ou l'un de ses boss : la fiche qu'ils ouvrent est la même.
    var estDonjon: Bool {
        if categorie == CategorieLieu.donjon.rawValue { return true }
        if case .donjon = effet { return true }
        return false
    }

    /// La fiche d'un boss de donjon (`RecherchePalette.boss`), d'où s'ouvre l'aide à son combat.
    var estBoss: Bool {
        if case .donjon = effet { return genre == .monstre }
        return false
    }

    /// Après le reste : les monstres et objets par milliers, sauf les boss, qu'on cherche exprès.
    var enDernier: Bool { genre.enDernier && !estBoss }
}

/// Un perso de l'équipe active, tel que la palette le propose : le geste « passer sur lui ».
struct PersoPalette: Equatable, Sendable {
    let slotKey: String
    let nom: String
    let classe: String?
    let position: PositionCarte?
    /// Son raccourci d'accès direct, ou son numéro dans la barre.
    let touche: String
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
    /// Les persos de l'équipe active, dans l'ordre de la barre.
    var persos: [PersoPalette] = []
    /// `nil` tant qu'elles ne sont pas téléchargées.
    var quetes: Quetes?
    /// `nil` tant qu'ils ne sont pas téléchargés.
    var donjons: Donjons?
    /// Les quêtes du suivi lu et les épinglées : en tête de la vue « Quêtes ».
    var quetesSuivies: Set<Int> = []
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
            return classer(index.tout.filter { filtre.garde($0.entree, enRecherche: false) }, [])
        }
        if texte.hasPrefix("%") { return variables(texte, index.contexte) }
        if let cible = ItineraireZaap.caseTapee(texte) {
            return [versUneCase(cible, index.contexte)].filter { filtre.garde($0, enRecherche: true) }
        }
        guard texte.hasPrefix("/") else {
            let fiches = index.tout.filter { filtre.garde($0.entree, enRecherche: true) }
            guard filtre == .tout else { return ListePalette.fusionnerDonjons(classer(fiches, mots(texte))) }
            // L'Accueil : le meilleur de chaque famille, et une ligne vers le reste.
            let (entrees, restes) = RecherchePalette.classer(fiches, mots(texte), tri: tri, frequentation: index.contexte.frequentation,
                                            parFamille: ListePalette.parFamille)
            return ListePalette.avecLesSuites(ListePalette.fusionnerDonjons(entrees), restes: restes)
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

    /// Les capsules où `requete` ne trouverait rien : exactement celles dont `entrees(_:filtre:)` serait
    /// vide, l'Accueil jamais ; aucune sans texte. Une seule passe exacte sur toutes les fiches ; seules
    /// les familles qu'elle n'a pas trouvées refont leur recherche, fautes de frappe comprises.
    static func filtresVides(_ requete: String, _ index: IndexPalette) -> Set<FiltrePalette> {
        let texte = requete.trimmingCharacters(in: .whitespaces)
        guard !texte.isEmpty else { return [] }
        var restants = Set(FiltrePalette.allCases.filter { $0 != .tout })
        // Préfixes et coordonnées : des modes à part, peu coûteux, qui ignorent ou non le filtre.
        let simple = !texte.hasPrefix("/") && !texte.hasPrefix("%") && ItineraireZaap.caseTapee(texte) == nil
        if simple {
            let mots = mots(texte)
            for fiche in index.tout where fiche.champs.garde(mots) {
                restants = restants.filter { !$0.garde(fiche.entree, enRecherche: true) }
                if restants.isEmpty { break }
            }
        }
        return restants.filter { entrees(texte, index, filtre: $0).isEmpty }
    }

    /// Le texte qu'Entrée copiera — `nil` pour ce qui ne copie rien.
    static func texte(de effet: EntreePalette.Effet, _ contexte: ContextePalette) -> String? {
        switch effet {
        case .copier(let texte): return texte
        case .trajet(let x, let y, let sousZone): return trajet(vers: (x, y), sousZone: sousZone, contexte)
        case .completer, .action, .ouvrirQuete, .ouTrouver, .donjon, .positions, .basculer, .famille: return nil
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
                carte: zaap.idCarte, ici: estIci((zaap.x, zaap.y), sousZone: contexte.reseau.sousZone(du: zaap), contexte),
                effet: .copier(ItineraireZaap.zaap(zaap)))
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
                distance: vers.distance, itineraire: vers.itineraire(contexte.langue), cle: zaap.cle,
                carte: zaap.idCarte, ici: vers.ici, effet: vers.effet)
        }
    }

    /// Sans rien taper : les favoris, les plus choisis puis les plus proches
    /// (`ScorePalette`), puis les autres zaaps.
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
            let lieuDit = avecNiveau([lieu.sousZone(en: contexte.langue), lieu.zone(en: contexte.langue)]
                .compactMap { $0 }.joined(separator: " · "), donjon)
            return EntreePalette(
                id: lieu.cle, genre: .lieu, titre: lieu.nom(en: contexte.langue), sousTitre: lieuDit,
                etiquette: contexte.etiquettes[lieu.cle], detail: Coordonnees.texte(lieu.x, lieu.y),
                favori: contexte.favoris.contains(lieu.cle), distance: vers.distance,
                itineraire: vers.itineraire(contexte.langue), categorie: lieu.categorie, cle: lieu.cle,
                carte: lieu.idCarte, pictogramme: lieu.gfx,
                interieur: contexte.interieurs.contient(lieu.idCarte), ici: vers.ici,
                effet: donjon.map { .donjon($0.id) } ?? vers.effet)
        }
    }

    /// Le sous-titre d'un donjon ou de l'un de ses boss, suivi du niveau conseillé du donjon : la fiche ne
    /// le redit pas, et il se distingue ainsi de celui du boss.
    static func avecNiveau(_ dit: String, _ donjon: Donjon?) -> String {
        guard let niveau = donjon?.niveau else { return dit }
        return [dit, L("donjon.niveau", niveau)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Les boss de donjon : leur nom déplie la fiche de leur donjon, la même
    /// que le donjon cherché par son nom.
    static func boss(_ contexte: ContextePalette) -> [EntreePalette] {
        guard let donjons = contexte.donjons else { return [] }
        return donjons.nomsBoss.compactMap { id, noms in
            guard let nom = Lieu.traduit(noms, contexte.langue), let donjon = donjons.donjon(boss: id) else { return nil }
            let lieu = Lieu.traduit(donjon.noms, contexte.langue) ?? "?"
            return EntreePalette(id: "boss:\(id)", genre: .monstre, titre: nom, sousTitre: avecNiveau(L("palette.boss", lieu), donjon),
                                 effet: .donjon(donjon.id))
        }
        .alphabetiques()
    }

    /// Un perso par ligne : ↵ le met devant, sa touche au bout.
    static func persos(_ contexte: ContextePalette) -> [EntreePalette] {
        contexte.persos.map { perso in
            let lieu = perso.position.map { Coordonnees.texte($0.x, $0.y) }
            let dit = [perso.classe, lieu].compactMap(\.self)
            return EntreePalette(id: "perso:" + perso.slotKey, genre: .perso, titre: perso.nom,
                                 sousTitre: dit.isEmpty ? nil : dit.joined(separator: " · "),
                                 classe: perso.classe, touche: perso.touche, effet: .basculer(perso.slotKey))
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
                                     sousTitre: commande.description, detail: commande.argument,
                                     symbole: commande.symbole, effet: effet)
            }
    }

    private static func variables(_ texte: String, _ contexte: ContextePalette) -> [EntreePalette] {
        let tape = normaliser(texte).trimmingCharacters(in: CharacterSet(charactersIn: "%"))
        return VariableJeu.allCases
            .filter { tape.isEmpty || $0.rawValue.hasPrefix(tape) }
            .map { EntreePalette(id: "var:" + $0.rawValue, genre: .variable, titre: $0.texte,
                                 sousTitre: $0.description,
                                 detail: $0.valeur(perso: contexte.perso, position: contexte.position),
                                 symbole: $0.symbole, effet: .copier($0.texte)) }
    }

    /// Les gestes et les dernières copies : ce que `tout` ajoute aux zaaps,
    /// lieux, quêtes et PNJ.
    static func divers(_ contexte: ContextePalette) -> [EntreePalette] {
        let actions = ActionPalette.toutes.map {
            EntreePalette(id: "action:\($0)", genre: .action, titre: $0.titre, effet: .action($0))
        }
        return actions + recents(contexte)
    }

    // MARK: - Quêtes et PNJ

    static func quetes(_ contexte: ContextePalette) -> [EntreePalette] {
        (contexte.quetes?.quetes ?? []).map { quete in
            EntreePalette(id: "quete:\(quete.id)", genre: .quete, titre: Lieu.traduit(quete.noms, contexte.langue) ?? "?",
                          sousTitre: L("palette.quete.resume", nombre: quete.etapes.count, quete.niveau, quete.etapes.count),
                          suivie: contexte.quetesSuivies.contains(quete.id), effet: .ouvrirQuete(quete.id))
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

    /// Un PNJ par ligne, quel que soit le nombre de cases où les quêtes le placent, ses homonymes de la
    /// même sous-zone réunis (`HomonymesPNJ`). Sa ligne dit sa position habituelle (celle que le plus de
    /// quêtes citent), stable quand le perso bouge ; le rang suit la plus proche de ses positions.
    /// Plusieurs positions : ↵ les déplie en cartes (`positions(de:)`). `seulement` : ces PNJ (`PNJ.cle`).
    static func pnjs(_ contexte: ContextePalette, seulement: Set<String>? = nil) -> [EntreePalette] {
        guard let quetes = contexte.quetes else { return [] }
        let fusionnes = HomonymesPNJ.fusionner(quetes.pnjs, langue: contexte.langue)
        let choisis = seulement.map { cles in fusionnes.filter { !cles.isDisjoint(with: $0.cles) } } ?? fusionnes
        return choisis.compactMap { fusionne in
            let pnj = fusionne.pnj
            guard let habituel = pnj.passages.first else { return nil }
            let titre = Lieu.traduit(pnj.noms, contexte.langue) ?? "?"
            let lieu = lieuDit(habituel, quetes, contexte) ?? L("palette.pnj")
            let trajets = pnj.passages.map { versCase($0, contexte) }
            // La clé d'un homonyme déjà favori ou étiqueté : ⌘D et ⌘E le retrouvent.
            let cle = fusionne.cles.first { contexte.favoris.contains($0) || contexte.etiquettes[$0] != nil } ?? pnj.cle
            let etiquette = contexte.etiquettes[cle]
            let favori = contexte.favoris.contains(cle)
            if pnj.passages.count > 1 {
                return EntreePalette(id: pnj.cle, genre: .pnj, titre: titre, sousTitre: lieu,
                                     autresLieux: pnj.passages.dropFirst().compactMap { lieuDit($0, quetes, contexte) }
                                         .joined(separator: " "),
                                     etiquette: etiquette,
                                     compte: L("palette.pnj.positions", nombre: pnj.passages.count, pnj.passages.count),
                                     favori: favori, distance: trajets.compactMap(\.distance).min(),
                                     cle: cle, pnj: pnj.id, effet: .positions(pnj.id))
            }
            let vers = trajets[0]
            let nombre = habituel.quetes.count
            return EntreePalette(id: pnj.cle, genre: .pnj, titre: titre,
                                 sousTitre: L("palette.pnj.cite", nombre: nombre, lieu, nombre),
                                 etiquette: etiquette,
                                 detail: Coordonnees.texte(habituel.position.x, habituel.position.y),
                                 favori: favori, distance: vers.distance,
                                 itineraire: vers.itineraire(contexte.langue), cle: cle, carte: habituel.carte,
                                 interieur: contexte.interieurs.contient(habituel.carte), pnj: pnj.id, ici: vers.ici,
                                 effet: vers.effet)
        }
    }

    /// « Sous-zone · zone » d'un passage de PNJ ; `nil` quand sa sous-zone est inconnue.
    static func lieuDit(_ passage: PNJ.Passage, _ quetes: Quetes, _ contexte: ContextePalette) -> String? {
        passage.sousZone.flatMap { quetes.sousZones[String($0)] }.map {
            [Lieu.traduit($0.noms, contexte.langue), Lieu.traduit($0.zone, contexte.langue)]
                .compactMap { $0 }.joined(separator: " · ")
        }
    }

    /// Ce qu'une entrée qui mène à ce passage de PNJ montre et fait.
    static func versCase(_ passage: PNJ.Passage, _ contexte: ContextePalette)
        -> VersCase {
        versCase((passage.position.x, passage.position.y), sousZone: passage.sousZone,
                 dansLesDouze: passage.dansLesDouze(contexte.reseau), contexte)
    }

    /// Les dernières copies : cherchées comme le reste, jamais montrées au repos.
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
                             distance: vers.distance, itineraire: vers.itineraire(contexte.langue), ici: vers.ici,
                             effet: vers.effet)
    }

    /// Ce qu'une entrée vers ce lieu montre et fait : sa ligne, et l'entrée
    /// d'un donjon dans sa fiche.
    static func versLieu(_ lieu: Lieu, _ contexte: ContextePalette)
        -> VersCase {
        versCase((lieu.x, lieu.y), sousZone: lieu.idSousZone, dansLesDouze: !contexte.reseau.horsDesDouze(lieu.idSousZone),
                 contexte)
    }

    /// Ce qu'une entrée qui mène à une case montre et fait — un seul chemin
    /// pour les zaaps cherchés par `/travel`, les lieux et les PNJ. Hors du
    /// Monde des Douze, le `/travel` seul, sans distance ni zaap : ses
    /// coordonnées recoupent celles d'Amakna, un zaap d'Amakna y mènerait à tort.
    private static func versCase(_ cible: (x: Int, y: Int), sousZone: Int?, dansLesDouze: Bool,
                                 _ contexte: ContextePalette)
        -> VersCase {
        let ici = estIci(cible, sousZone: sousZone, contexte)
        guard dansLesDouze else { return VersCase(trajet: nil, distance: nil, effet: .copier(ItineraireZaap.travel(vers: cible)), ici: ici) }
        return VersCase(trajet: trajetVers(cible, sousZone: sousZone, contexte),
                        distance: ItineraireZaap.aPied(depuis: contexte.position, vers: cible, dansLesDouze: true),
                        effet: .trajet(x: cible.x, y: cible.y, sousZone: sousZone), ici: ici)
    }

    /// La case est celle du perso devant, dans le même monde (`QuetesIci.ici`).
    static func estIci(_ cible: (x: Int, y: Int), sousZone: Int?, _ contexte: ContextePalette) -> Bool {
        guard let perso = contexte.position else { return false }
        return QuetesIci.ici(PNJ.Position(x: cible.x, y: cible.y), sousZone: sousZone, perso: perso, reseau: contexte.reseau)
    }

    /// Ce qu'une entrée qui mène à une case montre et fait.
    struct VersCase {
        let trajet: ItineraireZaap.Trajet?
        let distance: Int?
        let effet: EntreePalette.Effet
        /// La case du perso : le repère de la ligne le dit (`EntreePalette.ici`), le trajet se tait.
        let ici: Bool

        func itineraire(_ langue: Langue) -> String? { ici ? nil : RecherchePalette.itineraire(trajet, langue) }
    }

    static func itineraire(_ trajet: ItineraireZaap.Trajet?, _ langue: Langue) -> String? {
        guard let trajet else { return nil }
        guard let zaap = trajet.zaap else {
            return trajet.cartes == 0 ? L("palette.trajet.ici") : L("palette.trajet.cartes", nombre: trajet.cartes, trajet.cartes)
        }
        if trajet.cartes == 0 { return L("palette.trajet.zaapSeul", zaap.nom(en: langue)) }
        return L("palette.trajet.via", nombre: trajet.cartes, trajet.cartes, zaap.nom(en: langue))
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
        /// Aucun mot tapé ne répond au nom : seulement au lieu (`Champs.nomRepond`).
        let parLieu: Bool
    }

    /// Les entrées retenues par une recherche, et l'ordre qui les range.
    private struct Retenues {
        let exactes: [Retenue]
        /// Les échos à une faute près, quand les exacts sont trop peu : toujours après eux.
        let tolerees: [Retenue]
        let avant: (Retenue, Retenue) -> Bool
    }

    /// Garde les entrées dont chaque mot tapé trouve un écho, puis les range :
    /// celles trouvées par leur seul lieu après toutes celles dont le nom répond
    /// (`parLieu`), les monstres et objets en dernier (`enDernier`), puis « Auto »
    /// (`ScorePalette`), ou les zaaps devant, les favoris en tête de chaque
    /// famille et le tri explicite, à égalité la meilleure correspondance.
    /// Trop peu d'échos exacts : les échos à une faute près (`approchees`)
    /// viennent après eux. Seules les `limite` premières sont rangées
    /// (`premiers`) : une lettre en retient des milliers.
    private static func classer(_ fiches: [Fiche], _ mots: [String], tri: TriPalette,
                                frequentation: FrequentationPalette) -> [EntreePalette] {
        let retenues = retenir(fiches, mots, tri: tri, frequentation: frequentation)
        var rangees = premiers(retenues.exactes, limite, avant: retenues.avant)
        rangees += premiers(retenues.tolerees, limite - rangees.count, avant: retenues.avant)
        return rangees.map { fiches[$0.rang].entree }
    }

    /// Comme `classer`, au plus `parFamille` entrées de chaque famille (`FiltrePalette.famille`) — un
    /// donjon et ses boss n'y comptent qu'une fois, `ListePalette.fusionnerDonjons` les réunit ensuite —
    /// et ce qui reste de chacune, compté sur toutes ses correspondances.
    private static func classer(_ fiches: [Fiche], _ mots: [String], tri: TriPalette, frequentation: FrequentationPalette,
                                parFamille: Int) -> (entrees: [EntreePalette], restes: [FiltrePalette: Int]) {
        let retenues = retenir(fiches, mots, tri: tri, frequentation: frequentation)
        let avant = retenues.avant
        func entree(_ retenue: Retenue) -> EntreePalette { fiches[retenue.rang].entree }
        // Un donjon et ses boss : une seule clé, la ligne qu'ils deviendront.
        func cle(_ retenue: Retenue) -> String {
            if case .donjon(let id) = entree(retenue).effet { return "donjon:\(id)" }
            return entree(retenue).id
        }
        var rangees: [Retenue] = []
        var montrees: [FiltrePalette: Set<String>] = [:]
        var restes: [FiltrePalette: Int] = [:]
        for lot in [retenues.exactes, retenues.tolerees] {
            var choisies: [Retenue] = []
            for (famille, groupe) in Dictionary(grouping: lot, by: { FiltrePalette.famille(de: entree($0)) }) {
                guard let famille else {
                    choisies += premiers(groupe, limite, avant: avant)
                    continue
                }
                let place = parFamille - montrees[famille, default: []].count
                // Les donjons sont peu nombreux : triés en entier, pour compter leurs clés.
                let tries = famille == .donjons ? groupe.sorted(by: avant) : premiers(groupe, max(place, 0), avant: avant)
                var cles: [String] = []
                for retenue in tries where !cles.contains(cle(retenue)) { cles.append(cle(retenue)) }
                let gardees = Set(cles.prefix(max(place, 0)))
                choisies += tries.filter { gardees.contains(cle($0)) }
                montrees[famille, default: []].formUnion(gardees)
                let total = famille == .donjons ? cles.count : groupe.count
                restes[famille, default: 0] += total - gardees.count
            }
            rangees += choisies.sorted(by: avant)
        }
        return (rangees.map(entree), restes.filter { $0.value > 0 })
    }

    private static func retenir(_ fiches: [Fiche], _ mots: [String], tri: TriPalette,
                                frequentation: FrequentationPalette) -> Retenues {
        let habitudes = tri == .auto ? frequentation : FrequentationPalette()
        func retenue(_ rang: Int, _ points: Int, parLieu: Bool = false) -> Retenue {
            let entree = fiches[rang].entree
            return Retenue(rang: rang, score: ScorePalette(entree, correspondance: mots.isEmpty ? nil : points,
                                                           compte: habitudes.compte(de: entree)), parLieu: parLieu)
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
            if garde { exactes.append(retenue(rang, points, parLieu: !mots.isEmpty && !fiche.champs.nomRepond(mots))) }
        }
        let avant = { (a: Retenue, b: Retenue) -> Bool in
            let (fa, fb) = (fiches[a.rang], fiches[b.rang])
            let (ea, eb) = (fa.entree, fb.entree)
            if a.parLieu != b.parLieu { return b.parLieu }
            if ea.enDernier != eb.enDernier { return eb.enDernier }
            if tri == .auto { return ScorePalette.avant(a.score, b.score) ?? (a.rang < b.rang) }
            if (ea.genre == .zaap) != (eb.genre == .zaap) { return ea.genre == .zaap }
            if ea.favori != eb.favori { return ea.favori }
            if let ordre = RecherchePalette.comparer(fa, fb, tri) { return ordre }
            let (pa, pb) = (a.score.correspondance ?? 0, b.score.correspondance ?? 0)
            if pa != pb { return pa > pb }
            return a.rang < b.rang
        }
        guard exactes.count < seuilTolerance else { return Retenues(exactes: exactes, tolerees: [], avant: avant) }
        let gardees = Set(exactes.map(\.rang))
        let tolerees = approchees(fiches, mots, sauf: gardees).map { retenue($0.rang, $0.points) }
        return Retenues(exactes: exactes, tolerees: tolerees, avant: avant)
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
        /// Les mots du titre seuls, bout à bout : un mot cherché au milieu du nom.
        private let interieurDuNom: String
        /// Les mots du titre et de l'étiquette, prêts pour la borne basse de
        /// `Ressemblance` : une fiche trop loin d'un mot approché s'écarte sans
        /// calculer de distance.
        private let forme: Ressemblance.Forme

        /// Tout ce dont les champs dépendent : une entrée qui garde sa clé garde ses champs.
        static func cle(_ entree: EntreePalette) -> String {
            [entree.id, entree.titre, entree.etiquette ?? "", entree.sousTitre ?? "", entree.autresLieux ?? "",
             entree.categorie.map(String.init) ?? ""].joined(separator: "\u{1F}")
        }

        init(_ entree: EntreePalette) {
            self.init(titre: entree.titre, etiquette: entree.etiquette,
                      lieu: [entree.sousTitre, entree.autresLieux].compactMap(\.self).joined(separator: " "),
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
            interieurDuNom = self.titre.joined(separator: "\u{1F}")
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

        /// Un mot tapé au moins répond à l'étiquette, au titre ou à un surnom — pas seulement au lieu.
        func nomRepond(_ mots: [String]) -> Bool {
            mots.contains { mot in
                etiquette.contains { $0.hasPrefix(mot) } || titre.contains { $0.hasPrefix(mot) } || surnoms.contains(mot)
                    || (mot.count >= 3 && interieurDuNom.contains(mot))
            }
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
    private(set) lazy var persos = fiches(RecherchePalette.persos(contexte))
    /// Sans préfixe : persos, zaaps, lieux, quêtes, PNJ, gestes, dernières copies,
    /// monstres et objets.
    private(set) lazy var tout = persos + zaaps + lieux + quetes + pnjs + fiches(RecherchePalette.divers(contexte)) + monstres + objets

    /// Les champs de toutes les fiches, à garder pour l'index suivant.
    static func champs(de contexte: ContextePalette, connus: [String: RecherchePalette.Champs] = [:])
        -> [String: RecherchePalette.Champs] {
        let index = IndexPalette(contexte, connus: connus)
        return Dictionary((index.tout + index.zaapsCommeLieux).map { (RecherchePalette.Champs.cle($0.entree), $0.champs) },
                          uniquingKeysWith: { a, _ in a })
    }
}
