import Foundation
import Testing
@testable import Synfus

/// La carte : assemblée depuis DofusDB, les zaaps et les sous-zones en sont tirés.
struct CarteTests {

    @Test("Chaque repère reçoit sa sous-zone et sa zone ; un repère orphelin garde des noms vides")
    func assemblage() throws {
        let reperes = """
        {"total":3,"data":[
          {"id":1,"x":-2,"y":0,"mapId":11,"worldMapId":1,"categoryId":9,"subareaId":10,"name":{"fr":"Zaap","en":"Zaap"}},
          {"id":2,"x":-2,"y":1,"mapId":12,"worldMapId":1,"categoryId":4,"subareaId":10,"name":{"fr":"Banque","en":"Bank"}},
          {"id":3,"x":9,"y":9,"mapId":13,"worldMapId":1,"categoryId":4,"subareaId":999,"name":{"fr":"Milice"}}]}
        """
        let sousZones = """
        {"total":1,"data":[{"id":10,"areaId":0,"name":{"id":"1","fr":"Village d'Amakna","en":"Amakna Village"}}]}
        """
        let zones = """
        {"total":1,"data":[{"id":0,"name":{"fr":"Amakna","en":"Amakna"}}]}
        """
        let decodeur = JSONDecoder()
        let carte = CarteDofusDB.assembler(
            date: .now,
            reperes: try decodeur.decode(DofusDB.Page<CarteDofusDB.Repere>.self, from: Data(reperes.utf8)).data,
            sousZones: try decodeur.decode(DofusDB.Page<CarteDofusDB.SousZone>.self, from: Data(sousZones.utf8)).data,
            zones: try decodeur.decode(DofusDB.Page<CarteDofusDB.Zone>.self, from: Data(zones.utf8)).data,
            cases: [])
        let lieux = carte.lieux
        #expect(lieux.map(\.id) == [1, 2, 3])
        #expect(lieux[1].nom(en: .en) == "Bank")
        #expect(lieux[1].sousZone(en: .fr) == "Village d'Amakna")
        #expect(lieux[1].zone(en: .es) == "Amakna")
        #expect(lieux[2].zone.isEmpty && lieux[2].sousZone.isEmpty)

        #expect(carte.zaaps == [Zaap(-2, 0, noms: ["fr": "Village d'Amakna", "en": "Amakna Village"],
                                     zone: ["fr": "Amakna", "en": "Amakna"], idCarte: 11, idSousZone: 10)])
        // Les sous-zones des repères du Monde des Douze, même sans case.
        #expect(carte.sousZones.map(\.id) == [10, 999])
    }

    private func case_(_ id: Int, _ x: Int, _ y: Int, _ sousZone: Int, prioritaire: Bool? = nil) -> CarteDofusDB.Case {
        CarteDofusDB.Case(id: id, posX: x, posY: y, subAreaId: sousZone, hasPriorityOnWorldmap: prioritaire)
    }

    @Test("Une case partagée prend la sous-zone de ses cartes prioritaires, la plus fréquente, puis la plus petite carte")
    func sousZoneDUneCase() {
        let cases = [
            // Une prioritaire contre deux autres : la prioritaire.
            case_(5, 0, 0, 1, prioritaire: false), case_(6, 0, 0, 1, prioritaire: false), case_(7, 0, 0, 2, prioritaire: true),
            // Deux prioritaires contre une.
            case_(8, 1, 0, 3, prioritaire: true), case_(9, 1, 0, 4, prioritaire: true), case_(10, 1, 0, 3, prioritaire: true),
            // Aucune prioritaire, égalité : celle de la plus petite carte.
            case_(12, 2, 0, 6), case_(11, 2, 0, 5),
        ]
        #expect(CarteDofusDB.sousZoneParCase(cases) == ["0,0": 2, "1,0": 3, "2,0": 5])
    }

    @Test("Les voisines deviennent symétriques, bornées au Monde des Douze ; un zaap 0 n'en est pas un")
    func graphe() throws {
        let json = """
        [{"id":1,"areaId":0,"name":{},"associatedZaapMapId":0,"neighbors":[2,1,99]},
         {"id":2,"areaId":0,"name":{},"associatedZaapMapId":42,"neighbors":[]},
         {"id":3,"areaId":0,"name":{}}]
        """
        let sousZones = try JSONDecoder().decode([CarteDofusDB.SousZone].self, from: Data(json.utf8))
        #expect(CarteDofusDB.graphe([1, 2, 3], sousZones) == [
            SousZoneCarte(id: 1, zaap: nil, voisines: [2]),
            SousZoneCarte(id: 2, zaap: 42, voisines: [1]),
            SousZoneCarte(id: 3, zaap: nil, voisines: []),
        ])
    }

    @Test("Une carte gardée d'un ancien format cède la place à l'intégrée")
    func ancienCache() throws {
        let integree = Carte(date: Date(timeIntervalSinceReferenceDate: 1000), lieux: [], sousZones: [], cases: ["0,0": 1])
        let ancien = #"{"date":999999999,"lieux":[{"id":1,"x":0,"y":0,"monde":1,"categorie":4,"noms":{},"zone":{},"sousZone":{}}]}"#
        #expect(CarteDofusDB.retenue(gardee: Data(ancien.utf8), integree: integree) == integree)
        #expect(CarteDofusDB.retenue(gardee: Data("pas du JSON".utf8), integree: integree) == integree)
        #expect(CarteDofusDB.retenue(gardee: nil, integree: integree) == integree)

        let recente = Carte(date: Date(timeIntervalSinceReferenceDate: 2000), lieux: [], sousZones: [], cases: [:])
        #expect(CarteDofusDB.retenue(gardee: try JSONEncoder().encode(recente), integree: integree) == recente)
        let vieille = Carte(date: Date(timeIntervalSinceReferenceDate: 500), lieux: [], sousZones: [], cases: [:])
        #expect(CarteDofusDB.retenue(gardee: try JSONEncoder().encode(vieille), integree: integree) == integree)
    }

    @Test("La carte intégrée : tous les zaaps, une banque à Bonta")
    func integree() {
        let carte = Carte.integree
        #expect(carte.lieux.count >= Carte.minimumPlausible)
        #expect(carte.zaaps.count == 45)
        let cles = carte.zaaps.map(\.cle)
        #expect(Set(cles).count == cles.count)
        #expect(carte.lieux.contains { $0.nom(en: .fr) == "Banque" && $0.zone(en: .fr) == "Bonta" })
        #expect(carte.zaaps.contains { $0.nom(en: .fr) == "Cœur immaculé" && $0.zone(en: .fr) == "Bonta" })
        // Le Monde des Douze, case par case ; chaque zaap y a sa sous-zone.
        #expect(carte.cases.count >= Carte.minimumCasesPlausible)
        let reseau = ReseauSousZones(carte)
        #expect(reseau.sousZone(-20, 9) == 235)
        let sousZones = Set(carte.sousZones.map(\.id))
        #expect(carte.zaaps.filter { $0.monde == Zaap.mondeDesDouze }.allSatisfy { sousZones.contains($0.idSousZone ?? -1) })
    }

    @Test("Un zaap ajouté avant la zone se relit, sans zone")
    func zaapSansZone() throws {
        let ancien = #"{"x":50,"y":-50,"monde":1,"noms":{"fr":"Mon zaap"}}"#
        let zaap = try JSONDecoder().decode(Zaap.self, from: Data(ancien.utf8))
        #expect(zaap == Zaap(50, -50, noms: ["fr": "Mon zaap"]))
    }
}
