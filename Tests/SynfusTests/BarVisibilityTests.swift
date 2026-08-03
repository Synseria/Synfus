import Testing
import Foundation
@testable import Synfus

/// La décision d'afficher la barre est isolée en fonction pure : elle dépend de
/// deux réglages et de qui est au premier plan, rien d'autre.
@MainActor
struct BarVisibilityTests {

    private let synfus: pid_t = 100
    private let dofus: pid_t = 200
    private let autre: pid_t = 300

    private func visible(
        barre: Bool = true,
        seulementSurDofus: Bool,
        devant: pid_t?,
        devantEstDofus: Bool
    ) -> Bool {
        FloatingBarController.computeVisibility(
            barVisible: barre,
            onlyWithDofus: seulementSurDofus,
            frontPID: devant,
            frontIsDofus: devantEstDofus,
            ownPID: synfus
        )
    }

    @Test("Barre désactivée : rien ne l'affiche")
    func barreDesactivee() {
        #expect(!visible(barre: false, seulementSurDofus: false, devant: dofus, devantEstDofus: true))
    }

    @Test("Sans restriction, la barre reste affichée quelle que soit l'app devant")
    func sansRestriction() {
        #expect(visible(seulementSurDofus: false, devant: autre, devantEstDofus: false))
        #expect(visible(seulementSurDofus: false, devant: pid_t?.none, devantEstDofus: false))
    }

    @Test("Restreinte à Dofus, la barre suit le premier plan")
    func restreinteADofus() {
        #expect(visible(seulementSurDofus: true, devant: dofus, devantEstDofus: true))
        #expect(!visible(seulementSurDofus: true, devant: autre, devantEstDofus: false))
    }

    @Test("Synfus lui-même compte comme « devant »")
    func synfusCompteCommeDevant() {
        // Sans cette exception, ouvrir les réglages ferait disparaître la barre
        // que l'on est en train de configurer.
        #expect(visible(seulementSurDofus: true, devant: synfus, devantEstDofus: false))
    }

    @Test("Premier plan inconnu : la barre restreinte reste masquée")
    func premierPlanInconnu() {
        #expect(!visible(seulementSurDofus: true, devant: pid_t?.none, devantEstDofus: false))
    }
}
