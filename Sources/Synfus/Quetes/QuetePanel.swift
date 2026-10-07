import AppKit
import SwiftUI

/// Le panneau des quêtes épinglées : transparent, au-dessus du jeu, qui ne
/// prend jamais le clavier (un clic ne retire pas la frappe à Dofus) — on le
/// garde ouvert en jouant. Plusieurs quêtes, une par onglet ; on le déplace
/// par son en-tête et on le redimensionne par ses bords, AppKit garde le
/// cadre (`frameAutosaveName`).
@MainActor
final class QuetePanel: NSObject, ObservableObject {
    static let shared = QuetePanel()

    /// La quête montrée parmi les épinglées.
    @Published private(set) var montree: Int?
    private var panel: NSPanel?

    private override init() { super.init() }

    /// Épingle la quête (si elle ne l'est pas) et la montre.
    func ouvrir(_ id: Int) {
        let prefs = Preferences.shared
        if !prefs.quetesEpinglees.contains(id) { prefs.quetesEpinglees.append(id) }
        montree = id
        (panel ?? construire()).orderFrontRegardless()
    }

    func montrer(_ id: Int) { montree = id }

    /// Retire l'onglet ; le panneau se ferme avec le dernier.
    func desepingler(_ id: Int) {
        let prefs = Preferences.shared
        prefs.quetesEpinglees.removeAll { $0 == id }
        if montree == id { montree = prefs.quetesEpinglees.last }
        if prefs.quetesEpinglees.isEmpty { fermer() }
    }

    /// Cache le panneau ; les quêtes restent épinglées pour la prochaine fois.
    func fermer() {
        panel?.orderOut(nil)
    }

    private func construire() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: QueteVue())
        panel.minSize = NSSize(width: 280, height: 200)
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
            panel.setFrameTopLeftPoint(NSPoint(x: ecran.maxX - 384, y: ecran.maxY - 80))
        }
        self.panel = panel
        return panel
    }
}
