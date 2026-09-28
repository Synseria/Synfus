import Testing
@testable import Synfus

/// La rotation saute les clients injoignables — ce qui la garde fiable
/// pendant qu'un client meurt après un ⌘Q.
struct RotationTests {

    @Test("Tous joignables : le pas suit la liste, en boucle")
    func boucle() {
        let tous = [true, true, true]
        #expect(Rotation.suivant(depuis: 0, pas: 1, joignables: tous) == 1)
        #expect(Rotation.suivant(depuis: 2, pas: 1, joignables: tous) == 0)
        #expect(Rotation.suivant(depuis: 0, pas: -1, joignables: tous) == 2)
    }

    @Test("Un client qui se ferme est sauté, dans les deux sens")
    func sauteLInjoignable() {
        let joignables = [true, false, true, true]
        #expect(Rotation.suivant(depuis: 0, pas: 1, joignables: joignables) == 2)
        #expect(Rotation.suivant(depuis: 2, pas: -1, joignables: joignables) == 0)
    }

    @Test("Depuis le client qui se ferme lui-même, on repart au suivant")
    func depuisLeMourant() {
        #expect(Rotation.suivant(depuis: 1, pas: 1, joignables: [true, false, true]) == 2)
    }

    @Test("Hors de l'effectif, on revient au premier joignable")
    func sansRangCourant() {
        #expect(Rotation.suivant(depuis: nil, pas: 1, joignables: [false, true, true]) == 1)
        #expect(Rotation.suivant(depuis: 7, pas: 1, joignables: [true, true]) == 0)
    }

    @Test("Seul joignable : on y reste ; aucun : rien")
    func casLimites() {
        #expect(Rotation.suivant(depuis: 0, pas: 1, joignables: [true, false]) == 0)
        #expect(Rotation.suivant(depuis: 0, pas: 1, joignables: [false, false]) == nil)
        #expect(Rotation.suivant(depuis: nil, pas: 1, joignables: []) == nil)
    }
}
