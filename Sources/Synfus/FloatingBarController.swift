import AppKit
import SwiftUI

/// Panneau qui reste au-dessus du jeu sans jamais lui prendre le focus.
private final class BarPanel: NSPanel {
    // Un overlay de jeu ne doit jamais capter le clavier : ce qui est tapé pendant
    // une partie doit toujours arriver à Dofus, même si la barre est sous la souris.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingBarController: NSObject {
    static let shared = FloatingBarController()

    private var panel: NSPanel?
    /// Distingue un repositionnement automatique d'un déplacement à la souris :
    /// sans ce drapeau, chaque recentrage se prendrait pour un geste utilisateur
    /// et désactiverait aussitôt le centrage automatique.
    private var repositioning = false

    private override init() { super.init() }

    /// Cadre de la barre à l'écran, si elle est affichée — sert à placer la
    /// fenêtre de réglages juste en dessous.
    var visibleBarFrame: NSRect? {
        guard let panel, panel.isVisible else { return nil }
        return panel.frame
    }

    func apply() {
        Preferences.shared.barVisible ? show() : hide()
    }

    func toggle() {
        Preferences.shared.barVisible.toggle()
        apply()
    }

    func show() {
        if panel == nil { build() }
        guard shouldBeVisible else {
            panel?.orderOut(nil)
            return
        }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// La barre peut être réservée aux moments où Dofus est devant. Synfus
    /// compte comme « devant » : sans ça, ouvrir les réglages ferait disparaître
    /// la barre que l'on est en train de configurer.
    ///
    /// La décision se prend sur l'état déjà tenu par `WindowManager`, et non en
    /// interrogeant `NSWorkspace` : au moment où l'on apprend qu'une application
    /// vient de passer devant, `frontmostApplication` désigne encore la
    /// précédente, et la barre décidait donc avec un tour de retard.
    private var shouldBeVisible: Bool {
        Self.computeVisibility(
            barVisible: Preferences.shared.barVisible,
            onlyWithDofus: Preferences.shared.barOnlyWithDofus,
            frontPID: WindowManager.shared.frontmostPID,
            frontIsDofus: WindowManager.shared.frontmostIsDofus,
            ownPID: ProcessInfo.processInfo.processIdentifier
        )
    }

    static func computeVisibility(
        barVisible: Bool,
        onlyWithDofus: Bool,
        frontPID: pid_t?,
        frontIsDofus: Bool,
        ownPID: pid_t
    ) -> Bool {
        guard barVisible else { return false }
        guard onlyWithDofus else { return true }
        guard let frontPID else { return false }
        return frontPID == ownPID || frontIsDofus
    }

    /// Appelé à chaque changement d'application active.
    func updateVisibility() {
        guard panel != nil else { return }
        shouldBeVisible ? panel?.orderFrontRegardless() : panel?.orderOut(nil)
    }

    private func build() {
        let hosting = NSHostingController(rootView: BarView())
        hosting.sizingOptions = [.preferredContentSize]

        let panel = BarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 40),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        // `.floating` passe *sous* une app en plein écran : l'espace plein écran
        // héberge sa fenêtre à un niveau propre, et la barre y disparaissait. Le
        // niveau de la barre de menus est celui des overlays qui doivent rester
        // lisibles par-dessus un jeu, sans monter jusqu'aux alertes système.
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        // Le déplacement est confié à `performDrag(with:)` depuis la vue, ce qui
        // donne un suivi parfaitement fluide sans capter les clics sur les persos.
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .none
        // Suit l'utilisateur d'un bureau à l'autre et survit au plein écran d'une
        // autre app, sans apparaître dans Mission Control comme une vraie fenêtre.
        // `.stationary` est délibérément absent : il demande de ne pas participer
        // aux transitions d'espace, ce qui brouille le suivi lors d'un passage en
        // plein écran.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        self.panel = panel
        restorePosition()

        NotificationCenter.default.addObserver(
            self, selector: #selector(panelMoved),
            name: NSWindow.didMoveNotification, object: panel
        )
        // La barre change de largeur dès qu'un perso se connecte ou se déconnecte ;
        // il faut la recentrer sur la nouvelle largeur, sinon elle dérive.
        NotificationCenter.default.addObserver(
            self, selector: #selector(panelResized),
            name: NSWindow.didResizeNotification, object: panel
        )
    }

    private func restorePosition() {
        if Preferences.shared.autoCenterBar {
            centerAtTop()
        } else if let origin = Preferences.shared.barOrigin, isOnScreen(origin) {
            panel?.setFrameOrigin(origin)
        } else {
            centerAtTop()
        }
    }

    /// Centre la barre sur l'écran et la colle sous la barre de menus.
    ///
    /// Le centrage se fait sur `frame` (l'écran physique) et non sur
    /// `visibleFrame` : c'est ce qui la met d'aplomb sous l'encoche, alors qu'un
    /// Dock placé sur un côté décalerait `visibleFrame` et donc la barre.
    func centerAtTop() {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let size = panel.frame.size
        // Sur un espace plein écran la barre de menus est masquée, `visibleFrame`
        // rejoint donc `frame` et la barre se colle au bord haut — là où la barre
        // de menus se déploie au survol et la recouvre. Une marge l'en dégage.
        let menuBarHidden = screen.visibleFrame.maxY >= screen.frame.maxY - 1
        let top = screen.visibleFrame.maxY - (menuBarHidden ? Self.fullScreenTopInset : 0)
        let origin = CGPoint(
            x: (screen.frame.midX - size.width / 2).rounded(),
            y: (top - size.height).rounded()
        )
        reposition(to: origin)
    }

    /// Marge sous le bord haut quand la barre de menus est masquée.
    private static let fullScreenTopInset: CGFloat = 6

    /// Convertit un cadre exprimé dans le repère de la barre — celui de SwiftUI,
    /// origine en haut à gauche — en coordonnées écran, où l'ordonnée monte.
    func screenFrame(fromBarFrame rect: CGRect) -> CGRect? {
        guard let panel, panel.isVisible else { return nil }
        return CGRect(
            x: panel.frame.minX + rect.minX,
            y: panel.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func reposition(to origin: CGPoint) {
        repositioning = true
        panel?.setFrameOrigin(origin)
        // `didMove` peut arriver au tour de boucle suivant : on ne relâche le
        // drapeau qu'une fois la notification passée.
        DispatchQueue.main.async { self.repositioning = false }
    }

    /// Évite de restaurer la barre sur un écran débranché depuis.
    private func isOnScreen(_ origin: CGPoint) -> Bool {
        NSScreen.screens.contains { $0.frame.insetBy(dx: -40, dy: -40).contains(origin) }
    }

    @objc private func panelMoved() {
        guard !repositioning, let panel else { return }
        // Déplacement à la souris : on mémorise la position et on cesse de recentrer.
        Preferences.shared.barOrigin = panel.frame.origin
        Preferences.shared.autoCenterBar = false
    }

    @objc private func panelResized() {
        guard Preferences.shared.autoCenterBar else { return }
        centerAtTop()
    }

    /// Remet la barre au centre et réactive le suivi automatique.
    func recenter() {
        Preferences.shared.autoCenterBar = true
        centerAtTop()
    }

    /// Ramène la barre au premier plan après une bascule au clavier, pour que le
    /// changement d'état du bouton soit visible même si Dofus est plein écran.
    func flashAutoFocusState() {
        guard shouldBeVisible else { return }
        panel?.orderFrontRegardless()
    }
}
