import AppKit
import Testing
@testable import Synfus

/// Un panneau posé sur le jeu (recette, boss) se tient par son en-tête : un contenu plus long ou plus
/// court le fait grandir ou rétrécir vers le bas, jamais sauter.
@MainActor
struct PanneauDeJeuTests {
    private func panneau() -> PanneauDeJeu {
        PanneauDeJeu(contentRect: NSRect(x: 100, y: 100, width: 300, height: 200),
                       styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    }

    @Test func leHautResteQuandLaHauteurChange() {
        let panel = panneau()
        let haut = panel.frame.maxY
        panel.setContentSize(NSSize(width: 300, height: 420))
        #expect(panel.frame.maxY == haut)
        #expect(panel.frame.height == 420)
        panel.setContentSize(NSSize(width: 300, height: 120))
        #expect(panel.frame.maxY == haut)
    }

    @Test func unDeplacementPasseTelQuel() {
        let panel = panneau()
        panel.setFrame(NSRect(x: 40, y: 60, width: 300, height: 250), display: false)
        #expect(panel.frame == NSRect(x: 40, y: 60, width: 300, height: 250))
    }
}
