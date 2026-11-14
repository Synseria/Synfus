import AppKit
import SwiftUI
import Testing
@testable import Synfus

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
    nonisolated private static let apparence: NSAppearance.Name = clair ? .aqua : .darkAqua

    private func contexte() -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna (Village d'Amakna)")
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:]),
                                     reseau: ReseauSousZones(Carte.integree))
        contexte.lieux = Carte.integree.lieux
        contexte.etiquettes = ["1:-78,-41": "Fri 1", "1:-77,-73": "Fri 2", "1:39,-82": "Fri 3",
                               "1:-2,0": "Village", "1:-16,1": "Koalak", "1:5,7": "Bouftou",
                               "1:-31,-56": "Bonta", "1:-26,37": "Brâk"]
        contexte.favoris = ["1:-31,-56", "1:-26,37", "1:-78,-41"]
        contexte.recents = ["/zaap -31,-56 ; /travel -31,-57", "/invite Brok; /invite Cid", "%pos%"]
        contexte.invitationEquipe = "/invite Brok; /invite Cid"
        contexte.invitations = [(nom: "Brok", commande: "/invite Brok"), (nom: "Cid", commande: "/invite Cid")]
        contexte.quetes = QuetesDofusDB.gardees()
        return contexte
    }

    /// Une équipe d'exemple, pour la barre et l'onglet Raccourcis.
    private func equipe() {
        let persos = [("Syn-App", "Feca"), ("Syn-Ops", "Huppermage"), ("Brok", "Iop"), ("Cid", "Eniripsa")]
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
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "barre.png"))
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
                .background(Color(red: 0.11, green: 0.11, blue: 0.13))
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
        let vue = QueteVue(ficheImposee: fiche, etapeImposee: reelle == nil ? 1 : 0,
                           validesImposes: reelle == nil ? [101] : Set(premier.map { [$0] } ?? []),
                           ressourcesImposees: Set(fiche.ressources.prefix(1).map(\.objet)))
            .frame(width: 360, height: 560)
            .padding(24)
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "quete.png"))
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
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "quete-vide.png"))
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
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "chasse.png"))
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
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "boss.png"))
    }

    /// Les vues de chaque boss, posées sur la carte du panneau, avec ce que l'aide
    /// aurait noté à la main : le tour et les lectures ne se forcent pas hors du jeu.
    @Test("Captures des vues de boss", .enabled(if: dossier != nil))
    func vuesBoss() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        func panneau(_ nom: String, @ViewBuilder _ vue: () -> some View) throws {
            let carte = VStack(alignment: .leading, spacing: Jetons.Espace.deux) { vue() }
                .padding(Jetons.Espace.trois)
                .frame(width: BossVue.largeur, alignment: .leading)
                .font(Jetons.Typo.note.police)
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
            .padding(Jetons.Espace.trois)
            .frame(width: BossVue.largeur)
            .surfaceFlottante()
            .padding(24)
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "boss-fiche.png"))
    }

    @Test("Captures des réglages", .enabled(if: dossier != nil))
    func reglages() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        equipe()
        CarteStore.shared.poserPourCaptures(Carte.integree)
        QuetesStore.shared.poserPourCaptures(try QuetesTests.quetes())
        let toutes = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES_TOUT"] != nil
        // `SYNFUS_CAPTURES_HAUTEUR` : la fenêtre plus haute, pour voir une page longue en entier.
        let hauteur = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES_HAUTEUR"].flatMap(Double.init) ?? 680
        let sections: [SettingsSection] = toutes ? SettingsSection.allCases : [.carte, .raccourcis, .lecture]
        for (nom, section) in sections.map({ ("reglages-" + $0.rawValue, $0) }) {
            let vue = SettingsView(onglet: OngletReglages(section), hauteur: CGFloat(hauteur))
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, Self.schema)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
        // L'échec du téléchargement des quêtes : l'état occupe le bloc entier.
        QuetesStore.shared.poserPourCaptures(nil, echec: "hors ligne")
        let vue = SettingsView(onglet: OngletReglages(.quetes), hauteur: CGFloat(hauteur))
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, Self.schema)
        try ecrire(vue, vers: dossier.appending(path: "reglages-quetes-indisponibles.png"))
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
