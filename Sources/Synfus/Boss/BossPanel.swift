import AppKit
import SwiftUI

/// Jamais clé : en combat, la frappe va aux raccourcis de sorts du jeu, et un
/// clic sur le panneau (un coup compté, une confusion choisie) ne la lui
/// retire pas.
private final class PanneauBoss: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Le panneau d'aide aux boss, posé sur le jeu : la mécanique du boss choisi
/// et le tour du combat. Montré, il fait lire au tour le combat, et en combat
/// ce que le boss demande (`Boss.lectures`) chez le perso devant — si
/// l'enregistrement de l'écran est déjà permis, jamais il ne le demande de
/// lui-même. Comme les quêtes, il ne se montre que
/// devant Dofus (`PanneauxJeu`) ; AppKit garde sa position.
@MainActor
final class BossPanel: NSObject, ObservableObject {
    static let shared = BossPanel()

    /// Voulu ouvert, qu'il soit à l'écran ou caché derrière une autre app.
    @Published private(set) var ouvert = false
    /// Ouvert depuis une autre app que Dofus (menu, réglages) : il reste là
    /// jusqu'au prochain changement d'app.
    private var impose = false
    private var panel: NSPanel?

    private override init() { super.init() }

    func basculer() {
        ouvert ? fermer() : ouvrir()
    }

    /// Sur ce boss, s'il est donné ; sur le dernier choisi sinon.
    func ouvrir(_ boss: Boss? = nil) {
        // Abonné aux combats dès maintenant : le tour en cours compte.
        let aide = AideBoss.shared
        if let boss, boss != aide.boss { aide.choisir(boss) }
        if !ouvert { UsageStore.shared.compter(.boss(aide.boss)) }
        ouvert = true
        impose = true
        appliquer(force: true)
    }

    func fermer() {
        ouvert = false
        appliquer(force: false)
    }

    func revoirVisibilite(force: Bool) {
        if force { impose = false }
        appliquer(force: force)
    }

    /// Le boss a changé : ce qui se lit aussi.
    func revoirLectures() { appliquer(force: false) }

    private func appliquer(force: Bool) {
        let montre = PanneauxJeu.appliquer(&panel, ouvert: ouvert, impose: impose, force: force, construire: construire)
        LecteurEcran.shared.suivreBoss(montre && WindowPreviewService.shared.authorized ? AideBoss.shared.boss.lectures : nil)
    }

    private func construire() -> NSPanel {
        let hosting = NSHostingController(rootView: BossVue().racineSynfus())
        hosting.sizingOptions = [.preferredContentSize]
        let panel = PanneauBoss(
            contentRect: NSRect(x: 0, y: 0, width: BossVue.largeur, height: 300),
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
        if !panel.setFrameAutosaveName("BossPanel") || panel.frame.origin == .zero, let ecran = NSScreen.main?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: ecran.midX + 220, y: ecran.maxY - 80))
        }
        return panel
    }
}
