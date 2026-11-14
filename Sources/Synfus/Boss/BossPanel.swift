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
/// ce que le boss demande (`CibleBoss.lectures`) chez le perso devant — si
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
    func ouvrir(_ boss: CibleBoss? = nil) {
        // Abonné aux combats dès maintenant : le tour en cours compte.
        let aide = AideBoss.shared
        if let boss, boss != aide.boss { aide.choisir(boss) }
        // Les compteurs sont une liste fermée, partagée avec le collecteur :
        // les boss de donjon passent par l'action de la palette.
        if !ouvert, let special = aide.boss.special { UsageStore.shared.compter(.boss(special)) }
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
        let montre = PanneauxJeu.appliquer(&panel, ouvert: ouvert, impose: impose, force: force,
                                           parDefaut: Self.placeParDefaut, construire: construire)
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
        if !panel.setFrameAutosaveName("BossPanel") || panel.frame.origin == .zero {
            PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut)
        }
        return panel
    }

    /// En haut, à droite du centre de l'écran.
    private static let placeParDefaut: PanneauxJeu.PlaceParDefaut = { zone, _ in
        NSPoint(x: zone.midX + 220, y: zone.maxY - 80)
    }

    /// Le panneau ouvert reprend sa place d'origine.
    func recentrer() {
        if ouvert, let panel { PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut) }
    }
}
