import Testing
import AppKit
@testable import Synfus

/// La règle qui décide, sur les drapeaux d'un clic relâché, si Synfus passe
/// au perso suivant. Pure : on la nourrit de drapeaux, elle ne lit rien.
struct ClickModifierTests {

    @Test("La touche tenue, et elle seule, déclenche")
    func toucheSeule() {
        #expect(ClickModifier.fn.isHeldAlone(in: [.function]))
        #expect(ClickModifier.option.isHeldAlone(in: [.option]))
        #expect(ClickModifier.command.isHeldAlone(in: [.command]))
    }

    /// Un clic sans la touche est un clic ordinaire — c'est toute la
    /// différence avec l'ancien mode, où chaque clic nu enchaînait.
    @Test("Un clic nu ne déclenche pas")
    func clicNu() {
        for touche in ClickModifier.allCases {
            #expect(!touche.isHeldAlone(in: []))
        }
    }

    /// ⇧fn-clic ou ⌥-clic gardent le sens que le jeu leur donne : une autre
    /// touche en plus, ou à la place, et Synfus ne bouge pas.
    @Test("Une autre touche, en plus ou à la place, ne déclenche pas")
    func autreTouche() {
        #expect(!ClickModifier.fn.isHeldAlone(in: [.function, .shift]))
        #expect(!ClickModifier.fn.isHeldAlone(in: [.option]))
        #expect(!ClickModifier.option.isHeldAlone(in: [.option, .command]))
    }

    /// Le verrouillage des majuscules est un état, pas un doigt posé : un
    /// joueur qui l'a laissé enclenché ne perd pas la fonction. Les drapeaux
    /// propres aux touches (pavé numérique, aide) n'ont rien à voir avec la
    /// souris et sont ignorés de même.
    @Test("Les drapeaux d'état sont ignorés")
    func drapeauxDEtat() {
        #expect(ClickModifier.fn.isHeldAlone(in: [.function, .capsLock]))
        #expect(ClickModifier.fn.isHeldAlone(in: [.function, .numericPad, .help]))
    }

    @Test("Le diagnostic nomme les touches tenues")
    func diagnostic() {
        #expect(ClickModifier.describe([]) == "aucune")
        #expect(ClickModifier.describe([.function]) == "fn")
        #expect(ClickModifier.describe([.shift, .command]) == "⇧⌘")
        #expect(ClickModifier.describe([.capsLock]) == "aucune")
    }
}
