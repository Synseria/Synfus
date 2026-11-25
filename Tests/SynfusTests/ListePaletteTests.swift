import Foundation
import Testing
@testable import Synfus

/// La liste classée de la palette : doublons réunis.
struct ListePaletteTests {
    private func lignesDuDonjon(_ entrees: [EntreePalette]) -> [EntreePalette] {
        entrees.filter { $0.effet == .donjon(ContexteNidas.donjon) }
    }

    @Test("Le boss et son donjon : une seule ligne, la mieux classée, à la case du donjon",
          arguments: TriPalette.allCases)
    func bossEtDonjon(tri: TriPalette) throws {
        let contexte = try ContexteNidas.contexte()
        for filtre in [FiltrePalette.tout, .donjons] {
            let lignes = lignesDuDonjon(RecherchePalette.entrees("nidas", contexte, filtre: filtre, tri: tri))
            #expect(lignes.count == 1)
        }
        let boss = try #require(lignesDuDonjon(RecherchePalette.entrees("nidas", contexte)).first)
        #expect(boss.estBoss && boss.titre == "Roi Nidas")
        #expect(boss.detail == Coordonnees.texte(-5, -5) && boss.carte == 112460048 && !boss.etiquetable)
        let donjon = try #require(lignesDuDonjon(RecherchePalette.entrees("palais", contexte)).first)
        #expect(!donjon.estBoss && donjon.titre == "Palais du roi Nidas" && donjon.etiquetable)
    }

    @Test("Un donjon à deux boss : une ligne, celle du boss cherché")
    func deuxBoss() {
        let boss = { (id: Int, nom: String) in
            EntreePalette(id: "boss:\(id)", genre: .monstre, titre: nom, effet: .donjon(1))
        }
        let donjon = EntreePalette(id: "lieu:1", genre: .lieu, titre: "Donjon", detail: "[1,1]", cle: "lieu:1", effet: .donjon(1))
        let autre = EntreePalette(id: "lieu:2", genre: .lieu, titre: "Autre", effet: .donjon(2))
        let lignes = ListePalette.fusionnerDonjons([boss(2, "Second"), autre, boss(1, "Premier"), donjon])
        #expect(lignes.map(\.id) == ["boss:2", "lieu:2"])
        #expect(lignes[0].detail == "[1,1]" && lignes[0].cle == nil)
    }
}
