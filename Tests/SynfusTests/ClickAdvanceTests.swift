import Testing
@testable import Synfus

/// La coche qui suit l'enchaînement des persos est une règle à part entière :
/// elle décide de ce que la barre montre, et se teste sans fenêtre ni clic.
@MainActor
struct ClickAdvanceTests {

    private let tous: Set<String> = ["10#0", "20#0", "30#0"]

    private func suivant(_ visites: Set<String>, quitte: String) -> Set<String> {
        ClickAdvanceWatcher.nextVisited(visites, leaving: quitte, among: tous)
    }

    @Test("Le perso que l'on quitte est coché")
    func premierPasse() {
        #expect(suivant([], quitte: "10#0") == ["10#0"])
    }

    @Test("Les coches s'accumulent le long de la passe")
    func passeEnCours() {
        var visites = suivant([], quitte: "10#0")
        visites = suivant(visites, quitte: "20#0")
        #expect(visites == ["10#0", "20#0"])
    }

    /// Une coche qui ne s'efface jamais ne renseigne plus sur rien : la passe
    /// suivante repart d'une barre vide.
    @Test("Une fois tout le monde coché, le clic suivant ouvre une passe neuve")
    func passeSuivante() {
        let complet: Set<String> = ["10#0", "20#0", "30#0"]
        #expect(suivant(complet, quitte: "10#0") == ["10#0"])
    }

    /// Une passe entamée à cinq persos ne doit pas rester éternellement
    /// inachevée parce que deux clients ont été fermés depuis.
    @Test("Un perso fermé ne bloque pas la passe")
    func persoFerme() {
        let heritees: Set<String> = ["10#0", "20#0", "99#0"]
        let apres = suivant(heritees, quitte: "30#0")
        #expect(!apres.contains("99#0"))
        #expect(apres == ["10#0", "20#0", "30#0"])
    }

    @Test("Recocher le perso courant ne change rien")
    func idempotent() {
        let visites = suivant([], quitte: "10#0")
        #expect(suivant(visites, quitte: "10#0") == ["10#0"])
    }
}
