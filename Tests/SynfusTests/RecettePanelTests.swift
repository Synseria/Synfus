import AppKit
import Testing
@testable import Synfus

/// Le panneau de la recette se tient par son en-tête : une recette plus longue ou plus courte le
/// fait grandir ou rétrécir vers le bas, jamais sauter.
@MainActor
struct RecettePanelTests {
    private func panneau() -> PanneauRecette {
        PanneauRecette(contentRect: NSRect(x: 100, y: 100, width: 300, height: 200),
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
