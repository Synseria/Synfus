import AppKit
import SwiftUI
import Testing
@testable import Synfus
import SynseriaDesign

/// Les captures de la documentation et des notes de version : les vues de
/// Synfus rendues hors écran, sur des données d'exemple — jamais un visuel du
/// jeu. Ignoré sans `SYNFUS_CAPTURES=<dossier>` ; pour `docs/screenshots` :
/// `SYNFUS_CAPTURES=$PWD/docs/screenshots sh test.sh CapturesTests`.
@MainActor
struct CapturesTests {
    nonisolated private static let dossier = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES"]
    /// `SYNFUS_CAPTURES_APPARENCE=clair` pour les captures en clair ; sombre sinon, celui de la doc.
    nonisolated private static let clair = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES_APPARENCE"] == "clair"
    nonisolated private static let schema: ColorScheme = clair ? .light : .dark
    // swiftlint:disable:next couleur_en_dur - le fond commun des captures, volontairement hors des jetons de l'app
    private static let fondCapture = Color(red: 0.11, green: 0.11, blue: 0.13)
    nonisolated private static let apparence: NSAppearance.Name = clair ? .aqua : .darkAqua

    private func contexte() -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna (Village d'Amakna)")
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: CarteDuJeu.integree.zaaps, ajoutes: [], choix: [:]),
                                     reseau: ReseauSousZones(CarteDuJeu.integree))
        contexte.lieux = CarteDuJeu.integree.lieux
        contexte.etiquettes = ["1:-78,-41": "Fri 1", "1:-77,-73": "Fri 2", "1:39,-82": "Fri 3",
                               "1:-2,0": "Village", "1:-16,1": "Koalak", "1:5,7": "Bouftou",
                               "1:-31,-56": "Portails Dimensionnels", "1:-26,37": "Brâk"]
        contexte.favoris = ["1:-31,-56", "1:-26,37", "1:-78,-41"]
        contexte.recents = ["/zaap -31,-56 ; /travel -31,-57", "/invite Brok; /invite Cid", "%pos%"]
        contexte.invitationEquipe = "/invite Brok; /invite Cid"
        contexte.invitations = [(nom: "Brok", commande: "/invite Brok"), (nom: "Cid", commande: "/invite Cid")]
        contexte.quetes = QuetesDofusDB.gardees()
        contexte.quetesSuivies = Set(contexte.quetes?.quetes.prefix(2).map(\.id) ?? [])
        return contexte
    }

    /// Une équipe d'exemple, pour la barre et l'onglet Raccourcis.
    private func equipe(huit: Bool = false) {
        var persos = [("Syn-App", "Feca"), ("Syn-Ops", "Huppermage"), ("Brok", "Iop"), ("Cid", "Eniripsa")]
        if huit { persos += [("Aeryn", "Cra"), ("Nova", "Sram"), ("Zoé", "Osamodas"), ("Tolbrek", "Sacrieur")] }
        WindowManager.shared.poserPourCaptures(persos.enumerated().map { rang, perso in
            let pid = pid_t(90_000 + rang)
            return DofusClient(pid: pid, slotKey: "\(pid)#0", axWindow: .application(pid),
                               rawTitle: "\(perso.0) - \(perso.1) - 3.6.8.8 - Release", name: perso.0,
                               characterClass: perso.1, dormant: false)
        })
        // Le premier au premier plan : sa pastille est celle qu'on voit allumée.
        WindowManager.shared.frontmostPID = 90_000
        WindowManager.shared.frontmostIsDofus = true
    }

    @Test("Capture de la barre", .enabled(if: dossier != nil))
    func barre() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        equipe()
        let vue = BarView()
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "barre.png"))
    }

    @Test("Capture de la barre en équipe, sa pilule devant les pastilles", .enabled(if: dossier != nil))
    func barreEnEquipe() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        equipe()
        let prefs = Preferences.shared
        for (nom, rang) in [("Syn-App", 0), ("Syn-Ops", 0), ("Brok", 1)] { prefs.affecter(nom, aEquipe: rang) }
        WindowManager.shared.activerEquipe(0)
        defer {
            WindowManager.shared.activerEquipe(nil)
            for nom in ["Syn-App", "Syn-Ops", "Brok"] { prefs.affecter(nom, aEquipe: nil) }
        }
        let vue = BarView()
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "barre-equipe.png"))
    }

    @Test("Capture de la barre à huit personnages, pleine puis réduite", .enabled(if: dossier != nil))
    func barreHuitPersos() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        equipe(huit: true)
        let prefs = Preferences.shared
        let avant = prefs.reduirePersosInactifs
        defer { prefs.reduirePersosInactifs = avant }
        for (nom, reduite) in [("barre-huit-reduite", true), ("barre-huit", false)] {
            prefs.reduirePersosInactifs = reduite
            let vue = BarView()
                .padding(24)
                .background(Self.fondCapture)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    @Test("Capture du décompte du tour, au rose puis dans les cinq dernières secondes", .enabled(if: dossier != nil))
    func decompteDuTour() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        let vue = HStack(spacing: 40) {
            ForEach([20.0, 3.0], id: \.self) { reste in
                Text("Syn-App").padding(Jetons.espace3)
                    .overlay { CombatBadge(etat: .monTour(fin: Date().addingTimeInterval(reste))) }
            }
        }
        .padding(32)
        .background(Self.fondCapture)
        .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "combat-decompte.png"))
    }

    @Test("Captures de la palette", .enabled(if: dossier != nil))
    func palette() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        for (nom, requete) in [("palette-zaaps", ""), ("palette-travel", "/travel banque bonta"),
                               ("palette-commandes", "/"), ("palette-quetes", "/quete âme")] {
            let modele = PaletteModele(contexte: contexte(), requete: requete)
            let vue = PaletteVue(modele: modele)
                .padding(24)
                .background(Self.fondCapture)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    /// Les vues de la palette : l'Accueil, « Zaaps », « Donjons », « PNJ », « Quêtes », « Almanax » (sept jours d'exemple, sans visuel du jeu), une recherche.
    @Test("Captures des vues de la palette", .enabled(if: dossier != nil))
    func vuesDeLaPalette() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let offrandes = [("Leurnettes", 1, "Quête répétable"), ("Poils de Pétartifoux", 4, "Challenge supplémentaire"),
                         ("Gelée Bleue", 3, "Bonus d'expérience"), ("Plume de Piou Rouge", 8, "Récolte favorisée"),
                         ("Cuir de Bouftou", 2, "Butin amélioré"), ("Fil de Tisserand", 5, "Quête répétable"),
                         ("Peau de Larve", 6, "Challenge supplémentaire")]
        let jours = try zip(Almanax.semaine(depuis: Date()), offrandes).map { jour, offrande in
            let json = #"{"name":{"fr":"\#(offrande.2)"},"desc":{"fr":"Un bonus spécial est disponible aujourd'hui près de la vieille chapelle d'Astrub, pour les joueurs de niveau 20 et plus."},"itemIds":[1],"quantities":[\#(offrande.1)],"items":[{"id":1,"name":{"fr":"\#(offrande.0)"}}]}"#
            return Almanax(try JSONDecoder().decode(Almanax.API.self, from: Data(json.utf8)), jour: jour)
        }
        AlmanaxStore.shared.poserPourCaptures(Array(jours.prefix(6)))
        // Le Sanctuaire vient de la carte : sans elle, la carte du jour n'a pas son bouton.
        CarteStore.shared.poserPourCaptures(CarteDuJeu.integree)
        for (nom, requete, filtre, deplie) in [("palette-accueil", "", FiltrePalette.tout, false),
                                               ("palette-vue-zaaps", "", .zaaps, false),
                                               ("palette-vue-donjons", "", .donjons, false),
                               ("palette-vue-pnj", "", .pnj, false),
                               ("palette-vue-quetes", "", .quetes, false),
                               ("palette-vue-almanax", "", .almanax, false),
                                               ("palette-vue-almanax-deplie", "", .almanax, true),
                                               ("palette-recherche", "bonta", .tout, false)] {
            let modele = PaletteModele(contexte: contexte(), requete: requete, filtre: filtre)
            if deplie { modele.deplacer(colonne: 1) }
            let vue = PaletteVue(modele: modele)
                .padding(24)
                .background(Self.fondCapture)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    /// Des PNJ à une, deux, trois et cinq positions, dont un à cent cinquante quêtes : les cartes de leurs positions.
    private func contexteDePNJ() -> ContextePalette {
        var contexte = contexte()
        let passage = { (x: Int, y: Int, quetes: [Int], sousZone: Int) in
            PNJ.Passage(position: .init(x: x, y: y), carte: nil, sousZone: sousZone, quetes: quetes)
        }
        let lieux = [(10, "Village d'Amakna", "Amakna"), (11, "Champs de Cania", "Cania"), (12, "Plaine des Porcos", "Cania"),
                     (13, "Forêt maléfique", "Amakna"), (14, "Mine de Kanabo", "Amakna")]
        let noms = ["Chasse au Bouftou", "Le sang du wabbit", "Poils de Pétartifoux", "Les Tofus de la plaine", "Livraison urgente",
                    "Le retour de Wogew", "Une herbe rare", "Les gelées d'Astrub", "Le crâne de Larve", "Gants de cuir"]
        let quetes = (1...150).map { id in
            Quete(id: id, noms: ["fr": "\(noms[id % noms.count]) \(id)"], niveau: 1, groupe: false, donjon: false,
                  prerequis: [], critere: nil, etapes: [])
        }
        contexte.quetes = Quetes(
            format: Quetes.formatActuel, date: .now, quetes: quetes,
            pnjs: [PNJ(id: 1, noms: ["fr": "Brokkeitri"], passages: [passage(-2, 0, [1, 2, 3, 4], 10), passage(-32, -57, [5, 6], 11),
                                                                    passage(14, 9, [7], 12)]),
                   PNJ(id: 2, noms: ["fr": "Amayiro"], passages: [passage(-32, -57, Array(1...150), 11), passage(3, 4, [2], 10),
                                                                  passage(8, -6, [3, 4], 12), passage(-14, 22, [5], 13),
                                                                  passage(20, 20, [6], 14)]),
                   PNJ(id: 3, noms: ["fr": "Brokar"], passages: [passage(5, 7, [8, 9, 10], 10)]),
                   PNJ(id: 4, noms: ["fr": "Tiluk"], passages: [passage(-1, -1, [1, 2], 10), passage(30, -4, [3], 13)])],
            objets: [:], monstres: [:], nomsPNJ: [:],
            sousZones: Dictionary(uniqueKeysWithValues: lieux.map { (String($0.0), SousZoneNommee(noms: ["fr": $0.1], zone: ["fr": $0.2])) }),
            famillesObjets: [:], familles: [:], emotes: [:], titres: [:], metiers: [:], camps: [:])
        contexte.favoris = ["pnj:4"]
        contexte.etiquettes = ["pnj:3": "Banque"]
        return contexte
    }

    @Test("Captures des positions d'un PNJ", .enabled(if: dossier != nil))
    func positionsDePNJ() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        for (nom, requete, filtre, deplie) in [("palette-pnj-3-positions", "brokkeitri", FiltrePalette.tout, true),
                                               ("palette-pnj-5-positions", "amayiro", .tout, true),
                                               ("palette-pnj-2-positions", "tiluk", .tout, true),
                                               ("palette-pnj-1-position", "brokar", .tout, true),
                                               ("palette-pnj-recherche", "bro", .tout, false),
                                               ("palette-pnj-vue", "", .pnj, false)] {
            let modele = PaletteModele(contexte: contexteDePNJ(), requete: requete, filtre: filtre)
            if deplie { _ = modele.lateral(1) }
            // La carte d'à côté : la rangée suit la sélection.
            if nom.hasSuffix("5-positions") { _ = modele.lateral(1); _ = modele.lateral(1); _ = modele.lateral(1) }
            let vue = PaletteVue(modele: modele)
                .padding(24)
                .background(Self.fondCapture)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    /// Une recherche à doublons sur données factices (`ContexteNidas`) : boss et donjon, PNJ homonymes,
    /// PNJ trouvés par leur seul lieu, objets au nom du roi.
    @Test("Capture d'une recherche à doublons", .enabled(if: dossier != nil))
    func rechercheNidas() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        for (nom, requete, suite) in [("palette-nidas", "nidas", false), ("palette-nidas-palais", "palais", false),
                                      ("palette-nidas-suite", "nidas", true)] {
            let modele = PaletteModele(contexte: try ContexteNidas.contexte(), requete: requete)
            // La ligne « de plus » choisie : son pied.
            if suite, let rang = modele.entrees.firstIndex(where: { if case .famille = $0.effet { true } else { false } }) {
                modele.selection = rang
            }
            let vue = PaletteVue(modele: modele)
                .padding(24)
                .background(Self.fondCapture)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    /// Les états de la palette que la doc ne montre pas : coordonnées, perso, variables, listes vides.
    @Test("Captures des états de la palette", .enabled(if: dossier != nil && ProcessInfo.processInfo.environment["SYNFUS_CAPTURES_ETATS"] != nil))
    func etatsDeLaPalette() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        var avecPersos = contexte()
        avecPersos.perso = "Syn-App"
        avecPersos.persos = [
            PersoPalette(slotKey: "1#0", nom: "Syn-App", classe: "Feca", position: avecPersos.position, touche: "⌘1"),
            PersoPalette(slotKey: "2#0", nom: "Brok", classe: "Iop", position: PositionCarte(x: -31, y: -56, zone: nil), touche: "⌘3"),
        ]
        var sansPosition = contexte()
        sansPosition.position = nil
        let cas: [(String, ContextePalette, String, FiltrePalette, EtatCarte)] = [
            ("palette-coordonnees", avecPersos, "-31,-56", .tout, .prete),
            ("palette-perso", avecPersos, "brok", .tout, .prete),
            ("palette-variables", avecPersos, "%", .tout, .prete),
            ("palette-rien", avecPersos, "lancer la session", .lieux, .prete),
            ("palette-carte-chargement", ContextePalette(), "", .tout, .chargement),
            ("palette-carte-indisponible", ContextePalette(), "", .tout, .indisponible),
            ("palette-position-inconnue", sansPosition, "", .tout, .prete),
        ]
        for (nom, contexte, requete, filtre, carte) in cas {
            let vue = PaletteVue(modele: PaletteModele(contexte: contexte, requete: requete, filtre: filtre, carte: carte))
                .padding(24)
                .background(Self.fondCapture)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    @Test("Capture d'une quête ouverte", .enabled(if: dossier != nil))
    func quete() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        // Une vraie quête si celles de DofusDB sont sur la machine, sinon
        // celle des tests : des textes et des coordonnées, aucun visuel.
        let gardees = QuetesDofusDB.gardees()
        let reelle = gardees.flatMap { quetes in
            quetes.quetes.first { $0.noms["fr"] == "L'éternelle moisson" }.map { quetes.fiche($0, en: .fr) }
        }
        let fiche = Self.sansCartes(try reelle ?? #require(try QuetesTests.quetes().fiche(18, en: .fr)))
        let premier = fiche.etapes.first?.objectifs.first?.id
        equipe()
        let maintenant = Date()
        let lus = ["Brok", "Cid", "Syn-App", "Syn-Ops", "Zed", "Zoé"].map {
            HistoriqueSuivi.EtapeLue(perso: $0, etape: 0, date: maintenant)
        }
        let vue = QueteVue(ficheImposee: fiche, etapeImposee: reelle == nil ? 1 : 0,
                           validesImposes: reelle == nil ? [101] : Set(premier.map { [$0] } ?? []),
                           ressourcesImposees: Set(fiche.ressources.prefix(1).map(\.objet)), lusImposes: lus)
            .frame(width: 360, height: 560)
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        let prefs = Preferences.shared
        let avant = prefs.quetesCompact
        defer { prefs.quetesCompact = avant }
        for (nom, compact) in [("quete", true), ("quete-confort", false)] {
            prefs.quetesCompact = compact
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
        // À sa taille minimale : rien ne déborde, l'en-tête de l'étape passe sur deux lignes.
        prefs.quetesCompact = true
        let etroite = QueteVue(ficheImposee: fiche, etapeImposee: reelle == nil ? 1 : 0, lusImposes: lus)
            .frame(width: QuetePanel.tailleMinimale.width, height: 300)
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(etroite, vers: dossier.appending(path: "quete-etroite.png"))
        // Une quête courte en entier, si elle est sur la machine : exigences, objectifs faits
        // repliés, récompenses, suite.
        if let courte = gardees.flatMap({ quetes in
            quetes.quetes.first { $0.noms["fr"] == "On se calme" }.map { quetes.fiche($0, en: .fr) }
        }).map(Self.sansCartes) {
            let faits = Set(courte.etapes.first?.objectifs.prefix(4).map(\.id) ?? [])
            let vue = QueteVue(ficheImposee: courte, etapeImposee: 0, validesImposes: faits, lusImposes: [])
                .frame(width: 360, height: 520)
                .padding(24)
                .background(Self.fondCapture)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: "quete-courte.png"))
        }
    }

    @Test("Capture du panneau de quête sans quête épinglée, au suivi long", .enabled(if: dossier != nil))
    func queteVide() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let modele = try QuetesTests.quetes()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(modele)) as? [String: Any])
        let premiere = try #require((json["quetes"] as? [[String: Any]])?.first)
        let noms = ["Apprentissage : Écaflip, le joueur de dés", "L'éternelle moisson", "Le sang du wabbit GM",
                    "Apprentissage : Éniripsa, la guérisseuse du village", "Chasseur de têtes", "Les fils de la forêt maudite",
                    "Une affaire de famille", "Le retour de l'enfant prodigue", "Trois pas vers la lumière"]
        json["quetes"] = noms.enumerated().map { rang, nom -> [String: Any] in
            var quete = premiere
            quete["id"] = 9000 + rang
            quete["noms"] = ["fr": nom]
            return quete
        }
        let quetes = try JSONDecoder().decode(Quetes.self, from: JSONSerialization.data(withJSONObject: json))
        QuetesStore.shared.poserPourCaptures(quetes)
        // Le perso devant d'abord : en changer ramène le suivi lu à celui qu'il a (vide).
        // Chaque quête commence sur sa case : le signe de l'en-tête.
        LecteurEcran.shared.poserPourCaptures(persoDevant: "Aeryn", position: PositionCarte(x: -1, y: -39, zone: nil))
        defer { LecteurEcran.shared.poserPourCaptures(persoDevant: nil, position: nil) }
        LectureSuivi.shared.poserPourCaptures(reconnues: noms.indices.map { SuiviQuetes.Reconnue(id: 9000 + $0, etape: $0 % 3 == 0 ? nil : $0) })
        let vue = QueteVue()
            .frame(width: 360, height: 480)
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "quete-vide.png"))
        // À sa taille minimale, rien ne déborde : le verre garde sa marge, « ⋯ » son coin.
        let minimale = QuetePanel.tailleMinimale
        try ecrire(QueteVue().frame(width: minimale.width, height: minimale.height).padding(24)
            .background(Self.fondCapture).environment(\.colorScheme, Self.schema),
                   vers: dossier.appending(path: "quete-vide-etroite.png"))
        // La liste avec des quêtes au panneau : le suivi ne propose plus que les autres.
        let prefs = Preferences.shared
        let avant = prefs.quetesEpinglees
        defer { prefs.quetesEpinglees = avant }
        prefs.quetesEpinglees = [9001, 9003, 9004]
        QuetePanel.shared.enListe = true
        defer { QuetePanel.shared.enListe = false }
        try ecrire(vue, vers: dossier.appending(path: "quete-liste.png"))
        // Plié : le bandeau seul.
        let plies = prefs.panneauxPlies
        defer { prefs.panneauxPlies = plies }
        prefs.panneauxPlies = [PanneauJeu.quetes.rawValue: 480]
        try ecrire(QueteVue().frame(width: minimale.width).padding(24)
            .background(Self.fondCapture).environment(\.colorScheme, Self.schema),
                   vers: dossier.appending(path: "quete-pliee.png"))
    }

    /// Sans la vue des cartes : elle viendrait de DofusDB, et une capture du
    /// dépôt ne porte aucun visuel du jeu (CGU Dofus, art. 13.2).
    private static func sansCartes(_ fiche: FicheQuete) -> FicheQuete {
        FicheQuete(
            id: fiche.id, nom: fiche.nom, nomFrancais: fiche.nomFrancais, niveau: fiche.niveau, groupe: fiche.groupe,
            donjon: fiche.donjon, exigences: fiche.exigences, ressources: fiche.ressources,
            etapes: fiche.etapes.map { etape in
                FicheQuete.Etape(nom: etape.nom, description: etape.description, objectifs: etape.objectifs.map {
                    FicheQuete.Objectif(id: $0.id, texte: $0.texte, position: $0.position, carte: nil, combat: $0.combat)
                }, recompenses: etape.recompenses)
            },
            suivantes: fiche.suivantes)
    }

    @Test("Capture du panneau de chasse", .enabled(if: dossier != nil))
    func chasse() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        ChasseModele.shared.departX = -2
        ChasseModele.shared.departY = 0
        let vue = ChasseVue()
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "chasse.png"))
        try ecrire(vue.environment(\.largeurPanneau, ChasseVue.largeurs.upperBound), vers: dossier.appending(path: "chasse-max.png"))
        let indice = Indice(id: 993, noms: ["fr": "Poupée koalak"])
        let longue = Indice(id: 1, noms: ["fr": "Crâne de likrone dans la glace, près du vieux pont"])
        ChasseModele.shared.poserResultatPourCaptures(cible: .indice(indice), lues: [.indice(longue), .indice(indice)])
        try ecrire(vue, vers: dossier.appending(path: "chasse-resultat.png"))
        ChasseModele.shared.viderPourCaptures()
        try ecrire(vue, vers: dossier.appending(path: "chasse-depart-inconnu.png"))
        ChasseModele.shared.poserEchecPourCaptures()
        try ecrire(vue, vers: dossier.appending(path: "chasse-indisponible.png"))
    }

    @Test("Capture du panneau des boss", .enabled(if: dossier != nil))
    func boss() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        let vue = BossVue()
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "boss.png"))
        for (nom, largeur) in [("min", BossVue.largeurs.lowerBound), ("max", BossVue.largeurs.upperBound)] {
            try ecrire(vue.environment(\.largeurPanneau, largeur), vers: dossier.appending(path: "boss-\(nom).png"))
        }
    }

    /// Les vues de chaque boss, posées sur la carte du panneau, avec ce que l'aide
    /// aurait noté à la main : le tour et les lectures ne se forcent pas hors du jeu.
    @Test("Captures des vues de boss", .enabled(if: dossier != nil))
    func vuesBoss() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        func panneau(_ nom: String, @ViewBuilder _ vue: () -> some View) throws {
            let carte = VStack(alignment: .leading, spacing: Jetons.espace2) { vue() }
                .padding(Jetons.espace3)
                .frame(width: BossVue.largeur, alignment: .leading)
                .font(Jetons.typoMeta.font)
                .surfaceFlottante()
                .padding(24)
                .environment(\.colorScheme, Self.schema)
            try ecrire(carte, vers: dossier.appending(path: "boss-\(nom).png"))
        }
        let aide = AideBoss.shared
        try panneau("harebourg") { HarebourgVue() }
        try panneau("kimbo-attente") { KimboVue() }
        aide.noter { session, _ in session.kimbo = .impair }
        try panneau("kimbo") { KimboVue() }
        try panneau("toxoliath") { ToxoliathVue() }
        try panneau("ilyzaelle") { IlyzaelleVue() }
        aide.noter { session, _ in session.ilyzaelle75 = 1 }
        try panneau("ilyzaelle-75") { IlyzaelleVue() }
        aide.noter { session, _ in session.glyphesTalKasha = 2 }
        try panneau("talkasha") { TalKashaVue() }
        aide.noter { session, _ in session = SessionBoss() }
        // Une section courte garde sa hauteur, une longue défile sous son plafond.
        let conseils = (1...14).map { ConseilCombat(titre: "Conseil \($0) : tuer les Bouftons avant qu'ils ne soignent", detail: "") }
        try panneau("sections") {
            SectionBoss(titre: L("boss.rappels"), depliee: .constant(true)) {} contenu: {
                ConseilsVue(conseils: Array(conseils.prefix(2)))
            }
            SectionBoss(titre: L("donjon.conseils"), depliee: .constant(true)) {} contenu: {
                ConseilsVue(conseils: conseils)
            }
        }
    }

    @Test("Capture de la fiche d'un boss", .enabled(if: dossier != nil))
    func ficheBoss() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        let json = """
        {"grades":[{"grade":5,"level":200,"lifePoints":12000,"actionPoints":12,"movementPoints":6,
         "reductionNeutral":20,"reductionEarth":35,"reductionFire":-10,"reductionWater":-5,"reductionAir":40}]}
        """
        let fiche = try #require(FicheCombat(try JSONDecoder().decode(FicheCombat.MonstreAPI.self, from: Data(json.utf8))))
        let vue = FicheCombatVue(fiche: fiche)
            .padding(Jetons.espace3)
            .frame(width: BossVue.largeur)
            .surfaceFlottante()
            .padding(24)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "boss-fiche.png"))
    }

    @Test("Capture du tableau des combinaisons de l'Huppermage", .enabled(if: dossier != nil))
    func huppermage() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        let vue = TableauHuppermage()
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "huppermage.png"))
    }

    @Test("Capture de la recette épinglée", .enabled(if: dossier != nil))
    func recette() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let recette = SourcesObjet.Recette(
            metier: ["fr": "Bricoleur"], niveau: 60,
            ingredients: [("Planche de Frêne", 3), ("Gelée Bleue", 10), ("Poils de Pétartifoux et autres fibres", 4),
                          ("Clef du Donjon des Bouftous", 1)].map { .init(noms: ["fr": $0.0], quantite: $0.1) })
        let vue = FicheRecette(recette: RecetteEpinglee(recette, objet: "Clef du Château du Wa Wabbit", langue: .fr))
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "recette.png"))
        // Aux bornes de leur largeur, rien ne se coupe ni ne déborde.
        for (nom, largeur) in [("min", RecetteVue.largeurs.lowerBound), ("max", RecetteVue.largeurs.upperBound)] {
            try ecrire(vue.environment(\.largeurPanneau, largeur), vers: dossier.appending(path: "recette-\(nom).png"))
        }
    }

    /// Une fiche de donjon aux données factices : une capture par onglet, la palette la fiche ouverte sous sa
    /// ligne (sur l'onglet le plus court et le plus long : même hauteur), un donjon à deux boss et deux clefs.
    @Test("Capture de la fiche d'un donjon", .enabled(if: dossier != nil))
    func ficheDonjon() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let api = """
        [{"id":71,"name":{"fr":"Palais du roi Nidas"},"optimalPlayerLevel":200,"entranceMapId":112460048,
          "requiredObjects":[{"id":14047,"quantity":1}],"bosses":[3416],"monsters":[3384,3416],"achievements":[892,893]},
         {"id":72,"name":{"fr":"Repaire des jumeaux"},"optimalPlayerLevel":190,"entranceMapId":112460049,
          "requiredObjects":[{"id":14048,"quantity":1},{"id":14049,"quantity":1}],"bosses":[3417,3418],"monsters":[3417,3418],"achievements":[]}]
        """
        let liste = Donjons(try JSONDecoder().decode([Donjon.API].self, from: Data(api.utf8)).map(Donjon.init),
                            nomsBoss: [3416: ["fr": "Roi Nidas"], 3417: ["fr": "Jumeau de gauche"], 3418: ["fr": "Jumeau de droite"]])
        func fiche(_ niveau: Int, _ vie: Int, _ pa: Int, _ pm: Int, _ resistances: [Int]) throws -> FicheCombat {
            let json = """
            {"grades":[{"grade":5,"level":\(niveau),"lifePoints":\(vie),"actionPoints":\(pa),"movementPoints":\(pm),
             "reductionNeutral":\(resistances[0]),"reductionEarth":\(resistances[1]),"reductionFire":\(resistances[2]),
             "reductionWater":\(resistances[3]),"reductionAir":\(resistances[4])}]}
            """
            return try #require(FicheCombat(try JSONDecoder().decode(FicheCombat.MonstreAPI.self, from: Data(json.utf8))))
        }
        let monstres: [DetailDonjon.Monstre] = [
            .init(id: 3416, noms: ["fr": "Roi Nidas"], boss: true, fiche: try fiche(220, 22_000, 20, 5, [20, 35, -10, 15, 40])),
            .init(id: 1, noms: ["fr": "Kamasterisk"], boss: false, fiche: try fiche(212, 6_600, 12, 5, [10, -10, 30, 25, 5])),
            .init(id: 2, noms: ["fr": "Tournesol Affamé"], boss: false, fiche: try fiche(200, 4_200, 10, 4, [0, 15, 20, -15, 30])),
            .init(id: 3, noms: ["fr": "Bouftou Royal"], boss: false, fiche: try fiche(190, 3_000, 9, 4, [5, 5, 5, 5, 5]))]
        let succes: [DetailDonjon.Succes] = [
            .init(noms: ["fr": "Roi Nidas (Spécial)"], description: ["fr": "Vaincre le Roi Nidas sans perdre un seul allié."]),
            .init(noms: ["fr": "Roi Nidas (Statue)"], description: ["fr": "Détruire les statues avant la fin du troisième tour."]),
            .init(noms: ["fr": "Roi Nidas (Rapide)"], description: ["fr": "Vaincre le Roi Nidas en moins de dix tours."])]
        let clef = DetailDonjon.Clef(objet: 14047, noms: ["fr": "Clef du Palais du roi Nidas"], quantite: 1)
        let detail = DetailDonjon(monstres: monstres, clefs: [clef], succes: succes)
        let conseils = ["Dommage à distance.", "Entrave (PM, PO).", "Placement."].map { ConseilCombat(titre: $0, detail: "") }
        let jumeaux = DetailDonjon(
            monstres: [.init(id: 3417, noms: ["fr": "Jumeau de gauche"], boss: true, fiche: try fiche(190, 9_000, 12, 5, [10, 10, 10, 10, 10])),
                       .init(id: 3418, noms: ["fr": "Jumeau de droite"], boss: true, fiche: try fiche(190, 9_500, 12, 6, [0, 20, 0, 20, 0]))],
            clefs: [.init(objet: 14048, noms: ["fr": "Clef de gauche"], quantite: 1), .init(objet: 14049, noms: ["fr": "Clef de droite"], quantite: 1)],
            succes: [])
        DonjonsStore.shared.poserPourCaptures(liste, details: [71: detail, 72: jumeaux], conseils: [71: conseils])
        let ingredients = ["Sourcil de Barbétoal", "Dent de Lévitrof", "Écaille de Frostiz", "Griffe de Dragoune",
                           "Plume de Corbac", "Peau de Bouftou", "Laine de Mouton", "Œil de Vampyre"]
        OuTrouverStore.shared.poserPourCaptures(objet: 14047, SourcesObjet(
            lacheurs: [], recette: .init(metier: ["fr": "Bricoleur"], niveau: 200,
                                         ingredients: ingredients.map { .init(noms: ["fr": $0], quantite: 2) })))
        var contexte = ContextePalette()
        contexte.donjons = liste
        let reperes = Lieu(id: 1, x: -67, y: -75, monde: 1, idCarte: 112460048, idSousZone: 794,
                           categorie: CategorieLieu.donjon.rawValue, gfx: nil, noms: ["fr": "Palais du roi Nidas"], zone: [:], sousZone: [:])
        let repaire = Lieu(id: 2, x: -60, y: -70, monde: 1, idCarte: 112460049, idSousZone: 794,
                           categorie: CategorieLieu.donjon.rawValue, gfx: nil, noms: ["fr": "Repaire des jumeaux"], zone: [:], sousZone: [:])
        contexte.lieux = [reperes, repaire]
        // L'entrée de la fiche (le bouton « Position », ↵) se lit sur les repères de la carte.
        CarteStore.shared.poserPourCaptures(CarteDuJeu(date: .now, lieux: [reperes, repaire], sousZones: [], cases: [:]))
        let modele = PaletteModele(contexte: contexte, filtre: .donjons)
        let entree = try #require(modele.entrees.first { $0.effet == .donjon(71) })
        modele.executer(entree)
        func ecrireFiche(_ nom: String, id: Int = 71) throws {
            let vue = FicheDonjonVue(id: id, modele: modele)
                .padding(Jetons.espace3)
                .frame(width: Jetons.largeurPalette, alignment: .leading)
                .font(Jetons.typoMeta.font)
                .surfaceFlottante()
                .padding(24)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: "fiche-\(nom).png"))
        }
        func ecrirePalette(_ nom: String) throws {
            let vue = PaletteVue(modele: modele)
                .padding(24)
                .background(Self.fondCapture)
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: "palette-fiche-\(nom).png"))
        }
        #expect(modele.fiche.onglets == [.boss, .conseils, .monstres, .succes, .clef(objet: 14047)])
        #expect(modele.ongletCourant == .boss && modele.surOnglets)
        let noms: [OngletFiche: String] = [.boss: "boss", .conseils: "conseils", .monstres: "monstres", .succes: "succes",
                                          .clef(objet: 14047): "clef"]
        for onglet in modele.fiche.onglets {
            try ecrireFiche(try #require(noms[onglet]))
            // → passe à l'onglet suivant, sans Entrée.
            #expect(modele.lateral(1))
        }
        #expect(modele.ongletCourant == .clef(objet: 14047))
        modele.choisir(onglet: .boss)
        try ecrirePalette("boss")
        modele.choisir(onglet: .monstres)
        try ecrirePalette("monstres")
        // ← sur le premier onglet replie la fiche.
        modele.choisir(onglet: .boss)
        #expect(modele.lateral(-1) && modele.deplie == nil)

        let deux = try #require(modele.entrees.first { $0.effet == .donjon(72) })
        modele.executer(deux)
        #expect(modele.fiche.onglets == [.boss, .clef(objet: 14048), .clef(objet: 14049)])
        try ecrireFiche("deux-boss", id: 72)
        try ecrirePalette("deux-boss")

        // Une ligne de boss trouvée par recherche, la plus chargée : sous-titre long et trois boutons.
        let recherche = PaletteModele(contexte: contexte, requete: "nidas", filtre: .donjons)
        let boss = try #require(recherche.entrees.first { $0.id == "boss:3416" })
        recherche.executer(boss)
        #expect(recherche.deplie == boss.id && recherche.fiche.principale != nil)
        let vue = PaletteVue(modele: recherche)
            .padding(24)
            .background(Self.fondCapture)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "palette-fiche-recherche.png"))
    }

    @Test("Captures des réglages", .enabled(if: dossier != nil))
    func reglages() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        equipe()
        CarteStore.shared.poserPourCaptures(CarteDuJeu.integree)
        QuetesStore.shared.poserPourCaptures(try QuetesTests.quetes())
        let toutes = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES_TOUT"] != nil
        // `SYNFUS_CAPTURES_HAUTEUR` : la fenêtre plus haute, pour voir une page longue en entier.
        let hauteur = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES_HAUTEUR"].flatMap(Double.init) ?? 680
        let onglets: [OngletSynfus] = toutes ? [.general, .theme] + SettingsSection.allCases.map { .propre($0) }
            : [.general, .theme, .propre(.barre), .propre(.donnees), .propre(.raccourcis), .propre(.lecture)]
        for onglet in onglets {
            let nom: String = switch onglet {
            case .general: "reglages-general"
            case .theme: "reglages-theme"
            case .propre(let section): "reglages-" + section.rawValue
            }
            let vue = SettingsView(onglet: OngletReglages(onglet), hauteur: CGFloat(hauteur))
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
        // L'échec du téléchargement des quêtes : l'état occupe le bloc entier.
        QuetesStore.shared.poserPourCaptures(nil, echec: "hors ligne")
        let vue = SettingsView(onglet: OngletReglages(.propre(.donnees)), hauteur: CGFloat(hauteur))
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "reglages-quetes-indisponibles.png"))
    }

    @Test("Capture de la fenêtre des réglages, telle que bâtie", .enabled(if: dossier != nil))
    func fenetreDesReglages() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        equipe()
        NSApplication.shared.appearance = NSAppearance(named: Self.apparence)
        let fenetre = SettingsWindowController.batir(SettingsView(onglet: OngletReglages(.general))
            .environment(\.colorScheme, Self.schema))
        fenetre.appearance = NSAppearance(named: Self.apparence)
        let vue = try #require(fenetre.contentView)
        vue.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let rep = try #require(vue.bitmapImageRepForCachingDisplay(in: vue.bounds))
        vue.cacheDisplay(in: vue.bounds, to: rep)
        try #require(rep.representation(using: .png, properties: [:])).write(to: dossier.appending(path: "reglages-fenetre.png"))
    }

    @Test("Capture de la fenêtre À propos", .enabled(if: dossier != nil))
    func aPropos() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let vue = AProposVue(version: "1.4.2")
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "a-propos.png"))
    }

    /// Par une fenêtre hors écran : `ImageRenderer` ne dessine ni champ de
    /// texte ni défilement, qui sont des vues AppKit.
    private func ecrire(_ vue: some View, vers url: URL) throws {
        NSApplication.shared.appearance = NSAppearance(named: Self.apparence)
        let hote = NSHostingView(rootView: vue.racineSynfus())
        hote.frame = NSRect(origin: .zero, size: hote.fittingSize)
        let fenetre = NSWindow(contentRect: hote.frame, styleMask: .borderless, backing: .buffered, defer: false)
        fenetre.contentView = hote
        fenetre.appearance = NSAppearance(named: Self.apparence)
        hote.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let rep = try #require(hote.bitmapImageRepForCachingDisplay(in: hote.bounds))
        hote.cacheDisplay(in: hote.bounds, to: rep)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}
