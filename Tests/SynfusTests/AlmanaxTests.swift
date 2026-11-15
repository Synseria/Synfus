import Foundation
import Testing
@testable import Synfus

/// L'almanax du jour, d'après la réponse de DofusDB (raccourcie).
struct AlmanaxTests {
    static let reponse = """
    {"id":24,"name":{"fr":"Challenge supplémentaire","en":"Extra challenge","de":"Zusatzchallenge"},
     "desc":{"fr":"Un challenge supplémentaire est généré contre les créatures de type <b>{{monsterRace,229::Firefoux}}</b>.",
             "en":"An extra challenge is generated against creatures in the <b>{{monsterRace,229::Firefoux}}</b> family."},
     "itemIds":[7294],"quantities":[4],
     "items":[{"id":7294,"iconId":54204,"level":140,"name":{"fr":"Poils de Pétartifoux","en":"Bangartifoux Hairs"}}]}
    """

    @Test("La réponse de DofusDB : l'offrande et sa quantité, le bonus sans mise en forme")
    func lecture() throws {
        let api = try JSONDecoder().decode(Almanax.API.self, from: Data(Self.reponse.utf8))
        let almanax = Almanax(api, jour: "2026-10-09")
        #expect(almanax.offrandes == [.init(objet: 7294, noms: ["fr": "Poils de Pétartifoux", "en": "Bangartifoux Hairs"],
                                            quantite: 4, icone: 54204)])
        #expect(almanax.bonus["fr"] == "Challenge supplémentaire")
        #expect(almanax.description["fr"] == "Un challenge supplémentaire est généré contre les créatures de type Firefoux.")
        // Un objet que la réponse ne joint pas garde son identifiant.
        let nu = try JSONDecoder().decode(Almanax.API.self, from: Data(#"{"itemIds":[1],"quantities":[2]}"#.utf8))
        #expect(Almanax(nu, jour: "2026-10-09").offrandes.first?.noms == ["fr": "#1"])
    }

    @Test("Les renvois gardent leur libellé, les balises tombent")
    func nettoyage() {
        #expect(Almanax.nettoyer("<b>{{monsterRace,229::Firefoux}}</b> et {{item,1}} <i>x</i> ") == "Firefoux et x")
    }

    @Test("Le jour du jeu est celui de Paris")
    func jour() throws {
        let iso = ISO8601DateFormatter()
        #expect(Almanax.jour(de: try #require(iso.date(from: "2026-10-08T21:59:00Z"))) == "2026-10-08")
        #expect(Almanax.jour(de: try #require(iso.date(from: "2026-10-08T22:01:00Z"))) == "2026-10-09")
        #expect(Almanax.jour(de: try #require(iso.date(from: "2026-12-31T23:30:00Z"))) == "2027-01-01")
    }

    private func almanax(_ jour: String) throws -> Almanax {
        Almanax(try JSONDecoder().decode(Almanax.API.self, from: Data(Self.reponse.utf8)), jour: jour)
    }

    @Test("Les jours gardés se relisent ; ceux d'une autre forme, ou un fichier d'avant, non")
    func disque() throws {
        let jours = [try almanax("2026-10-09"), try almanax("2026-10-10")]
        #expect(Almanax.relire(try JSONEncoder().encode(jours)) == jours)
        var ancien = jours[1]
        ancien.format = 0
        #expect(Almanax.relire(try JSONEncoder().encode([jours[0], ancien])) == [jours[0]])
        // Le fichier d'avant portait un seul jour, sans tableau.
        #expect(Almanax.relire(try JSONEncoder().encode(jours[0])).isEmpty)
        #expect(Almanax.relire(nil).isEmpty)
    }

    @Test("La semaine : aujourd'hui et six jours, au calendrier de Paris, mois et année compris")
    func semaine() throws {
        let iso = ISO8601DateFormatter()
        let semaine = Almanax.semaine(depuis: try #require(iso.date(from: "2026-12-28T23:30:00Z")))
        #expect(semaine == ["2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03", "2027-01-04"])
        #expect(semaine.count == Almanax.joursMontres)
    }

    @Test("Ce qui se redemande : le jour qui manque ou qui a échoué, pas ceux déjà lus")
    func manquants() {
        let semaine = ["2026-11-15", "2026-11-16", "2026-11-17"]
        #expect(Almanax.manquants(semaine, connus: []) == semaine)
        #expect(Almanax.manquants(semaine, connus: ["2026-11-15", "2026-11-17", "2026-11-01"]) == ["2026-11-16"])
        #expect(Almanax.manquants(semaine, connus: Set(semaine)).isEmpty)
    }

    @MainActor
    @Test("Un jour se lit « lun. 16 nov. » : midi de Paris, jamais la veille")
    func libelle() throws {
        #expect(Almanax.libelle(du: "2026-11-16", .fr) == "lun. 16 nov.")
        #expect(Almanax.libelle(du: "2026-11-16", .fr) == "lun. 16 nov.")
        #expect(Almanax.libelle(du: "2026-11-16", .en).contains("Mon"))
        #expect(Almanax.libelle(du: "n'importe quoi", .fr) == "n'importe quoi")
        #expect(Almanax.jour(de: try #require(Almanax.date(de: "2026-11-16"))) == "2026-11-16")
        #expect(try almanax("2026-11-16").nomOffrande(.fr) == "Poils de Pétartifoux")
    }

    @Test("Les flèches : la carte du jour seule, puis deux lignes de trois ; un bord n'emmène nulle part")
    func navigation() {
        func cible(_ index: Int, _ colonne: Int, _ ligne: Int) -> Int {
            NavigationAlmanax.cible(depuis: index, colonne: colonne, ligne: ligne)
        }
        #expect(cible(0, 1, 0) == 0 && cible(0, 0, -1) == 0)
        #expect(cible(0, 0, 1) == 1)
        #expect(cible(1, 0, -1) == 0 && cible(3, 0, -1) == 0)
        #expect(cible(2, 0, 1) == 5 && cible(5, 0, -1) == 2)
        #expect(cible(6, 0, 1) == 6)
        #expect(cible(1, 1, 0) == 2 && cible(3, 1, 0) == 3 && cible(4, -1, 0) == 4)
        #expect(NavigationAlmanax.ligne(de: 5) == 4...6 && NavigationAlmanax.ligne(de: 0) == 0...0)
    }

    @Test("Le Sanctuaire de l'Almanax est sur la carte intégrée, en Plaine des Porkass")
    func sanctuaire() throws {
        let lieu = try #require(ReperesCarte(Carte.integree.lieux).lieu(id: Almanax.sanctuaire))
        #expect(lieu.noms["fr"] == "Sanctuaire de l'Almanax")
        #expect(lieu.monde == Zaap.mondeDesDouze)
    }
}
