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
            axWindow: AXUIElementCreateApplication(pid),
            rawTitle: "\(nom) - Feca - 3.6.8.8 - Release",
            name: nom,
            characterClass: "Feca",
            dormant: dormant
        )
    }

    @Test("Sans aperçu, rien à décider")
    func aucunApercu() {
        #expect(PreviewPanelController.surviving(nil, among: [client(pid: 10, nom: "Amarine")]) == nil)
    }

    @Test("Un aperçu simple disparaît avec son perso")
    func simpleDisparaitAvecSonPerso() {
        let amarine = client(pid: 10, nom: "Amarine")
        let bram = client(pid: 20, nom: "Bram")
        #expect(PreviewPanelController.surviving(.single(amarine), among: [bram]) == nil)
        #expect(PreviewPanelController.surviving(.single(amarine), among: []) == nil)
    }

    @Test("Un aperçu simple survit à un perso revenu sous un autre état")
    func simpleSurvitAuChangementDEtat() {
        let amarine = client(pid: 10, nom: "Amarine")
        // Passé sur un autre bureau : même identité, autre état — c'est
        // précisément ce que l'égalité de `DofusClient` ne reconnaissait pas.
        let endormi = client(pid: 10, nom: "Amarine", dormant: true)
        #expect(PreviewPanelController.surviving(.single(amarine), among: [endormi]) == .single(amarine))
    }

    @Test("La grille se resserre sur les persos restants et disparaît avec le dernier")
    func grilleSeResserre() {
        let amarine = client(pid: 10, nom: "Amarine")
        let bram = client(pid: 20, nom: "Bram")
        let corel = client(pid: 30, nom: "Corel")
        let grille = PreviewPanelController.Mode.grid([amarine, bram, corel])

        let reduite = PreviewPanelController.surviving(grille, among: [corel, amarine])
        #expect(reduite?.clients.map(\.name) == ["Amarine", "Corel"])
        #expect(PreviewPanelController.surviving(grille, among: []) == nil)
    }
}
