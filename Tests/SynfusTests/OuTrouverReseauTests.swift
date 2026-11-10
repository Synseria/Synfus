import Foundation
import Testing
@testable import Synfus

/// Où trouver, demandé pour de vrai à DofusDB — réseau : ignoré sans
/// `SYNFUS_RESEAU=1`. Les requêtes fines (`drops.objectId`, `monsters[$in]`,
/// champs pointés) sont celles dont l'API pourrait changer la forme.
struct OuTrouverReseauTests {
    private static let actif = ProcessInfo.processInfo.environment["SYNFUS_RESEAU"] == "1"

    @Test("Le Minotot : les salles du labyrinthe, situées par leur repère sur l'île du Minotoror",
          .enabled(if: actif))
    func minotot() async throws {
        let fiche = try await OuTrouverDofusDB.monstre(827)
        #expect(fiche.noms["fr"] == "Minotot")
        #expect(fiche.repaires.contains { $0.genre == .donjon && $0.noms["fr"] == "Salle du Minotot" })
        let situes = OuTrouver.situes(fiche.repaires, depuis: (0, 0), reseau: ReseauSousZones(Carte.integree),
                                      reperes: ReperesCarte(Carte.integree.lieux)) { ItineraireZaap.distance((0, 0), $0) }
        #expect(situes.contains { [$0.situation.x, $0.situation.y, $0.situation.monde] == [-42, -17, Zaap.mondeDesDouze] })
    }

    @Test("La laine de Bouftou : lâchée par le Bouftou, situé à Astrub et dans sa cour ; une coiffe se fabrique",
          .enabled(if: actif))
    func objets() async throws {
        let laine = try await OuTrouverDofusDB.objet(384)
        let bouftou = try #require(laine.lacheurs.first { $0.monstre.id == 101 })
        #expect(bouftou.taux > 10)
        #expect(bouftou.monstre.repaires.contains { $0.genre == .donjon && $0.entree == 120063489 })
        let reseau = ReseauSousZones(Carte.integree)
        #expect(bouftou.monstre.repaires.contains { $0.genre == .sousZone && !reseau.cases($0.id).isEmpty })
        let coiffe = try await OuTrouverDofusDB.objet(8463)
        let recette = try #require(coiffe.recette)
        #expect(recette.metier["fr"] == "Tailleur" && recette.niveau > 0 && recette.ingredients.count == 7)
        #expect(recette.ingredients.allSatisfy { $0.noms["fr"]?.hasPrefix("#") == false && $0.quantite > 0 })
    }
}
