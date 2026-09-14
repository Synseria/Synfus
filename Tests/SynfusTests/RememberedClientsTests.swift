import Testing
import Foundation
import ApplicationServices
@testable import Synfus

/// Un client dans un espace plein écran inactif ne rend plus aucune fenêtre à
/// l'Accessibilité. La barre s'appuie donc sur une mémoire par processus, dont
/// la règle de fusion est isolée ici.
@MainActor
struct RememberedClientsTests {

    private func client(pid: pid_t, nom: String, index: Int = 0) -> DofusClient {
        DofusClient(
            pid: pid,
            slotKey: "\(pid)#\(index)",
            // Une référence d'application suffit : rien n'est lu dans ces tests.
            axWindow: .application(pid),
            rawTitle: "\(nom) - Feca - 3.6.8.8 - Release",
            name: nom,
            characterClass: "Feca",
            dormant: false
        )
    }

    @Test("Un perso dont la fenêtre a disparu reste affiché tant que son client vit")
    func persoConserveTantQueLeClientVit() {
        let aeryn = client(pid: 10, nom: "Aeryn")
        let brok = client(pid: 20, nom: "Brok")

        // Brok est passé sur un autre bureau : l'Accessibilité ne le rend plus.
        let resultat = ClientMemory.withRemembered(
            found: [aeryn],
            remembered: [10: [aeryn], 20: [brok]],
            silentPIDs: [20]
        )

        #expect(resultat.count == 2)
        #expect(resultat[0].name == "Aeryn")
        #expect(resultat[0].dormant == false)
        #expect(resultat[1].name == "Brok")
        #expect(resultat[1].dormant == true)
    }

    @Test("Un client fermé n'est pas ressuscité")
    func clientFermeDisparait() {
        let aeryn = client(pid: 10, nom: "Aeryn")
        let brok = client(pid: 20, nom: "Brok")

        // Le processus 20 est mort : il n'est donc pas « silencieux », il n'est
        // plus là du tout.
        let resultat = ClientMemory.withRemembered(
            found: [aeryn],
            remembered: [10: [aeryn], 20: [brok]],
            silentPIDs: []
        )

        #expect(resultat.map(\.name) == ["Aeryn"])
    }

    @Test("Un perso déconnecté ne reste pas affiché")
    func retourAuLoginOublieLePerso() {
        let aeryn = client(pid: 10, nom: "Aeryn")
        let brok = client(pid: 20, nom: "Brok")

        // Brok s'est déconnecté : sa fenêtre s'intitule de nouveau « Dofus », donc
        // aucun perso n'en ressort — mais le client, lui, répond toujours. Le
        // ressusciter afficherait un perso qui n'est plus en jeu.
        let resultat = ClientMemory.withRemembered(
            found: [aeryn],
            remembered: [10: [aeryn], 20: [brok]],
            silentPIDs: []
        )

        #expect(resultat.map(\.name) == ["Aeryn"])
    }

    @Test("Un perso de nouveau visible n'est pas dédoublé")
    func pasDeDoublonAuRetour() {
        let aeryn = client(pid: 10, nom: "Aeryn")
        let brok = client(pid: 20, nom: "Brok")

        let resultat = ClientMemory.withRemembered(
            found: [aeryn, brok],
            remembered: [10: [aeryn], 20: [brok]],
            silentPIDs: []
        )

        #expect(resultat.count == 2)
        #expect(resultat.allSatisfy { !$0.dormant })
    }

    @Test("L'ordre des persos mémorisés ne varie pas d'un rafraîchissement à l'autre")
    func ordreStable() {
        // Un dictionnaire n'a pas d'ordre : sans tri, la barre se réorganiserait
        // toutes les deux secondes.
        let memoire: [pid_t: [DofusClient]] = [
            30: [client(pid: 30, nom: "Cyd")],
            10: [client(pid: 10, nom: "Aeryn")],
            20: [client(pid: 20, nom: "Brok")],
        ]
        for _ in 0..<20 {
            let resultat = ClientMemory.withRemembered(
                found: [], remembered: memoire, silentPIDs: [10, 20, 30]
            )
            #expect(resultat.map(\.name) == ["Aeryn", "Brok", "Cyd"])
        }
    }

    @Test("Un client à plusieurs fenêtres les retrouve toutes")
    func plusieursFenetresParProcessus() {
        let premiere = client(pid: 10, nom: "Aeryn", index: 0)
        let seconde = client(pid: 10, nom: "Aeryn (2)", index: 1)

        let resultat = ClientMemory.withRemembered(
            found: [],
            remembered: [10: [premiere, seconde]],
            silentPIDs: [10]
        )

        #expect(resultat.map(\.slotKey) == ["10#0", "10#1"])
        #expect(resultat.allSatisfy { $0.dormant })
    }

    // MARK: - Découverte à travers les espaces (CGWindowList)

    private func decouverts(_ titles: [pid_t: String],
                            existants: Set<String> = []) -> [DofusClient] {
        ClientMemory.discoveredAcrossSpaces(
            titles: titles,
            existingNames: existants,
            appElement: AXHandle.application
        )
    }

    @Test("Un titre de perso sur un pid inconnu devient un dormant complet")
    func decouverteSimple() {
        let resultat = decouverts([42: "Aeryn - Feca - 3.6.8.8 - Release"])
        #expect(resultat.count == 1)
        #expect(resultat[0].name == "Aeryn")
        #expect(resultat[0].characterClass == "Feca")
        #expect(resultat[0].dormant)
        #expect(resultat[0].slotKey == "42#cg")
    }

    @Test("Un client au login vu par CGWindowList n'invente pas de perso")
    func decouverteEcarteLeLogin() {
        #expect(decouverts([42: "Dofus"]).isEmpty)
        #expect(decouverts([42: "Dofus 3.6.8.8"]).isEmpty)
    }

    @Test("Un homonyme découvert est suffixé comme ceux de l'inventaire")
    func decouverteSuffixeLesHomonymes() {
        let resultat = decouverts(
            [42: "Aeryn - Feca - 3.6.8.8 - Release"],
            existants: ["Aeryn"]
        )
        #expect(resultat.map(\.name) == ["Aeryn (2)"])
    }

    @Test("La découverte est ordonnée par pid, pas par l'ordre du dictionnaire")
    func decouverteStable() {
        let titres: [pid_t: String] = [
            30: "Ciel - Iop - 3.6.8.8 - Release",
            10: "Aeryn - Feca - 3.6.8.8 - Release",
            20: "Brok - Sacrieur - 3.6.8.8 - Release",
        ]
        #expect(decouverts(titres).map(\.name) == ["Aeryn", "Brok", "Ciel"])
    }
}
