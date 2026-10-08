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
        #expect(quetes.pnjs.contains { $0.id == 196 && $0.passages.contains { $0.position == PNJ.Position(x: -1, y: -39) } })
        let fiche = try #require(quetes.fiche(18, en: .fr))
        #expect(fiche.etapes.allSatisfy { $0.description != nil })
        #expect(fiche.etapes.flatMap(\.objectifs).contains { $0.carte == 185862149 })
        let etapes = quetes.quetes.flatMap(\.etapes)
        #expect(etapes.contains { !$0.recompenses.objets.isEmpty } && etapes.contains { $0.recompenses.experience > 0 })
        #expect(etapes.contains { !$0.recompenses.emotes.isEmpty } && quetes.emotes.isEmpty == false)
        #expect(etapes.contains { !$0.recompenses.titres.isEmpty } && quetes.titres.isEmpty == false)
        #expect(quetes.suivantes(de: 55).map(\.id).contains(56))
        #expect(quetes.familles[String(Quetes.familleObjetDeQuete)] != nil)
        #expect(quetes.quetes.contains { quete in quetes.fiche(quete, en: .fr).ressources.contains(where: \.objetDeQuete) })
        #expect(quetes.quetes.contains { ConditionsQuete.lire($0.critere).classe != nil })
        #expect(quetes.metiers["26"] != nil && quetes.camps["1"] != nil)

        var contexte = ContextePalette()
        contexte.lieux = Carte.integree.lieux
        contexte.zaaps = Carte.integree.zaaps
        contexte.quetes = quetes
        let horloge = ContinuousClock()
        let index = IndexPalette(contexte)
        let entrees = horloge.measure {
            _ = RecherchePalette.lieux(contexte) + RecherchePalette.quetes(contexte) + RecherchePalette.pnjs(contexte)
        }
        print("entrées seules : \(entrees)")
        let construction = horloge.measure { _ = index.tout }
        let frappe = horloge.measure { _ = RecherchePalette.entrees("bonta", index) }
        let champs = IndexPalette.champs(de: contexte)
        let rechauffe = horloge.measure { _ = IndexPalette(contexte, connus: champs).tout }
        print("index préchauffé : \(rechauffe)")
        print("index : \(construction), frappe : \(frappe)")
        #expect(frappe < .milliseconds(150))
    }
}
