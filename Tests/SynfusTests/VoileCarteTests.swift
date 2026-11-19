// Le voile des cartes à image : aucune pointe, donc aucun trait clair en travers de la carte.

import Foundation
import Testing
@testable import Synfus

@Suite struct VoileCarteTests {
    /// Échantillonné finement, le voile ne saute nulle part et sa pente change sans à-coup : un
    /// creux en pointe (pente qui s'inverse d'un coup) se voit comme une ligne.
    @Test func leVoileNaNiSautNiPointe() {
        let (haut, bas) = (0.35 as CGFloat, 0.78 as CGFloat)
        let pas: CGFloat = 0.001
        let valeurs = stride(from: 0, through: 1, by: pas).map { FondCarte.opacite($0, haut: haut, bas: bas) }
        for i in 1..<valeurs.count {
            #expect(abs(valeurs[i] - valeurs[i - 1]) < 0.01)
        }
        let pentes = (1..<valeurs.count).map { (valeurs[$0] - valeurs[$0 - 1]) / Double(pas) }
        for i in 1..<pentes.count {
            #expect(abs(pentes[i] - pentes[i - 1]) < 0.5, "pente brisée à \(Double(i) * Double(pas))")
        }
    }

    @Test func denseAuxBordsLegerAuMilieu() {
        let (haut, bas) = (0.35 as CGFloat, 0.78 as CGFloat)
        let milieu = FondCarte.opacite((haut + bas) / 2, haut: haut, bas: bas)
        #expect(FondCarte.opacite(0, haut: haut, bas: bas) > milieu)
        #expect(FondCarte.opacite(1, haut: haut, bas: bas) > milieu)
    }
}
