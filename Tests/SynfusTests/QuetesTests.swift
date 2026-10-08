import Foundation
import Testing
@testable import Synfus

/// Les quêtes : assemblées depuis DofusDB, leurs ressources, et la palette.
struct QuetesTests {

    /// Wogew l'hewmite, raccourcie : deux étapes, deux objets à ramener, une
    /// récompense ; et la quête qui la suit.
    static let page = """
    {"total":2,"data":[{"id":18,"name":{"fr":"Wogew l'hewmite","en":"Wogew the Hewmit"},"levelMin":70,"isPartyQuest":true,
      "startCriterion":"PL>59&PG=13&PJ>26,79&Ps=1&Pa>19&(Qf=1|Qa=2)",
      "stepIds":[57,55],"startPosition":[{"mapId":160695296,"npcId":196}],"need":{"quests":[]},
      "steps":[
        {"id":55,"name":{"fr":"Le sang du wabbit GM"},"optimalLevel":70,"duration":1,
         "description":{"id":"94441","fr":"Wogew a besoin du sang d'un {monster,182}."},
         "rewards":[{"levelMin":-1,"levelMax":-1,"experienceRatio":1,"kamasRatio":1,
                     "itemsReward":[[1747,1]],"emotesReward":[11],"titlesReward":[]}],
         "objectives":[
          {"id":101,"className":"QuestObjectiveFightMonsterData","text":{"fr":"Vaincre x1 {monster,182} en un seul combat"},
           "coords":{"x":25,"y":-8},"mapId":0,"parameters":{"parameter0":182,"parameter1":1}},
          {"id":102,"className":"QuestObjectiveBringItemToNpcData","text":{"fr":"Ramener à {npc,119} : x3 {item,1746}"},
           "mapId":185862149,"map":{"posX":-2,"posY":-4,"subAreaId":10},
           "parameters":{"parameter0":119,"parameter1":1746,"parameter2":3}}]},
        {"id":57,"name":{"fr":"Analyse de sang"},"rewards":[],"objectives":[
          {"id":103,"className":"QuestObjectiveBringItemToNpcData","text":{"fr":"Ramener à {npc,196} : x2 {item,1746}"},
           "mapId":149769,"parameters":{"parameter0":196,"parameter1":1746,"parameter2":2}},
          {"id":104,"className":"QuestObjectiveDiscoverMapData","text":{"fr":"Découvrir la carte : {map,99}"}}]}]},
     {"id":19,"name":{"fr":"La suite"},"levelMin":80,"need":{"quests":[18]},"steps":[]}]}
    """

    static func quetes() throws -> Quetes {
        let api = try JSONDecoder().decode(DofusDB.Page<QuetesDofusDB.QueteAPI>.self, from: Data(page.utf8)).data
        func nomme(_ id: Int, _ nom: String, type: Int? = nil) throws -> QuetesDofusDB.Nomme {
            var nomme = try JSONDecoder().decode(QuetesDofusDB.Nomme.self,
                                                 from: Data(#"{"id":\#(id),"name":{"fr":"\#(nom)"}}"#.utf8))
            nomme.typeId = type
            return nomme
        }
        let type = try JSONDecoder().decode(QuetesDofusDB.TypeObjetAPI.self,
                                            from: Data(#"{"id":137,"superType":{"id":14,"name":{"fr":"Objet de quête"}}}"#.utf8))
        let carte = try JSONDecoder().decode(QuetesDofusDB.CarteAPI.self,
                                             from: Data(#"{"id":160695296,"posX":-1,"posY":-39,"subAreaId":56}"#.utf8))
        let sousZone = try JSONDecoder().decode(QuetesDofusDB.SousZoneAPI.self,
                                                from: Data(#"{"id":10,"areaId":0,"name":{"fr":"Village d'Amakna"}}"#.utf8))
        let cites = QuetesDofusDB.Cites(
            objets: [try nomme(1746, "Sang de Wabbit GM", type: 137), try nomme(1747, "Analyse de sang")],
            monstres: [try nomme(182, "Wabbit GM")],
            pnjs: [try nomme(119, "Otomaï"), try nomme(196, "Wogew")], cartes: [carte],
            sousZones: [sousZone], zones: [try nomme(0, "Amakna")], types: [type], emotes: [try nomme(11, "Pierre")],
            metiers: [try nomme(26, "Alchimiste")], camps: [try nomme(1, "Bontarien")])
        return QuetesDofusDB.assembler(quetes: api, cites: cites, date: .now)
    }

    @Test("Les étapes suivent stepIds, les renvois se résolvent, un renvoi inconnu reste lisible")
    func assemblage() throws {
        let quetes = try Self.quetes()
        let quete = try #require(quetes.quetes.first)
        #expect(quete.etapes.map { $0.noms["fr"] } == ["Analyse de sang", "Le sang du wabbit GM"])
        #expect(quetes.texte("Ramener à {npc,119} : x3 {item,1746}", en: .fr) == "Ramener à Otomaï : x3 Sang de Wabbit GM")
        #expect(quetes.texte("Découvrir la carte : {map,99}", en: .fr) == "Découvrir la carte : [map]")
        let renvois = QuetesDofusDB.renvois(
            try JSONDecoder().decode(DofusDB.Page<QuetesDofusDB.QueteAPI>.self, from: Data(Self.page.utf8))
                .data.flatMap { ($0.steps ?? []).flatMap { $0.objectives ?? [] } })
        #expect(renvois.objets == [1746] && renvois.monstres == [182] && renvois.pnjs == [119, 196])
    }

    @Test("Les ressources de la quête s'additionnent d'une étape à l'autre")
    func ressources() throws {
        let quete = try #require(try Self.quetes().quetes.first)
        #expect(Quetes.ressources(quete).map { [$0.objet, $0.quantite] } == [[1746, 5]])
    }

    @Test("Les passages d'un PNJ : le plus cité d'abord, avec sa sous-zone nommée")
    func passages() throws {
        // Une quête place Wogew en 5,5 ; deux autres en -2,-4.
        func quete(_ id: Int, _ x: Int, _ y: Int) -> String {
            #"{"id":\#(id),"name":{"fr":"Q\#(id)"},"steps":[{"id":\#(id),"name":{"fr":"E"},"objectives":[{"#
                + #""id":\#(id),"className":"QuestObjectiveGoToNpcData","text":{"fr":"Aller voir {npc,196}"},"#
                + #""map":{"posX":\#(x),"posY":\#(y),"subAreaId":10},"parameters":{"parameter0":196}}]}]}"#
        }
        let page = #"{"total":3,"data":["# + [quete(1, 5, 5), quete(2, -2, -4), quete(3, -2, -4)].joined(separator: ",") + "]}"
        let api = try JSONDecoder().decode(DofusDB.Page<QuetesDofusDB.QueteAPI>.self, from: Data(page.utf8)).data
        let wogew = try JSONDecoder().decode(QuetesDofusDB.Nomme.self, from: Data(#"{"id":196,"name":{"fr":"Wogew"}}"#.utf8))
        let quetes = QuetesDofusDB.assembler(quetes: api, cites: QuetesDofusDB.Cites(pnjs: [wogew]), date: .now)
        #expect(quetes.pnjs.first?.passages.map(\.quetes) == [2, 1])
        #expect(quetes.pnjs.first?.passages.first?.position == PNJ.Position(x: -2, y: -4))
        #expect(try Self.quetes().sousZones["10"]
                == SousZoneNommee(noms: ["fr": "Village d'Amakna"], zone: ["fr": "Amakna"]))
    }

    @Test("Un PNJ est situé par le départ de la quête et par les objectifs qui mènent à lui, avec leur carte")
    func pnjs() throws {
        let pnjs = try Self.quetes().pnjs
        // L'objectif 103 mène aussi à Wogew, mais sans case : il ne le situe pas.
        #expect(pnjs.first { $0.id == 196 }?.passages == [PNJ.Passage(position: PNJ.Position(x: -1, y: -39),
                                                                      carte: 160695296, sousZone: 56, quetes: 1)])
        #expect(pnjs.first { $0.id == 119 }?.passages == [PNJ.Passage(position: PNJ.Position(x: -2, y: -4),
                                                                      carte: 185862149, sousZone: 10, quetes: 1)])
    }

    private func contexte() throws -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna")
        contexte.zaaps = CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:])
        contexte.quetes = try Self.quetes()
        return contexte
    }

    @Test("/quete trouve la quête, qui s'ouvre dans son panneau")
    func palette() throws {
        let quete = try #require(RecherchePalette.entrees("/quete wogew", try contexte()).first)
        #expect(quete.effet == .ouvrirQuete(18))
    }

    @Test("/pnj trouve le PNJ là où il se tient, avec la carte dont la liste montre la vue")
    func palettePNJ() throws {
        let otomai = try #require(RecherchePalette.entrees("/pnj otomai", try contexte()).first)
        #expect(otomai.effet == .trajet(x: -2, y: -4))
        #expect(otomai.carte == 185862149)
    }

    @Test("La fiche : ressources additionnées, objectifs résolus, carte quand elle est connue")
    func fiche() throws {
        let fiche = try #require(try Self.quetes().fiche(18, en: .fr))
        #expect(fiche.ressources == [FicheQuete.Ressource(nom: "Sang de Wabbit GM", quantite: 5, categorie: "Objet de quête",
                                                     objetDeQuete: true)])
        #expect(fiche.groupe && !fiche.donjon)
        #expect(fiche.exigences == [.classe(13), .niveau(60), .metier("Alchimiste", niveau: 80),
                                    .alignement(camp: "Bontarien", niveau: 20)])
        #expect(fiche.etapes.map(\.nom) == ["Analyse de sang", "Le sang du wabbit GM"])
        let otomai = try #require(fiche.etapes[1].objectifs.first { $0.texte.contains("Otomaï") })
        #expect(otomai.position == PNJ.Position(x: -2, y: -4))
        #expect(fiche.etapes[0].objectifs[1].position == nil)
        #expect(fiche.nomFrancais == "Wogew l'hewmite")
    }

    @Test("Les exigences en une ligne, la classe nommée par le catalogue des classes")
    @MainActor
    func exigences() throws {
        let fiche = try #require(try Self.quetes().fiche(18, en: .fr))
        let roublard = try #require(DofusClass.Catalogue.integre.breed(idDofusDB: 13)).nomLocalise
        #expect(QueteVue.exigences(fiche.exigences, classes: .integre) == [
            roublard, L("quete.exigence.niveau", 60), L("quete.exigence.metier", "Alchimiste", 80),
            L("quete.exigence.alignement", "Bontarien", 20),
        ].joined(separator: " · "))
        #expect(QueteVue.exigences([.alignement(camp: nil, niveau: nil)], classes: .integre) == nil)
    }

    @Test("La fiche d'une étape : sa consigne résolue, la vue de ses cartes connues, ses récompenses")
    func ficheEtape() throws {
        let fiche = try #require(try Self.quetes().fiche(18, en: .en))
        let sang = fiche.etapes[1]
        #expect(sang.description == "Wogew a besoin du sang d'un Wabbit GM.")
        #expect(sang.objectifs.map(\.id) == [101, 102])
        #expect(sang.objectifs.map(\.carte) == [nil, 185862149])
        // Une carte que DofusDB ne décrit pas (sans `map`) n'a pas de vue.
        #expect(fiche.etapes[0].objectifs.map(\.carte) == [nil, nil])
        #expect(fiche.etapes[0].description == nil)
        #expect(sang.recompenses == FicheQuete.Recompenses(
            niveau: 70, experience: 201_600, kamas: 6_280,
            objets: [FicheQuete.Ressource(nom: "Analyse de sang", quantite: 1, categorie: nil, objetDeQuete: false)],
            emotes: ["Pierre"], titres: []))
        #expect(fiche.etapes[0].recompenses.vides)
    }

    @Test("Expérience et kamas d'une étape, au niveau optimal ; une étape répétable prend la tranche de ce niveau")
    func recompenses() throws {
        #expect(RecompensesEtape.experience(niveau: 177, duree: 2, ratio: 1.2) == 4_377_903)
        #expect(RecompensesEtape.kamas(niveau: 1, duree: 1, ratio: 1) == 1)
        #expect(RecompensesEtape.kamas(niveau: 0, duree: 1, ratio: 1) == 0)
        let etape = try JSONDecoder().decode(QuetesDofusDB.EtapeAPI.self, from: Data("""
        {"id":1,"name":{"fr":"E"},"optimalLevel":21,"duration":1,"rewards":[
          {"levelMin":20,"levelMax":20,"kamasRatio":1},{"levelMin":21,"levelMax":21,"kamasRatio":3}]}
        """.utf8))
        #expect(etape.recompenses.kamas == RecompensesEtape.kamas(niveau: 21, duree: 1, ratio: 3))
    }

    @Test("Les quêtes suivantes : celles qui demandent la quête finie")
    func suivantes() throws {
        let quetes = try Self.quetes()
        #expect(quetes.fiche(18, en: .fr)?.suivantes == [FicheQuete.Suivante(id: 19, nom: "La suite", niveau: 80)])
        #expect(quetes.fiche(19, en: .fr)?.suivantes == [])
    }

    @Test("Un fichier de quêtes d'une autre forme n'est pas relu : il se retélécharge")
    func ancienFormat() throws {
        let donnees = try JSONEncoder().encode(try Self.quetes())
        #expect(QuetesDofusDB.relire(donnees) != nil)
        var objet = try #require(try JSONSerialization.jsonObject(with: donnees) as? [String: Any])
        objet["format"] = Quetes.formatActuel - 1
        #expect(QuetesDofusDB.relire(try JSONSerialization.data(withJSONObject: objet)) == nil)
        objet["format"] = nil
        #expect(QuetesDofusDB.relire(try JSONSerialization.data(withJSONObject: objet)) == nil)
    }

    @Test("Dofus pour les noobs : lettres nues d'abord, puis les entités HTML de Weebly")
    func dofusPourLesNoobs() {
        #expect(DofusPourLesNoobs.candidats("La voie du guerrier") == ["la-voie-du-guerrier"])
        #expect(DofusPourLesNoobs.candidats("Naissance d'une vocation") == ["naissance-dune-vocation"])
        #expect(DofusPourLesNoobs.candidats("Pense-bête") == ["pense-bete", "pense-becircte"])
        #expect(DofusPourLesNoobs.candidats("L'éternelle moisson").contains("leacuteternelle-moisson"))
        #expect(DofusPourLesNoobs.candidats("Esprit, es-tu là ?").first == "esprit-es-tu-la")
        #expect(DofusPourLesNoobs.candidats("Les gardes d'honneur... à punir")
                == ["les-gardes-dhonneur-a-punir", "les-gardes-dhonneur-agrave-punir"])
        #expect(DofusPourLesNoobs.candidats("Ingérence en Amakna à Bonta").count == 4)
        #expect(DofusPourLesNoobs.page("pense-bete").absoluteString == "https://www.dofuspourlesnoobs.com/pense-bete.html")
    }

    @Test("/pnj et le filtre PNJ : le trajet vers sa position")
    func paletteePNJ() throws {
        let contexte = try contexte()
        #expect(RecherchePalette.entrees("/pnj wogew", contexte).first?.detail == "[-1,-39]")
        #expect(RecherchePalette.entrees("/pnj otomai", contexte).first?.sousTitre?.hasPrefix("Village d'Amakna · Amakna") == true)
        #expect(RecherchePalette.entrees("", contexte, filtre: .pnj).allSatisfy { $0.genre == .pnj })
        #expect(RecherchePalette.entrees("wogew", contexte, filtre: .quetes).map(\.genre) == [.quete])
    }
}
