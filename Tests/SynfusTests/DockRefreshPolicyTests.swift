import Testing
@testable import Synfus

/// La politique de rafraîchissement est pure : c'est elle qui décide combien
/// coûte chaque tour de la détection d'attention.
struct DockRefreshPolicyTests {

    @Test("Sans structure en cache, le premier tour est complet")
    func premierTour() {
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: nil, dofusProcesses: 0, age: .infinity))
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: nil, dofusProcesses: 3, age: 0))
    }

    @Test("En régime permanent, le tour reste léger")
    func regimePermanent() {
        #expect(!DockRefreshPolicy.needsFullTour(cachedItems: 3, dofusProcesses: 3, age: 0.1))
        #expect(!DockRefreshPolicy.needsFullTour(cachedItems: 3, dofusProcesses: 3, age: 1.9))
    }

    @Test("Un client lancé ou fermé périme la structure sans attendre le filet")
    func effectifChange() {
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 3, dofusProcesses: 4, age: 0.1))
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 3, dofusProcesses: 2, age: 0.1))
    }

    @Test("Le filet des deux secondes redécouvre même sans autre signal")
    func filet() {
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 3, dofusProcesses: 3, age: 2))
        #expect(DockRefreshPolicy.needsFullTour(cachedItems: 3, dofusProcesses: 3, age: 0.5, maxAge: 0.5))
    }

    @Test("Un cache vide face à zéro processus reste léger")
    func cacheVide() {
        // Le watcher sort avant d'interroger le Dock sans perso ; si on y arrive
        // tout de même, rien n'oblige à refaire la découverte.
        #expect(!DockRefreshPolicy.needsFullTour(cachedItems: 0, dofusProcesses: 0, age: 0))
    }
}
