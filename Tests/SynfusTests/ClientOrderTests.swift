import Testing
import ApplicationServices
@testable import Synfus

/// L'ordre de la barre est celui de `characterOrder`, et c'est le même
/// comparateur qui sert à l'inventaire et au retri sans inventaire (`resort`).
@MainActor
struct ClientOrderTests {

    private func client(pid: pid_t, nom: String) -> DofusClient {
        DofusClient(
            pid: pid, slotKey: "\(pid)#0",
            axWindow: .application(pid),
            rawTitle: "\(nom) - Feca - 3.6.8.8 - Release",
            name: nom, characterClass: "Feca", dormant: false
        )
    }

    @Test("Les persos suivent l'ordre de préférence, les absents de la liste sont sautés")
    func suitLOrdreDePreference() {
        let trie = ClientMemory.sorted(
            [client(pid: 30, nom: "Cid"), client(pid: 10, nom: "Aeryn"), client(pid: 20, nom: "Brok")],
            by: ["Brok", "Zoé", "Cid", "Aeryn"]
        )
        #expect(trie.map(\.name) == ["Brok", "Cid", "Aeryn"])
    }

    @Test("Les noms inconnus de la liste vont en fin, par pid croissant")
    func inconnusEnFinParPid() {
        let trie = ClientMemory.sorted(
            [client(pid: 50, nom: "Dofus 3.3.4.9"), client(pid: 40, nom: "Brok (2)"),
             client(pid: 10, nom: "Aeryn")],
            by: ["Aeryn"]
        )
        #expect(trie.map(\.name) == ["Aeryn", "Brok (2)", "Dofus 3.3.4.9"])
    }

    @Test("Un ordre vide trie par pid, c'est-à-dire par ordre de lancement")
    func ordreVideTrieParPid() {
        let trie = ClientMemory.sorted(
            [client(pid: 3, nom: "C"), client(pid: 1, nom: "A"), client(pid: 2, nom: "B")],
            by: []
        )
        #expect(trie.map(\.pid) == [1, 2, 3])
    }

    @Test("Deux homonymes dans la liste : c'est le premier rang qui compte")
    func doublonDansLaListePremierRang() {
        let trie = ClientMemory.sorted(
            [client(pid: 2, nom: "Brok"), client(pid: 1, nom: "Aeryn")],
            by: ["Brok", "Aeryn", "Brok"]
        )
        #expect(trie.map(\.name) == ["Brok", "Aeryn"])
    }
}
