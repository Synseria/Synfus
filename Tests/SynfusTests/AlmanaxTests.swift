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

    @Test("Le jour gardé se relit ; une autre forme, non")
    func disque() throws {
        let almanax = Almanax(try JSONDecoder().decode(Almanax.API.self, from: Data(Self.reponse.utf8)), jour: "2026-10-09")
        let donnees = try JSONEncoder().encode(almanax)
        #expect(Almanax.relire(donnees) == almanax)
        var ancien = almanax
        ancien.format = 0
        #expect(Almanax.relire(try JSONEncoder().encode(ancien)) == nil)
        #expect(Almanax.relire(nil) == nil)
    }
}
