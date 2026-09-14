import Testing
import Foundation
@testable import Synfus

/// Ce qu'un résultat d'inventaire fait à la mémoire et à la barre, une fois
/// revenu sur main : la règle est pure, on la nourrit d'un relevé fabriqué.
@MainActor
struct ConsolidationTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 5_000)

    private func client(pid: pid_t, nom: String) -> DofusClient {
        DofusClient(pid: pid, slotKey: "\(pid)#0", axWindow: .application(pid),
                    rawTitle: "\(nom) - Feca - 3.6.8.8 - Release", name: nom,
                    characterClass: "Feca", dormant: false)
    }

    private func result(found: [DofusClient], live: Set<pid_t>, talkative: Set<pid_t>,
                        mute: Set<pid_t> = [], titles: [pid_t: String] = [:],
                        crossProbed: Set<pid_t> = []) -> InventoryResult {
        InventoryResult(generation: 1, found: found, livePIDs: live, talkativePIDs: talkative,
                        mutePIDs: mute, probedPIDs: live, crossSpaceTitles: titles,
                        crossSpaceProbed: crossProbed, duration: 0)
    }

    @Test("Un client muet reste affiché, dormant, par la mémoire")
    func muetResteDormant() {
        let brok = client(pid: 20, nom: "Brok")
        let r = result(found: [], live: [20], talkative: [], mute: [20])
        let c = ClientMemory.consolidate(r, remembered: [20: [brok]], crossSpaceChecked: [:], now: t0)
        #expect(c.clients.map(\.name) == ["Brok"])
        #expect(c.clients[0].dormant)
        #expect(c.silentPIDs == [20])
    }

    @Test("Un processus mort sort de la mémoire et des dates de lecture")
    func mortOublie() {
        let brok = client(pid: 20, nom: "Brok")
        let r = result(found: [], live: [], talkative: [])
        let c = ClientMemory.consolidate(r, remembered: [20: [brok]], crossSpaceChecked: [20: t0], now: t0)
        #expect(c.clients.isEmpty)
        #expect(c.remembered.isEmpty)
        #expect(c.crossSpaceChecked.isEmpty)
    }

    @Test("Un titre lu à travers les espaces fabrique un dormant, et la lecture est datée même sans titre")
    func titreCrossSpaceDevientDormant() {
        let r = result(found: [], live: [30, 31], talkative: [],
                       titles: [30: "Cara - Iop - 3.6.8.8 - Release"], crossProbed: [30, 31])
        let c = ClientMemory.consolidate(r, remembered: [:], crossSpaceChecked: [:], now: t0)
        #expect(c.clients.map(\.name) == ["Cara"])
        #expect(c.clients[0].dormant)
        #expect(c.remembered[30]?.first?.name == "Cara")
        #expect(c.crossSpaceChecked[30] == t0)
        #expect(c.crossSpaceChecked[31] == t0)
    }

    @Test("Un titre cross-space pour un pid déjà mémorisé est ignoré")
    func titreCrossSpaceIgnoreSiMemoire() {
        let brok = client(pid: 20, nom: "Brok")
        let r = result(found: [], live: [20], talkative: [],
                       titles: [20: "Autre - Iop - 3.6.8.8 - Release"], crossProbed: [20])
        let c = ClientMemory.consolidate(r, remembered: [20: [brok]], crossSpaceChecked: [:], now: t0)
        #expect(c.clients.map(\.name) == ["Brok"])
    }

    @Test("Un perso vu remplace la mémoire de son processus")
    func vuRemplaceLaMemoire() {
        let ancien = client(pid: 20, nom: "Brok")
        let nouveau = client(pid: 20, nom: "Zed")
        let r = result(found: [nouveau], live: [20], talkative: [20])
        let c = ClientMemory.consolidate(r, remembered: [20: [ancien]], crossSpaceChecked: [:], now: t0)
        #expect(c.clients.map(\.name) == ["Zed"])
        #expect(c.remembered[20]?.map(\.name) == ["Zed"])
        #expect(c.silentPIDs.isEmpty)
    }
}
