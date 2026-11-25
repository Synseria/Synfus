import Foundation
import Testing
@testable import Synfus

/// La fiche d'un donjon : retrouvée par son repère ou par un boss, détail
/// assemblé, et dans la palette.
struct DonjonsTests {

    private static let api = """
    [{"id":71,"name":{"fr":"Donjon du Comte Harebourg","en":"Count Harebourg's Dungeon"},"optimalPlayerLevel":200,
      "entranceMapId":112460048,"requiredObjects":[{"id":14047,"quantity":1}],"bosses":[3416],
      "monsters":[3384,3416],"achievements":[892,893]},
     {"id":171,"name":{"fr":"Expédition de l'Audace - Donjon du Comte Harebourg"},"bosses":[3416]},
     {"id":28,"name":{"fr":"Canopée du Kimbo"},"bosses":[1045]}]
    """

    private static func donjons() throws -> Donjons {
        let liste = try JSONDecoder().decode([Donjon.API].self, from: Data(api.utf8)).map(Donjon.init)
        return Donjons(liste, nomsBoss: [3416: ["fr": "Comte Harebourg"], 1045: ["fr": "Kimbo"]])
    }

    private static func lieu(_ nom: String, carte: Int) -> Lieu {
        Lieu(id: 1, x: -67, y: -75, monde: 1, idCarte: carte, idSousZone: 794, categorie: CategorieLieu.donjon.rawValue,
             gfx: nil, noms: ["fr": nom], zone: [:], sousZone: [:])
    }

    @Test("Un donjon se retrouve par la carte de son repère, sinon son nom, et par son boss — l'original, pas l'expédition")
    func index() throws {
        let donjons = try Self.donjons()
        #expect(donjons.donjon(de: Self.lieu("Autre nom", carte: 112460048))?.id == 71)
        #expect(donjons.donjon(de: Self.lieu("canopee du kimbo", carte: 1))?.id == 28)
        #expect(donjons.donjon(de: Self.lieu("Inconnu", carte: 1)) == nil)
        #expect(donjons.donjon(boss: 3416)?.id == 71)
        let harebourg = try #require(donjons.donjon(id: 71))
        #expect(harebourg.niveau == 200 && harebourg.clefs == [Donjon.Clef(objet: 14047, quantite: 1)])
        #expect(harebourg.succes == [892, 893])
    }

    @Test("La zone lue au-dessus de la position nomme son donjon, en toutes langues, malgré une écorchure")
    func zone() throws {
        let donjons = try Self.donjons()
        #expect(donjons.donjon(zone: "Frigost (Donjon du Comte Harebourg)")?.id == 71)
        #expect(donjons.donjon(zone: "Frigost (Count Harebourg's Dungeon)")?.id == 71)
        // L'expédition, au nom plus long, l'emporte sur le donjon qu'elle reprend.
        #expect(donjons.donjon(zone: "Expédition de l'Audace - Donjon du Comte Harebourg")?.id == 171)
        #expect(donjons.donjon(zone: "Île d'Otomaï (Canopee du Kimbo)")?.id == 28)
        #expect(donjons.donjon(zone: "Île d'Otomaï (Village de la Canopée)") == nil)
        #expect(donjons.donjon(zone: nil) == nil)
        // Un nom vide ou trop court venu de DofusDB ne se lit pas partout.
        let api = try JSONDecoder().decode([Donjon.API].self, from: Data(#"[{"id":5,"name":{"fr":"Repaire","es":""}}]"#.utf8))
        #expect(Donjons(api.map(Donjon.init), nomsBoss: [:]).donjon(zone: "Amakna (Village d'Amakna)") == nil)
    }

    @Test("Le détail : les boss d'abord, puis du plus fort au plus faible ; la clef nommée")
    func detail() throws {
        let json = """
        [{"id":3384,"name":{"fr":"Mansot"},"grades":[{"grade":1,"level":180,"lifePoints":3000,"actionPoints":8,"movementPoints":4}]},
         {"id":3416,"name":{"fr":"Comte Harebourg"},"grades":[{"grade":1,"level":200,"lifePoints":9000,"actionPoints":12,"movementPoints":6}]},
         {"id":9,"name":{"fr":"Sans grade"},"grades":[]}]
        """
        let monstres = try JSONDecoder().decode([FicheCombat.MonstreAPI].self, from: Data(json.utf8))
        let donjon = try #require(try Self.donjons().donjon(id: 71))
        let detail = DetailDonjon.assembler(donjon, monstres: monstres, objets: [14047: ["fr": "Clef du Donjon du Comte"]],
                                            succes: [])
        #expect(detail.monstres.map(\.id) == [3416, 3384])
        #expect(detail.monstres.first?.boss == true)
        #expect(detail.clefs.first?.noms["fr"] == "Clef du Donjon du Comte")
    }

    @Test("Palette : un donjon et son boss déplient la même fiche ; sans la liste, le donjon garde son trajet")
    func palette() throws {
        var contexte = ContextePalette()
        contexte.donjons = try Self.donjons()
        contexte.lieux = [Self.lieu("Donjon du Comte Harebourg", carte: 112460048)]
        #expect(RecherchePalette.lieux(contexte).first?.effet == .donjon(71))
        let boss = RecherchePalette.boss(contexte)
        #expect(boss.first { $0.titre == "Comte Harebourg" }?.effet == .donjon(71))
        #expect(RecherchePalette.entrees("kimbo", contexte).contains { $0.effet == .donjon(28) })
        contexte.donjons = nil
        #expect(RecherchePalette.lieux(contexte).first?.effet == .trajet(x: -67, y: -75, sousZone: 794))
    }

    private static func lieu(id: Int, _ nom: String, carte: Int, categorie: CategorieLieu = .donjon) -> Lieu {
        Lieu(id: id, x: id, y: -75, monde: 1, idCarte: carte, idSousZone: 794, categorie: categorie.rawValue,
             gfx: nil, noms: ["fr": nom], zone: [:], sousZone: [:])
    }

    private static func contexteDonjons() throws -> ContextePalette {
        var contexte = ContextePalette()
        contexte.donjons = try donjons()
        contexte.lieux = [lieu(id: 1, "Donjon du Comte Harebourg", carte: 112460048),
                          lieu(id: 2, "Canopée du Kimbo", carte: 5),
                          lieu(id: 3, "Atelier de Kimbo", carte: 6, categorie: .atelier)]
        return contexte
    }

    @Test("Le niveau du donjon est dans le sous-titre de sa ligne et de celle de son boss, après le lieu")
    func niveauDansLeSousTitre() throws {
        let contexte = try Self.contexteDonjons()
        let niveau = L("donjon.niveau", 200)
        let donjon = try #require(RecherchePalette.entrees("", contexte, filtre: .donjons).first { $0.effet == .donjon(71) })
        #expect(donjon.sousTitre == niveau)
        let boss = try #require(RecherchePalette.entrees("harebourg", contexte, filtre: .donjons).first { $0.id == "boss:3416" })
        #expect(boss.sousTitre == "\(L("palette.boss", "Donjon du Comte Harebourg")) · \(niveau)")
        // Sans niveau connu, le sous-titre ne bouge pas.
        #expect(RecherchePalette.avecNiveau("Boss · Kimbo", nil) == "Boss · Kimbo")
        #expect(RecherchePalette.avecNiveau("", try #require(try Self.donjons().donjon(id: 71))) == niveau)
    }

    @Test("Vue Donjons au repos : les donjons de la carte seuls ; en recherche, leurs boss, sur la ligne du donjon — et plus parmi les créatures")
    func vuesDonjons() throws {
        let contexte = try Self.contexteDonjons()
        let repos = RecherchePalette.entrees("", contexte, filtre: .donjons).map(\.titre)
        #expect(Set(repos) == ["Donjon du Comte Harebourg", "Canopée du Kimbo"])
        let recherche = RecherchePalette.entrees("kimbo", contexte, filtre: .donjons)
        #expect(recherche.map(\.titre) == ["Kimbo"])
        #expect(recherche.allSatisfy { $0.effet == .donjon(28) })
        #expect(!RecherchePalette.entrees("kimbo", contexte, filtre: .creatures).contains { $0.titre == "Kimbo" })
    }

    @Test("Sans la liste des donjons, la vue Donjons montre quand même les repères de la carte")
    func donjonsSansListe() throws {
        var contexte = try Self.contexteDonjons()
        contexte.donjons = nil
        #expect(RecherchePalette.entrees("", contexte, filtre: .donjons).count == 2)
    }

    @Test("Un donjon en cartes : ↵ déplie sa fiche sous une ligne, ← remet les cartes")
    @MainActor
    func ficheDepuisLesCartes() throws {
        let modele = PaletteModele(contexte: try Self.contexteDonjons(), filtre: .donjons)
        #expect(modele.enGrille && modele.enCartes)
        let entree = try #require(modele.entrees.first { $0.effet == .donjon(71) })
        modele.executer(entree)
        #expect(modele.deplie == entree.id && !modele.enGrille)
        #expect(modele.lateral(-1))
        #expect(modele.deplie == nil && modele.enGrille)
        // Échap replie la fiche avant de quitter la vue.
        modele.executer(entree)
        modele.echap()
        #expect(modele.deplie == nil && modele.filtre == .donjons)
        modele.echap()
        #expect(modele.filtre == .tout)
    }

    @Test("Fiche : position, aide au combat de chaque boss et guide en actions ; boss, conseils, monstres, succès et chaque clef en onglets")
    func onglets() throws {
        let donjon = try #require(try Self.donjons().donjon(id: 71))
        let entree = Self.lieu("Donjon du Comte Harebourg", carte: 112460048)
        // L'aide n'attend pas le détail ; un boss à mécanique y retrouve la sienne.
        let aides = donjon.boss.map { CibleBoss.boss($0, donjon: donjon.id) }
        #expect(aides == [.special(.harebourg)])
        let attente = OngletsFiche.donjon(entree: entree, boss: aides, guide: donjon.nomFrancais, conseils: false, detail: nil)
        #expect(attente.actions == [.entree(entree), .aide(.special(.harebourg)), .guide("Donjon du Comte Harebourg")])
        // Le détail attendu : l'onglet des boss dit l'attente.
        #expect(attente.onglets == [.boss])
        #expect(attente.principale == .entree(entree))

        let boss = DetailDonjon.Monstre(id: 3416, noms: [:], boss: true, fiche: Self.fiche)
        let mansot = DetailDonjon.Monstre(id: 3384, noms: [:], boss: false, fiche: Self.fiche)
        let detail = DetailDonjon(monstres: [boss, mansot], clefs: [.init(objet: 14047, noms: [:], quantite: 1), .init(objet: 2, noms: [:], quantite: 1)],
                                  succes: [.init(noms: [:], description: [:])])
        let complete = OngletsFiche.donjon(entree: nil, boss: [], guide: "Guide", conseils: true, detail: detail)
        #expect(complete.onglets == [.boss, .conseils, .monstres, .succes, .clef(objet: 14047), .clef(objet: 2)])
        // Sans entrée connue, ↵ replie.
        #expect(complete.principale == nil)
        // Un segment n'existe que s'il a du contenu.
        let seulsMonstres = DetailDonjon(monstres: [mansot], clefs: [], succes: [])
        #expect(OngletsFiche.donjon(entree: nil, boss: [], guide: nil, conseils: false, detail: seulsMonstres).onglets == [.monstres])
    }

    @Test("Onglets au clavier : ←/→ bornés à droite, ← sur le premier replie ; le modèle tient un onglet, pas un rang")
    func navigation() {
        let avant = OngletsFiche(actions: [], onglets: [.boss, .monstres, .succes])
        #expect(avant.courant(nil) == .boss)
        #expect(avant.lateral(depuis: nil, 1) == .onglet(.monstres))
        #expect(avant.lateral(depuis: .succes, 1) == .onglet(.succes))
        #expect(avant.lateral(depuis: .succes, -1) == .onglet(.monstres))
        #expect(avant.lateral(depuis: .boss, -1) == .replier)
        // Les conseils arrivent : l'onglet voulu reste les monstres ; disparu, on retombe sur le premier.
        let apres = OngletsFiche(actions: [], onglets: [.boss, .conseils, .monstres, .succes])
        #expect(apres.courant(.monstres) == .monstres)
        #expect(apres.courant(.clef(objet: 1)) == .boss)
        #expect(OngletsFiche.vide.lateral(depuis: nil, 1) == nil)
        #expect(OngletsFiche.vide.lateral(depuis: nil, -1) == .replier)
    }

    @Test("Conseils de Dofus pour les noobs : une phrase par puce de la section, son paragraphe, entités décodées")
    func conseils() {
        let html = """
        <span class="ancres-dpln" id="principe-combat"></span><ul><li>Pas un conseil</li></ul>Non.</div>
        <span class="ancres-dpln" id="conseils-tactiques"></span>
        <h4>Conseils tactiques pour ce combat</h4></div>
        <div class="paragraph">Les conseils list&eacute;s ci-dessous sont ind&eacute;pendants.<br></div>
        <div class="paragraph"><ul><li><strong><font color="#3f3f3f">Essayez d&rsquo;&ecirc;tre &agrave; plus de 8PO.</font></strong><br></li></ul>Les Coquilles infligent&#8203; des d&eacute;g&acirc;ts&nbsp;!</div>
        <div class="paragraph"><ul><li><strong>Occupez-vous de la Crocabulia en dernier.</strong></li></ul></div>
        <span class="ancres-dpln" id="strategie-globale"></span><ul><li>Hors section</li></ul>Non.</div>
        """
        #expect(ConseilCombat.extraire(html) == [
            ConseilCombat(titre: "Essayez d’être à plus de 8PO.", detail: "Les Coquilles infligent des dégâts !"),
            ConseilCombat(titre: "Occupez-vous de la Crocabulia en dernier.", detail: ""),
        ])
        #expect(ConseilCombat.extraire("<html>sans section</html>").isEmpty)
        // Une page ancienne : la stratégie, faute de conseils.
        let ancienne = """
        <span class="ancres-dpln" id="strategie-globale"></span>
        <div class="paragraph">Intro.<ul><li> Bouger le Disciple : </ul>Il gagne 1PM.<ul><li>Ne pas le bouger :</ul>Plus simple.</div>
        """
        #expect(ConseilCombat.extraire(ancienne) == [ConseilCombat(titre: "Bouger le Disciple", detail: "Il gagne 1PM."),
                                                      ConseilCombat(titre: "Ne pas le bouger", detail: "Plus simple.")])
        #expect(ConseilCombat.texte("&Eacute;t&eacute; &oelig;uf &#233;&#xE9; &inconnu;") == "Été œuf éé &inconnu;")
    }

    @Test("Toutes les sections de la page sont lues — tactique, stratégie, principe — pas seulement la première")
    func conseilsToutesSections() {
        let html = """
        <span class="ancres-dpln" id="conseils-tactiques"></span>
        <div class="paragraph"><ul><li>Conseil tactique.</li></ul></div>
        <span class="ancres-dpln" id="strategie-globale"></span>
        <div class="paragraph"><ul><li>Stratégie globale.</li></ul>Détail.</div>
        <span class="ancres-dpln" id="principe-combat"></span>
        <div class="paragraph"><ul><li>Principe du combat.</li></ul></div>
        """
        #expect(ConseilCombat.extraire(html) == [
            ConseilCombat(titre: "Conseil tactique.", detail: ""),
            ConseilCombat(titre: "Stratégie globale.", detail: "Détail."),
            ConseilCombat(titre: "Principe du combat.", detail: ""),
        ])
    }

    @Test("Éléments : frapper où il résiste le moins, éviter où il résiste le plus ; rien quand tout se vaut")
    func elements() throws {
        func fiche(_ neutre: Int, _ terre: Int, _ feu: Int, _ eau: Int, _ air: Int) throws -> FicheCombat {
            try #require(FicheCombat(FicheCombat.MonstreAPI(id: 1, name: nil, grades: [.init(
                grade: 1, level: 1, lifePoints: 1, actionPoints: 1, movementPoints: 1, reductionNeutral: neutre,
                reductionEarth: terre, reductionFire: feu, reductionWater: eau, reductionAir: air)])))
        }
        // Crocabulia.
        let croca = try fiche(13, 15, 21, 18, 9).elements
        #expect(croca.frapper == [.neutre, .air] && croca.eviter == [.feu, .eau])
        // Kimbo : 400 % partout.
        #expect(try fiche(400, 400, 400, 400, 400).elements.frapper.isEmpty)
        // Écart tout juste utile : un élément au milieu ne compte que pour frapper.
        let juste = try fiche(0, 5, 10, 10, 10).elements
        #expect(juste.frapper == [.neutre, .terre] && juste.eviter == [.feu, .eau, .air])
    }

    private static let fiche = FicheCombat(FicheCombat.MonstreAPI(
        id: 1, name: nil, grades: [.init(grade: 1, level: 1, lifePoints: 1, actionPoints: 1, movementPoints: 1,
                                         reductionNeutral: nil, reductionEarth: nil, reductionFire: nil,
                                         reductionWater: nil, reductionAir: nil)]))!
}

/// Les renvois `[challenge,N]` des descriptions de succès.
struct DescriptionSuccesTests {
    @Test("Un renvoi devient le nom du challenge, dans la langue du texte ; inconnu, il s'efface")
    func renvois() {
        let description = ["fr": "Vaincre le roi Nidas en validant le challenge [challenge,307].",
                           "en": "Defeat King Nidas with the [challenge,307] challenge."]
        #expect(DetailDonjon.Succes.challenges(dans: description) == [307])
        let noms = [307: ["fr": "Statue", "en": "Statue"]]
        let lue = DetailDonjon.Succes.resoudre(description, challenges: noms)
        #expect(lue["fr"] == "Vaincre le roi Nidas en validant le challenge « Statue ».")
        let muette = DetailDonjon.Succes.resoudre(description, challenges: [:])
        #expect(muette["fr"] == "Vaincre le roi Nidas en validant le challenge.")
    }
}
