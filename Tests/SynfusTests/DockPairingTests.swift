import Testing
import Foundation
import ApplicationServices
@testable import Synfus

/// L'appariement icône du Dock → perso. C'est une hypothèse — l'ordre des
/// icônes suit l'ordre de lancement, comme les pid —, mais elle porte sur les
/// **processus** : un client resté à l'écran de connexion a une icône sans
/// avoir de perso, et c'est exactement ce qui décalait tout le reste.
@MainActor
struct DockPairingTests {

    private func client(pid: pid_t, nom: String, index: Int = 0) -> DofusClient {
        DofusClient(
            pid: pid, slotKey: "\(pid)#\(index)", axWindow: .application(pid),
            rawTitle: "\(nom) - Feca - 3.6.8.8 - Release", name: nom,
            characterClass: "Feca", dormant: false
        )
    }

    @Test("Un client par perso : chaque icône tombe sur le sien")
    func casSimple() {
        let clients = [client(pid: 10, nom: "Aeryn"),
                       client(pid: 20, nom: "Brok"),
                       client(pid: 30, nom: "Cill")]
        let apparies = DockPairing.apparier(nombreIcones: 3, pidsVivants: [10, 20, 30],
                                            clients: clients)
        #expect(apparies.map { $0?.name } == ["Aeryn", "Brok", "Cill"])
        #expect(DockPairing.fiable(nombreIcones: 3, pidsVivants: [10, 20, 30]))
    }

    @Test("Un client resté au login garde sa place sans décaler les suivants")
    func clientAuLogin() {
        // Le pid 20 est lancé mais personne n'est en jeu : pas de perso, et
        // pourtant une icône, à sa place dans l'ordre de lancement.
        let clients = [client(pid: 10, nom: "Aeryn"), client(pid: 30, nom: "Cill")]
        let apparies = DockPairing.apparier(nombreIcones: 3, pidsVivants: [10, 20, 30],
                                            clients: clients)
        #expect(apparies.map { $0?.name } == ["Aeryn", nil, "Cill"])
    }

    @Test("Deux persos dans un même processus n'occupent qu'une icône")
    func deuxPersosUnProcessus() {
        let clients = [client(pid: 10, nom: "Aeryn"),
                       client(pid: 10, nom: "Aeryn (2)", index: 1),
                       client(pid: 20, nom: "Brok")]
        let apparies = DockPairing.apparier(nombreIcones: 2, pidsVivants: [10, 20],
                                            clients: clients)
        #expect(apparies.map { $0?.name } == ["Aeryn", "Brok"])
    }

    @Test("Le rang suit le pid croissant, quel que soit l'ordre de la liste")
    func ordreDesPids() {
        // La barre trie selon l'ordre de préférence, pas selon le pid : c'est
        // le pid qui fait foi côté Dock.
        let clients = [client(pid: 30, nom: "Cill"), client(pid: 10, nom: "Aeryn")]
        let apparies = DockPairing.apparier(nombreIcones: 2, pidsVivants: [10, 30],
                                            clients: clients)
        #expect(apparies.map { $0?.name } == ["Aeryn", "Cill"])
    }

    @Test("Plus d'icônes que de processus : l'appariement se dit douteux")
    func appariementDouteux() {
        #expect(!DockPairing.fiable(nombreIcones: 4, pidsVivants: [10, 20, 30]))
        #expect(!DockPairing.fiable(nombreIcones: 2, pidsVivants: [10, 20, 30]))
        let apparies = DockPairing.apparier(nombreIcones: 4, pidsVivants: [10],
                                            clients: [client(pid: 10, nom: "Aeryn")])
        #expect(apparies.map { $0?.name } == ["Aeryn", nil, nil, nil])
    }

    @Test("Sans icône, rien")
    func sansIcone() {
        #expect(DockPairing.apparier(nombreIcones: 0, pidsVivants: [10], clients: []).isEmpty)
    }
}
