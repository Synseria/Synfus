import Testing
import Foundation
@testable import Synfus

/// La règle d'abattage des clients gelés : sans fenêtre **et** muet à trois
/// sondes consécutives espacées de 5 s. Elle est nourrie par l'inventaire et
/// ne lit rien elle-même.
struct FreezeStrikesTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
    private func apres(_ secondes: TimeInterval) -> Date { t0.addingTimeInterval(secondes) }
    private func registre() -> FreezeStrikes {
        FreezeStrikes(probeInterval: 5, strikesRequired: 3)
    }

    @Test("Un pid jamais sondé est à sonder, et n'est pas suspect")
    func pidNeufASonder() {
        let r = registre()
        #expect(r.shouldProbe(7, now: t0))
        #expect(r.suspects.isEmpty)
    }

    @Test("Trois mutismes espacés de 5 s condamnent")
    func troisMutismesCondamnent() {
        var r = registre()
        #expect(r.record(7, mute: true, probed: true, now: t0) == .frappe(1))
        #expect(r.suspects == [7])
        #expect(r.record(7, mute: true, probed: true, now: apres(5)) == .frappe(2))
        #expect(r.record(7, mute: true, probed: true, now: apres(10)) == .condamne)
    }

    @Test("Entre deux échéances, la sonde n'est pas due")
    func sondePasDueEntreDeuxEcheances() {
        var r = registre()
        _ = r.record(7, mute: true, probed: true, now: t0)
        #expect(!r.shouldProbe(7, now: apres(2)))
        #expect(r.shouldProbe(7, now: apres(5)))
    }

    @Test("Un pid silencieux sauté par l'inventaire garde son ardoise")
    func silencieuxNonSondeGardeSonArdoise() {
        var r = registre()
        _ = r.record(7, mute: true, probed: true, now: t0)
        // Deux secondes plus tard, l'inventaire n'a pas sondé : le pid est
        // silencieux mais pas muet, et ce n'est pas une réponse.
        #expect(r.record(7, mute: false, probed: false, now: apres(2)) == .ignore)
        #expect(r.suspects == [7])
        #expect(r.record(7, mute: true, probed: true, now: apres(5)) == .frappe(2))
    }

    @Test("Une réponse à l'échéance efface l'ardoise")
    func reponseALEcheanceBlanchit() {
        var r = registre()
        _ = r.record(7, mute: true, probed: true, now: t0)
        _ = r.record(7, mute: true, probed: true, now: apres(5))
        #expect(r.record(7, mute: false, probed: true, now: apres(10)) == .blanchi)
        #expect(r.suspects.isEmpty)
        // Et la série repart de zéro.
        #expect(r.record(7, mute: true, probed: true, now: apres(15)) == .frappe(1))
    }

    @Test("Un pid redevenu bavard ou disparu est oublié par la purge")
    func purgeOublieLesBavards() {
        var r = registre()
        _ = r.record(7, mute: true, probed: true, now: t0)
        _ = r.record(8, mute: true, probed: true, now: t0)
        r.prune(keeping: [8])
        #expect(r.suspects == [8])
        #expect(r.shouldProbe(7, now: apres(1)))
    }

    @Test("Un pid sain sondé à chaque tour n'accumule rien")
    func sainNAccumuleRien() {
        var r = registre()
        #expect(r.record(7, mute: false, probed: true, now: t0) == .blanchi)
        #expect(r.record(7, mute: false, probed: true, now: apres(2)) == .blanchi)
        #expect(r.suspects.isEmpty)
    }

    @Test("Un condamné qu'on n'achève pas n'est resondé qu'à l'échéance longue")
    func condamneResondeMoinsSouvent() {
        var r = FreezeStrikes(probeInterval: 5, strikesRequired: 3, condemnedInterval: 30)
        _ = r.record(7, mute: true, probed: true, now: t0)
        _ = r.record(7, mute: true, probed: true, now: apres(5))
        #expect(r.record(7, mute: true, probed: true, now: apres(10)) == .condamne)
        // À 5 s de la condamnation, un suspect ordinaire serait à sonder ;
        // le condamné, non — chaque sonde est une seconde de borne perdue.
        #expect(!r.shouldProbe(7, now: apres(15)))
        #expect(r.shouldProbe(7, now: apres(40)))
        // Et il reste suspect, donc injoignable pour les gestes.
        #expect(r.suspects == [7])
    }

    @Test("Un suspect sauté au départ n'est pas blanchi parce que l'échéance est passée au retour")
    func sauteAuDepartPasBlanchiAuRetour() {
        var r = registre()
        _ = r.record(7, mute: true, probed: true, now: t0)
        // L'inventaire est parti à 4 s (sonde pas due, pid sauté) et revient
        // à 6 s : l'échéance est passée, mais personne n'a interrogé le pid.
        #expect(r.record(7, mute: false, probed: false, now: apres(6)) == .ignore)
        #expect(r.suspects == [7])
    }
}
