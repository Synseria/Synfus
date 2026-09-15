import Testing
import ApplicationServices
@testable import Synfus

/// Les équipes sont une appartenance, pas un ordre : l'effectif garde l'ordre
/// de la barre, et seuls les vrais noms de persos peuvent en faire partie.
@MainActor
struct EquipesTests {

    private func client(pid: pid_t, nom: String) -> DofusClient {
        DofusClient(
            pid: pid, slotKey: "\(pid)#0",
            axWindow: .application(pid),
            rawTitle: "\(nom) - Feca - 3.6.8.8 - Release",
            name: nom, characterClass: "Feca", dormant: false
        )
    }

    private let trois = [Equipe(membres: ["Amarine"]), Equipe(membres: ["Bram", "Cob"])]

    @Test("Sans équipe active, l'effectif est la liste entière")
    func sansEquipe() {
        let clients = [client(pid: 1, nom: "Amarine"), client(pid: 2, nom: "Bram")]
        #expect(Equipes.filtre(clients, equipe: nil) == clients)
    }

    @Test("L'effectif garde l'ordre de la liste, pas celui des membres")
    func ordreDeLaListe() {
        let clients = [client(pid: 1, nom: "Amarine"), client(pid: 2, nom: "Bram"), client(pid: 3, nom: "Cob")]
        let filtre = Equipes.filtre(clients, equipe: Equipe(membres: ["Cob", "Amarine"]))
        #expect(filtre.map(\.name) == ["Amarine", "Cob"])
    }

    @Test("Un homonyme suffixé et un client au login n'entrent dans aucune équipe")
    func nomsNonPersistables() {
        #expect(Equipes.affecter("Bram (2)", a: 0, dans: trois) == trois)
        #expect(Equipes.affecter("Dofus 3.3.4.9", a: 2, dans: trois) == trois)
    }

    @Test("Affecter retire le perso de son ancienne équipe")
    func changementDEquipe() {
        let apres = Equipes.affecter("Cob", a: 0, dans: trois)
        #expect(apres == [Equipe(membres: ["Amarine", "Cob"]), Equipe(membres: ["Bram"])])
    }

    @Test("Affecter à `count` crée une équipe, jamais au-delà de quatre")
    func creation() {
        let quatre = Equipes.affecter("Zoé", a: 2, dans: trois)
        #expect(quatre.count == 3)
        #expect(quatre[2].membres == ["Zoé"])

        var pleines = (0..<Equipes.maximum).map { Equipe(membres: ["P\($0)"]) }
        pleines = Equipes.affecter("Zoé", a: Equipes.maximum, dans: pleines)
        #expect(pleines.count == Equipes.maximum)
        #expect(!pleines.contains { $0.membres.contains("Zoé") })
    }

    @Test("Un index au-delà de `count` laisse tout inchangé")
    func indexHorsPortee() {
        #expect(Equipes.affecter("Zoé", a: 3, dans: trois) == trois)
        #expect(Equipes.affecter("Zoé", a: -1, dans: trois) == trois)
    }

    @Test("Une équipe vidée disparaît, les suivantes remontent")
    func equipeVidee() {
        let apres = Equipes.affecter("Amarine", a: 1, dans: trois)
        #expect(apres == [Equipe(membres: ["Bram", "Cob", "Amarine"])])
    }

    @Test("`nil` retire de toute équipe")
    func retrait() {
        let apres = Equipes.affecter("Bram", a: nil, dans: trois)
        #expect(apres == [Equipe(membres: ["Amarine"]), Equipe(membres: ["Cob"])])
        // Un nom absent ne change rien.
        #expect(Equipes.affecter("Zoé", a: nil, dans: trois) == trois)
    }

    @Test("`restreintes` oublie les noms disparus")
    func restreintes() {
        let apres = Equipes.restreintes(trois, aux: ["Bram"])
        #expect(apres == [Equipe(membres: ["Bram"])])
        #expect(Equipes.indexEquipe(de: "Bram", dans: trois) == 1)
        #expect(Equipes.indexEquipe(de: "Zoé", dans: trois) == nil)
    }

    @Test("`suivante` tourne Tous → 1 → 2 → Tous, et reste sur Tous sans équipe")
    func rotation() {
        #expect(Equipes.suivante(apres: nil, nombre: 2) == 0)
        #expect(Equipes.suivante(apres: 0, nombre: 2) == 1)
        #expect(Equipes.suivante(apres: 1, nombre: 2) == nil)
        #expect(Equipes.suivante(apres: nil, nombre: 0) == nil)
    }

    @Test("`activeValide` ramène à Tous un index devenu orphelin")
    func activeValide() {
        #expect(Equipes.activeValide(1, nombre: 2) == 1)
        #expect(Equipes.activeValide(2, nombre: 2) == nil)
        #expect(Equipes.activeValide(nil, nombre: 2) == nil)
    }
}
