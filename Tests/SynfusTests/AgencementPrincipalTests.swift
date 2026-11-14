import Testing
import CoreGraphics
@testable import Synfus

/// Qui va où quand Synfus amène un perso devant dans un « Un grand + vignettes ».
struct AgencementPrincipalTests {

    private static let zone = CGRect(x: 0, y: 25, width: 1728, height: 1067)
    private static let cles = ["1#0", "2#0", "3#0"]

    /// Un rangement `.principale` de trois fenêtres, le grand à `grand`, chaque fenêtre relue
    /// exactement où on l'a posée.
    private func agencement(grand: Int = 0) throws -> AgencementPrincipal {
        let cadres = LayoutComputer.cadres(.principale, nombre: Self.cles.count,
                                           indexPrincipal: grand, dans: Self.zone)
        var places: [String: AgencementPrincipal.Place] = [:]
        for (cle, cadre) in zip(Self.cles, cadres) { places[cle] = .init(voulu: cadre, lu: cadre) }
        return try #require(AgencementPrincipal(places: places, grand: Self.cles[grand]))
    }

    private func lus(_ agencement: AgencementPrincipal) -> [String: CGRect] {
        agencement.places.mapValues(\.lu)
    }

    @Test("Le perso amené prend la place du grand, l'ancien grand prend sa vignette")
    func permute() throws {
        let depart = try agencement()
        let suite = depart.suite(amene: "3#0", lus: lus(depart))
        guard case .permuter(let permutation) = suite else {
            Issue.record("attendu une permutation, reçu \(suite)")
            return
        }
        #expect(permutation.cadreAmene == depart.places["1#0"]?.voulu)
        #expect(permutation.cadreAncienGrand == depart.places["3#0"]?.voulu)

        let relus = lus(depart).merging(["3#0": permutation.cadreAmene,
                                         "1#0": permutation.cadreAncienGrand]) { $1 }
        let apres = try #require(depart.apres(permutation, lus: relus))
        #expect(apres.grand == "3#0")
        // L'ancien grand reprend la vignette du perso amené, les autres ne bougent pas.
        #expect(apres.places["3#0"]?.voulu == depart.places["1#0"]?.voulu)
        #expect(apres.places["1#0"]?.voulu == depart.places["3#0"]?.voulu)
        #expect(apres.places["2#0"] == depart.places["2#0"])
    }

    @Test("Le grand amené devant, ou un perso hors de la disposition : rien ne bouge")
    func rien() throws {
        let depart = try agencement()
        #expect(depart.suite(amene: "1#0", lus: lus(depart)) == .rien)
        #expect(depart.suite(amene: "9#0", lus: lus(depart)) == .rien)
        #expect(!depart.estVignette("1#0") && !depart.estVignette("9#0") && depart.estVignette("2#0"))
    }

    @Test("Une fenêtre déplacée à la main abandonne la disposition")
    func deplaceeALaMain() throws {
        let depart = try agencement()
        var deplaces = lus(depart)
        deplaces["1#0"] = deplaces["1#0"]?.offsetBy(dx: 120, dy: 0)
        #expect(depart.suite(amene: "2#0", lus: deplaces) == .abandonner)
        var agrandie = lus(depart)
        agrandie["2#0"]?.size.height += 200
        #expect(depart.suite(amene: "2#0", lus: agrandie) == .abandonner)
    }

    @Test("Une fenêtre illisible — autre bureau, fermée, muette — abandonne la disposition")
    func illisible() throws {
        let depart = try agencement()
        var sansGrand = lus(depart)
        sansGrand["1#0"] = nil
        #expect(depart.suite(amene: "2#0", lus: sansGrand) == .abandonner)
        var sansAmene = lus(depart)
        sansAmene["2#0"] = nil
        #expect(depart.suite(amene: "2#0", lus: sansAmene) == .abandonner)
    }

    @Test("Un arrondi du client n'est pas un déplacement")
    func tolerance() throws {
        let depart = try agencement()
        var arrondis = lus(depart)
        arrondis["1#0"] = arrondis["1#0"]?.insetBy(dx: 1, dy: 1)
        guard case .permuter = depart.suite(amene: "2#0", lus: arrondis) else {
            Issue.record("un écart d'un point doit permuter")
            return
        }
    }

    @Test("Une taille plafonnée par le client sert de référence, pas la taille demandée")
    func taillePlafonnee() throws {
        let grand = CGRect(x: 0, y: 25, width: 1400, height: 1067)
        let vignette = CGRect(x: 1408, y: 25, width: 320, height: 529)
        let plafonnee = CGRect(x: 1408, y: 25, width: 400, height: 529)
        let depart = try #require(AgencementPrincipal(
            places: ["a": .init(voulu: grand, lu: grand), "b": .init(voulu: vignette, lu: plafonnee)],
            grand: "a"))
        #expect(depart.suite(amene: "b", lus: ["a": grand, "b": plafonnee])
            == .permuter(.init(amene: "b", cadreAmene: grand, ancienGrand: "a", cadreAncienGrand: vignette)))
    }

    @Test("Une rafale de bascules garde une seule fenêtre au grand")
    func rafale() throws {
        var courant = try agencement()
        for cle in ["2#0", "3#0", "1#0", "3#0"] {
            guard case .permuter(let permutation) = courant.suite(amene: cle, lus: lus(courant)) else {
                Issue.record("bascule vers \(cle) sans permutation")
                return
            }
            let relus = lus(courant).merging([permutation.amene: permutation.cadreAmene,
                                              permutation.ancienGrand: permutation.cadreAncienGrand]) { $1 }
            courant = try #require(courant.apres(permutation, lus: relus))
            #expect(courant.grand == cle)
        }
        let grands = courant.places.values.filter { $0.voulu.width > LayoutComputer.colonneMinimale * 2 }
        #expect(grands.count == 1)
        #expect(Set(courant.places.values.map { "\($0.voulu)" }).count == Self.cles.count)
    }

    @Test("Sans place pour le grand, pas d'agencement")
    func sansGrand() {
        #expect(AgencementPrincipal(places: [:], grand: "1#0") == nil)
    }
}
