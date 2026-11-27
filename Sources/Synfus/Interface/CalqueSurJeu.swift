import AppKit
import SwiftUI

/// La fenêtre du perso devant, relevée par le serveur de fenêtres (un client
/// gelé ne fait pas attendre un calque) : son contenu et le pointeur dessus.
@MainActor
struct FenetreJeu: Equatable {
    let perso: String
    let fenetreAX: CGRect
    let pleinEcran: Bool

    static func devant() -> FenetreJeu? {
        let manager = WindowManager.shared
        guard manager.frontmostIsDofus, let client = manager.clients.first(where: manager.isFrontmost),
              let cadre = CrossSpaceTitles.cadreAffiche(pid: client.pid) else { return nil }
        return FenetreJeu(perso: client.name, fenetreAX: cadre, pleinEcran: client.pleinEcran)
    }

    /// Le contenu, sans la barre de titre, dans le repère de l'Accessibilité.
    var contenu: CGRect {
        ZoneEcran.contenuAX(fenetreAX: fenetreAX, barreTitre: GeometrieCapture.barreTitre, pleinEcran: pleinEcran)
    }

    /// Le pointeur en fraction du contenu ; `nil` hors du contenu.
    func pointeur() -> CGPoint? {
        guard let hauteur = NSScreen.screens.first?.frame.height else { return nil }
        return ZoneEcran.fraction(pointEcran: NSEvent.mouseLocation, fenetreAX: fenetreAX, hauteurPrincipale: hauteur,
                                  barreTitre: GeometrieCapture.barreTitre, pleinEcran: pleinEcran)
    }
}

/// Un calque posé exactement sur le contenu du jeu : il ne fait que dessiner —
/// `ignoresMouseEvents`, jamais clé, les clics vont au jeu. Au niveau
/// `.statusBar` comme les panneaux de jeu (`.floating` disparaît sous un espace
/// plein écran).
@MainActor
final class CalqueSurJeu {
    private var panel: NSPanel?
    private let vue: AnyView

    init(_ vue: some View) { self.vue = AnyView(vue.racineSynfus()) }

    /// Posé sur cette fenêtre, ou retiré (`nil`).
    func poser(sur fenetre: FenetreJeu?) {
        guard let fenetre, let hauteur = NSScreen.screens.first?.frame.height else {
            if let panel, panel.isVisible { panel.orderOut(nil) }
            return
        }
        let affiche = panel ?? construire()
        panel = affiche
        let cadre = ZoneEcran.cadreAppKit(fenetreAX: fenetre.fenetreAX, hauteurPrincipale: hauteur,
                                          barreTitre: GeometrieCapture.barreTitre, pleinEcran: fenetre.pleinEcran)
        if affiche.frame != cadre { affiche.setFrame(cadre, display: true) }
        if !affiche.isVisible { affiche.orderFrontRegardless() }
    }

    private func construire() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.contentView = NSHostingView(rootView: vue)
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}
