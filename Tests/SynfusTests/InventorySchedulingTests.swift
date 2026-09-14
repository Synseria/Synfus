import Testing
@testable import Synfus

/// Un inventaire à la fois : la politique de lancement de l'acteur
/// d'inventaire, sans acteur ni Accessibilité.
struct InventorySchedulingTests {

    @Test("Au repos, une demande lance la génération suivante")
    func demandeAuReposLance() {
        var s = InventoryScheduling()
        #expect(s.request() == .launch(generation: 1))
        #expect(s.inFlight)
        #expect(s.nextToApply == 1)
    }

    @Test("En vol, une demande est absorbée et un seul tour de plus est dû")
    func demandesEnVolCoalescent() {
        var s = InventoryScheduling()
        _ = s.request()
        #expect(s.request() == .coalesce)
        #expect(s.request() == .coalesce)
        #expect(s.nextToApply == 2)
        // Une seule relance à la fin, quelle que soit la rafale.
        #expect(s.completed(generation: 1) == .apply(relaunch: 2))
        #expect(s.inFlight)
        #expect(s.completed(generation: 2) == .apply(relaunch: nil))
        #expect(!s.inFlight)
    }

    @Test("Un résultat d'une génération dépassée est jeté")
    func resultatPerimeIgnore() {
        var s = InventoryScheduling()
        _ = s.request()
        #expect(s.completed(generation: 0) == .stale)
        #expect(s.inFlight)
        #expect(s.completed(generation: 1) == .apply(relaunch: nil))
        // Rien en vol : un second retour ne peut venir de personne.
        #expect(s.completed(generation: 1) == .stale)
    }
}
