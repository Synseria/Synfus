import Foundation
import Testing
@testable import Synfus

/// Les mécaniques des boss autres que le Comte : ce que l'aide en déduit à
/// chaque tour.
struct BossTests {
    @Test("Kimbo : l'état se lit au canal combat, la dernière ligne l'emporte")
    func kimbo() {
        #expect(Kimbo.etat(["[20:01] Kimbo : Glyphe impaire (1 tour)"]) == .impair)
        #expect(Kimbo.etat(["[20:01] Kimbo : Glyphe impaire", "[20:02] Kimbo : Glyphe paire"]) == .pair)
        #expect(Kimbo.etat(["[20:03] Kimbo: Odd Glyph"]) == .impair)
        #expect(Kimbo.etat(["[20:03] Kimbo: Glifo par"]) == .pair)
        #expect(Kimbo.etat(["[20:04] Le Disciple pose un glyphe par ici"]) == nil)
        #expect(Kimbo.etat(["[20:04] Syn-App lance Bulle."]) == nil)
        #expect(Kimbo.Etat.impair.glyphesImpairs && !Kimbo.Etat.pair.glyphesImpairs)
    }

    @Test("Toxoliath : vagues, Poison Volatile et Toxmose au fil des tours")
    func toxoliath() {
        #expect(Toxoliath.prochaineVague(apres: 1) == 6)
        #expect(Toxoliath.prochaineVague(apres: 6) == 11)
        #expect(Toxoliath.prochaineVague(apres: 21) == nil)
        #expect((1...14).filter(Toxoliath.poisonVolatile(au:)) == [6, 10, 14])
        #expect(Toxoliath.prochainPoisonVolatile(depuis: 2) == 6)
        #expect(Toxoliath.prochainPoisonVolatile(depuis: 7) == 10)
        #expect(Toxoliath.prochainPoisonVolatile(depuis: 10) == 10)
        #expect(Toxoliath.toxmose(toucheAu: 3, tour: 3) && Toxoliath.toxmose(toucheAu: 3, tour: 4))
        #expect(!Toxoliath.toxmose(toucheAu: 3, tour: 5) && !Toxoliath.toxmose(toucheAu: nil, tour: 3))
    }

    @Test("Ilyzaelle : deux tours alliée après chaque seuil, Vers les ténèbres tous les trois tours")
    func ilyzaelle() {
        #expect(Ilyzaelle.phase(seuil75: nil, seuil50: nil, tour: 4) == .premiere)
        #expect(Ilyzaelle.phase(seuil75: 2, seuil50: nil, tour: 3) == .allieeA75(depuis: 2))
        #expect(Ilyzaelle.phase(seuil75: 2, seuil50: nil, tour: 4) == .seconde)
        #expect(Ilyzaelle.phase(seuil75: 2, seuil50: 6, tour: 7) == .allieeA50(depuis: 6))
        #expect(Ilyzaelle.phase(seuil75: 2, seuil50: 6, tour: 8) == .gagnee)
        #expect((1...10).filter(Ilyzaelle.versLesTenebres(au:)) == [3, 6, 9])
        #expect(Ilyzaelle.prochainVersLesTenebres(depuis: 1) == 3)
        #expect(Ilyzaelle.prochainVersLesTenebres(depuis: 4) == 6)
        #expect(Ilyzaelle.prochainVersLesTenebres(depuis: 6) == 6)
    }

    @Test("Chaque boss lit au moins le combat ; seuls le Comte et Kimbo lisent le tchat")
    func lectures() {
        #expect(Boss.harebourg.lectures == [.vie, .tchat])
        #expect(Boss.kimbo.lectures == [.tchat])
        #expect(Boss.toxoliath.lectures.isEmpty)
        #expect(ActionPalette.toutes.filter { if case .boss = $0 { true } else { false } }.count == Boss.allCases.count)
    }
}
