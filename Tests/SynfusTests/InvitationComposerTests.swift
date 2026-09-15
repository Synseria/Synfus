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
        let effectif = [client(pid: 1, nom: "Amarine"), client(pid: 2, nom: "Bram"), client(pid: 3, nom: "Cob")]
        #expect(InvitationComposer.candidats(effectif, chefPID: 2) == ["Amarine", "Cob"])
        // Sans chef — Synfus devant —, tout le monde est candidat.
        #expect(InvitationComposer.candidats(effectif, chefPID: nil) == ["Amarine", "Bram", "Cob"])
    }

    @Test("Deux homonymes donnent une seule invitation, au nom brut")
    func homonymes() {
        let effectif = [client(pid: 1, nom: "Bram"), client(pid: 2, nom: "Bram (2)")]
        #expect(InvitationComposer.candidats(effectif, chefPID: nil) == ["Bram"])
    }

    @Test("Un client au login n'est pas un candidat, un dormant l'est")
    func loginEtDormant() {
        let effectif = [
            client(pid: 1, nom: "Dofus 3.3.4.9", titre: "Dofus - 3.3.4.9 - Release"),
            client(pid: 2, nom: "Amarine", dormant: true),
        ]
        #expect(InvitationComposer.candidats(effectif, chefPID: nil) == ["Amarine"])
    }

    @Test("Le format remplace %nom, et un format sans jeton ajoute le nom")
    func format() {
        #expect(InvitationComposer.commande(format: "/invite %nom", nom: "Amarine") == "/invite Amarine")
        #expect(InvitationComposer.commande(format: "/w %nom coucou", nom: "Amarine") == "/w Amarine coucou")
        #expect(InvitationComposer.commande(format: "/invite ", nom: "Amarine") == "/invite Amarine")
    }

    @Test("Les appuis successifs tournent en boucle")
    func boucle() {
        let noms = ["Bram", "Cob"]
        let premier = InvitationComposer.prochaine(candidats: noms, precedents: [], curseur: nil)
        #expect(premier?.nom == "Bram")
        let second = InvitationComposer.prochaine(candidats: noms, precedents: noms, curseur: premier?.curseur)
        #expect(second?.nom == "Cob")
        let troisieme = InvitationComposer.prochaine(candidats: noms, precedents: noms, curseur: second?.curseur)
        #expect(troisieme?.nom == "Bram")
    }

    @Test("Le curseur repart de zéro quand la liste change")
    func listeChangee() {
        let apres = InvitationComposer.prochaine(candidats: ["Amarine", "Cob"], precedents: ["Bram", "Cob"], curseur: 1)
        #expect(apres?.nom == "Amarine")
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
