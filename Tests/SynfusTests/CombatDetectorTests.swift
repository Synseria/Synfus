import Testing
import Foundation
@testable import Synfus

/// Le verdict combat / hors combat, sur des références fabriquées : la bande
/// basse « en combat » porte une rangée claire (la timeline), l'autre non.
struct CombatDetectorTests {

    private func band(timeline: Bool, noise: UInt8 = 0) -> LumaBitmap {
        var image = LumaBitmap(width: 64, height: 14, fill: 40 &+ noise)
        if timeline { image.fill(CGRect(x: 8, y: 4, width: 48, height: 4), with: 220) }
        image.fill(CGRect(x: 0, y: 11, width: 64, height: 3), with: 90)   // la barre de sorts, commune
        return image
    }

    @Test("Deux relevés concordants font basculer, un seul non")
    func hysteresis() {
        var d = CombatDetector(enCombat: band(timeline: true), horsCombat: band(timeline: false))
        #expect(d.verdict == nil)
        #expect(d.observe(band(timeline: true, noise: 3)) == nil)
        #expect(d.observe(band(timeline: true, noise: 5)) == true)
        // Un relevé isolé hors combat — une transition — ne change rien.
        #expect(d.observe(band(timeline: false)) == true)
        #expect(d.observe(band(timeline: true)) == true)
        #expect(d.observe(band(timeline: false)) == true)
        #expect(d.observe(band(timeline: false, noise: 2)) == false)
    }

    @Test("Un relevé qui ne ressemble à rien laisse le verdict en place")
    func indecis() {
        var d = CombatDetector(enCombat: band(timeline: true), horsCombat: band(timeline: false))
        let flat = LumaBitmap(width: 64, height: 14, fill: 100)
        #expect(d.observe(flat) == nil)
        #expect(d.read(flat).leaning == nil)
    }

    @Test("Les références se sauvent et se relisent")
    func codable() throws {
        let ref = band(timeline: true)
        let data = try JSONEncoder().encode(ref)
        #expect(try JSONDecoder().decode(LumaBitmap.self, from: data) == ref)
    }
}
