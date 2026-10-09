import Foundation
import Testing
@testable import Synfus

/// La politique de rafraîchissement est pure : c'est elle qui décide combien
/// coûte chaque tour de la détection d'attention.
struct DockRefreshPolicyTests {
    private let trois: Set<pid_t> = [101, 102, 103]

    @Test("Sans structure en cache, le premier tour est complet")
    func premierTour() {
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: nil, builtFor: [], pids: [], age: .infinity))
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: nil, builtFor: [], pids: trois, age: 0))
    }

    @Test("En régime permanent, le tour reste léger jusqu'au filet")
    func regimePermanent() {
        #expect(!DockRefreshPolicy.needsFullTour(cachedItems: 3, builtFor: trois, pids: trois, age: 0.1))
        #expect(!DockRefreshPolicy.needsFullTour(cachedItems: 3, builtFor: trois, pids: trois, age: 29.9))
    }

    @Test("Un client lancé ou fermé périme la structure sans attendre le filet")
    func effectifChange() {
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 3, builtFor: trois, pids: trois.union([104]), age: 0.1))
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 3, builtFor: trois, pids: [101, 102], age: 0.1))
    }

    @Test("Un client remplacé par un autre périme la structure, à effectif égal")
    func clientRemplace() {
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 3, builtFor: trois, pids: [101, 102, 104], age: 0.1))
    }

    @Test("Une structure incomplète se retente chaque seconde, pas à chaque tour")
    func incomplete() {
        // Un client qui se lance : son processus est connu, son icône pas encore « lancée ».
        #expect(!DockRefreshPolicy.needsFullTour(cachedItems: 2, builtFor: trois, pids: trois, age: 0.5))
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 2, builtFor: trois, pids: trois,
                                                age: DockRefreshPolicy.incompleteRetry))
    }

    @Test("Le filet redécouvre même sans autre signal")
    func filet() {
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 3, builtFor: trois, pids: trois,
                                                age: DockRefreshPolicy.maxAge))
    }

    @Test("Un cache vide face à zéro processus reste léger")
    func cacheVide() {
        // Le watcher ne tourne pas sans perso ; si on y arrive tout de même,
        // rien n'oblige à refaire la découverte.
        #expect(!DockRefreshPolicy.needsFullTour(cachedItems: 0, builtFor: [], pids: [], age: 0))
    }

    @Test("Le Dock n'est veillé qu'avec un perso et une suite à donner")
    func armement() {
        #expect(!AttentionAction.ignore.veilleLeDock(persos: 3))
        #expect(!AttentionAction.highlight.veilleLeDock(persos: 0))
        #expect(!AttentionAction.focus.veilleLeDock(persos: 0))
        #expect(AttentionAction.highlight.veilleLeDock(persos: 1))
        #expect(AttentionAction.focus.veilleLeDock(persos: 2))
    }
}
