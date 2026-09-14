import Testing
import Foundation
import ApplicationServices
@testable import Synfus

/// L'aperçu ne doit pas survivre au perso qu'il montre : la règle qui décide ce
/// qu'il en reste après une mise à jour de la liste est isolée ici, sans
/// panneau ni capture.
@MainActor
struct PreviewSurvivalTests {

    private func client(pid: pid_t, nom: String, dormant: Bool = false) -> DofusClient {
        DofusClient(
            pid: pid,
            slotKey: "\(pid)#0",
            // Une référence d'application suffit : rien n'est lu dans ces tests.
            axWindow: .application(pid),
            rawTitle: "\(nom) - Feca - 3.6.8.8 - Release",
            name: nom,
            characterClass: "Feca",
            dormant: dormant
        )
    }

    @Test("Sans aperçu, rien à décider")
    func aucunApercu() {
        #expect(PreviewPanelController.surviving(nil, among: [client(pid: 10, nom: "Aeryn")]) == nil)
    }

    @Test("Un aperçu simple disparaît avec son perso")
    func simpleDisparaitAvecSonPerso() {
        let aeryn = client(pid: 10, nom: "Aeryn")
        let brok = client(pid: 20, nom: "Brok")
        #expect(PreviewPanelController.surviving(.single(aeryn), among: [brok]) == nil)
        #expect(PreviewPanelController.surviving(.single(aeryn), among: []) == nil)
    }

    @Test("Un aperçu simple survit à un perso revenu sous un autre état")
    func simpleSurvitAuChangementDEtat() {
        let aeryn = client(pid: 10, nom: "Aeryn")
        // Passé sur un autre bureau : même identité, autre état — c'est
        // précisément ce que l'égalité de `DofusClient` ne reconnaissait pas.
        let endormi = client(pid: 10, nom: "Aeryn", dormant: true)
        #expect(PreviewPanelController.surviving(.single(aeryn), among: [endormi]) == .single(aeryn))
    }

    @Test("La grille se resserre sur les persos restants et disparaît avec le dernier")
    func grilleSeResserre() {
        let aeryn = client(pid: 10, nom: "Aeryn")
        let brok = client(pid: 20, nom: "Brok")
        let cael = client(pid: 30, nom: "Cael")
        let grille = PreviewPanelController.Mode.grid([aeryn, brok, cael])

        let reduite = PreviewPanelController.surviving(grille, among: [cael, aeryn])
        #expect(reduite?.clients.map(\.name) == ["Aeryn", "Cael"])
        #expect(PreviewPanelController.surviving(grille, among: []) == nil)
    }
}
