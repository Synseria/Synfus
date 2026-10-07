import Foundation
import Testing
@testable import Synfus

/// Le téléchargement réel des quêtes depuis DofusDB — réseau, une minute :
/// ignoré sans `SYNFUS_RESEAU=1`.
struct QuetesReseauTests {
    @Test("Les quêtes de DofusDB se téléchargent et se tiennent",
          .enabled(if: ProcessInfo.processInfo.environment["SYNFUS_RESEAU"] == "1"))
    func telechargement() async throws {
        let debut = Date()
        let quetes = try await QuetesDofusDB.telecharger()
        let taille = try JSONEncoder().encode(quetes).count
        print("quêtes : \(quetes.quetes.count), PNJ situés : \(quetes.pnjs.count), objets : \(quetes.objets.count),"
              + " \(taille / 1024) Ko, \(Int(Date().timeIntervalSince(debut))) s")
        #expect(quetes.quetes.count >= Quetes.minimumPlausible)
        let wogew = try #require(quetes.quetes.first { $0.id == 18 })
        #expect(wogew.etapes.count == 3)
        #expect(quetes.texte(wogew.etapes[1].objectifs[0].textes["fr"] ?? "", en: .fr).contains("{") == false)
        #expect(quetes.pnjs.contains { $0.id == 196 && $0.positions.contains(PNJ.Position(x: -1, y: -39)) })

        var contexte = ContextePalette()
        contexte.lieux = Carte.integree.lieux
        contexte.zaaps = Carte.integree.zaaps
        contexte.quetes = quetes
        let horloge = ContinuousClock()
        let index = IndexPalette(contexte)
        let construction = horloge.measure { _ = index.tout }
        let frappe = horloge.measure { _ = RecherchePalette.entrees("bonta", index) }
        print("index : \(construction), frappe : \(frappe)")
        #expect(frappe < .milliseconds(150))
    }
}
