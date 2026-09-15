import Testing
import ApplicationServices
@testable import Synfus

/// Ce qui part dans le presse-papiers : les noms du titre, sans le chef, en
/// boucle — et jamais rien vers le jeu.
@MainActor
struct InvitationComposerTests {

    private func client(pid: pid_t, nom: String, titre: String? = nil, dormant: Bool = false) -> DofusClient {
        DofusClient(
            pid: pid, slotKey: "\(pid)#0",
            axWindow: .application(pid),
            rawTitle: titre ?? "\(nom) - Feca - 3.6.8.8 - Release",
            name: nom, characterClass: "Feca", dormant: dormant
        )
    }

    @Test("Le chef n'est jamais invité")
    func chefExclu() {
        let effectif = [client(pid: 1, nom: "Aeryn"), client(pid: 2, nom: "Brok"), client(pid: 3, nom: "Cid")]
        #expect(InvitationComposer.candidats(effectif, chefPID: 2) == ["Aeryn", "Cid"])
        // Sans chef — Synfus devant —, tout le monde est candidat.
        #expect(InvitationComposer.candidats(effectif, chefPID: nil) == ["Aeryn", "Brok", "Cid"])
    }

    @Test("Deux homonymes donnent une seule invitation, au nom brut")
    func homonymes() {
        let effectif = [client(pid: 1, nom: "Brok"), client(pid: 2, nom: "Brok (2)")]
        #expect(InvitationComposer.candidats(effectif, chefPID: nil) == ["Brok"])
    }

    @Test("Un client au login n'est pas un candidat, un dormant l'est")
    func loginEtDormant() {
        let effectif = [
            client(pid: 1, nom: "Dofus 3.3.4.9", titre: "Dofus - 3.3.4.9 - Release"),
            client(pid: 2, nom: "Aeryn", dormant: true),
        ]
        #expect(InvitationComposer.candidats(effectif, chefPID: nil) == ["Aeryn"])
    }

    @Test("Le format remplace %nom, et un format sans jeton ajoute le nom")
    func format() {
        #expect(InvitationComposer.commande(format: "/invite %nom", nom: "Aeryn") == "/invite Aeryn")
        #expect(InvitationComposer.commande(format: "/w %nom coucou", nom: "Aeryn") == "/w Aeryn coucou")
        #expect(InvitationComposer.commande(format: "/invite ", nom: "Aeryn") == "/invite Aeryn")
    }

    @Test("Les appuis successifs tournent en boucle")
    func boucle() {
        let noms = ["Brok", "Cid"]
        let premier = InvitationComposer.prochaine(candidats: noms, precedents: [], curseur: nil)
        #expect(premier?.nom == "Brok")
        let second = InvitationComposer.prochaine(candidats: noms, precedents: noms, curseur: premier?.curseur)
        #expect(second?.nom == "Cid")
        let troisieme = InvitationComposer.prochaine(candidats: noms, precedents: noms, curseur: second?.curseur)
        #expect(troisieme?.nom == "Brok")
    }

    @Test("Le curseur repart de zéro quand la liste change")
    func listeChangee() {
        let apres = InvitationComposer.prochaine(candidats: ["Aeryn", "Cid"], precedents: ["Brok", "Cid"], curseur: 1)
        #expect(apres?.nom == "Aeryn")
        #expect(apres?.curseur == 0)
    }

    @Test("Le tour est fait au dernier candidat copié")
    func finDeTour() {
        #expect(InvitationComposer.tourTermine(curseur: 0, nombre: 3) == false)
        #expect(InvitationComposer.tourTermine(curseur: 2, nombre: 3) == true)
        #expect(InvitationComposer.tourTermine(curseur: 0, nombre: 1) == true)
    }

    @Test("Sans candidat, rien")
    func vide() {
        #expect(InvitationComposer.prochaine(candidats: [], precedents: [], curseur: nil) == nil)
    }
}
