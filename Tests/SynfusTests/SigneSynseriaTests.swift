import Testing
@testable import Synfus

@Suite("Signe Synseria : géométrie de l'emblème")
struct SigneSynseriaTests {
    @Test("Un seul disque prend la couleur de l'app, et tout tient dans le rond")
    func geometrie() {
        let cercles = EmblemeSynseria.cercles
        #expect(cercles.filter { $0.remplissage == .primaire }.count == 1)
        #expect(cercles.first?.remplissage == .nuit)
        for c in cercles {
            #expect(c.cx - c.r - c.epaisseur / 2 >= 0 && c.cx + c.r + c.epaisseur / 2 <= EmblemeSynseria.cote)
            #expect(c.cy - c.r - c.epaisseur / 2 >= 0 && c.cy + c.r + c.epaisseur / 2 <= EmblemeSynseria.cote)
        }
    }

    @Test("Le mot s'écrit en minuscules, en deux parties")
    func mot() {
        #expect(EmblemeSynseria.mot.syn + EmblemeSynseria.mot.seria == "synseria")
    }
}
