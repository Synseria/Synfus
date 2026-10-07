import AppKit
import SwiftUI

/// Le panneau d'une quête : transparent, au-dessus du jeu, qui ne prend
/// jamais le clavier (un clic ne retire pas la frappe à Dofus) — on le garde
/// ouvert en jouant, un clic copie un trajet ou une ressource. Sa position
/// est gardée par AppKit (`frameAutosaveName`).
@MainActor
final class QuetePanel: NSObject, ObservableObject {
    static let shared = QuetePanel()

    @Published private(set) var queteID: Int?
    private var panel: NSPanel?

    private override init() { super.init() }

    func ouvrir(_ id: Int) {
        queteID = id
        let panel = panel ?? construire()
        panel.orderFrontRegardless()
    }

    func fermer() {
        panel?.orderOut(nil)
        queteID = nil
    }

    private func construire() -> NSPanel {
        let hosting = NSHostingController(rootView: QueteVue())
        hosting.sizingOptions = [.preferredContentSize]
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: QueteVue.largeur, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if !panel.setFrameAutosaveName("QuetePanel") || panel.frame.origin == .zero,
           let ecran = NSScreen.main?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: ecran.maxX - QueteVue.largeur - 24, y: ecran.maxY - 80))
        }
        self.panel = panel
        return panel
    }
}
