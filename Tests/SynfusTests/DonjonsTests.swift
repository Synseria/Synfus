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

    @Test("Fiche au clavier : position en tête, guide, conseils, dépliables, la clef pour finir")
    func cartes() throws {
        let donjon = try #require(try Self.donjons().donjon(id: 71))
        let entree = Self.lieu("Donjon du Comte Harebourg", carte: 112460048)
        let attente = CartesFiche.donjon(entree: entree, guide: donjon.nomFrancais, detail: nil, conseils: false)
        #expect(attente.actions == [.entree(entree), .guide("Donjon du Comte Harebourg")])
        #expect(attente.premiere == .entree(entree))

        let boss = DetailDonjon.Monstre(id: 3416, noms: [:], boss: true, fiche: Self.fiche)
        let mansot = DetailDonjon.Monstre(id: 3384, noms: [:], boss: false, fiche: Self.fiche)
        let detail = DetailDonjon(monstres: [boss, mansot], clefs: [.init(objet: 14047, noms: [:], quantite: 1)],
                                  succes: [.init(noms: [:], description: [:])])
        let cartes = CartesFiche.donjon(entree: entree, guide: "Guide", detail: detail, conseils: true)
        #expect(cartes.actions == [.entree(entree), .guide("Guide"), .conseils, .monstres, .succes, .clef(objet: 14047)])
        // Seuls des boss : rien à déplier pour les monstres.
        #expect(CartesFiche.donjon(entree: nil, guide: nil, detail: DetailDonjon(monstres: [boss], clefs: [], succes: []),
                                   conseils: false) == .vide)
    }

    @Test("Fiche au clavier : ←/→ restent dans la rangée ; le clavier tient une carte, pas un rang")
    func navigation() {
        let avant = CartesFiche(actions: [.guide("a"), .monstres, .succes])
        #expect(avant.laterale(.succes, 1) == .succes)
        #expect(avant.laterale(.succes, -1) == .monstres)
        #expect(avant.laterale(.guide("a"), -1) == .guide("a"))
        // Les conseils arrivent : le clavier reste sur les monstres.
        let apres = CartesFiche(actions: [.guide("a"), .conseils, .monstres, .succes])
        #expect(apres.valide(.monstres) == .monstres)
        #expect(apres.valide(.clef(objet: 1)) == nil)
        #expect(CartesFiche.vide.premiere == nil)
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
