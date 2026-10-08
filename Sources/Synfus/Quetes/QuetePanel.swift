import AppKit
import SwiftUI

/// Un panneau qui ne devient jamais clé : un clic ne retire pas la frappe à
/// Dofus. Fenêtre à titre (barre transparente, sans boutons) pour les bords
/// de redimensionnement du système, plus larges que ceux d'un panneau sans
/// bordure et suivis même quand Synfus n'est pas l'app active.
private final class PanneauQuetes: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Le panneau des quêtes épinglées : transparent, au-dessus du jeu — on le
/// garde ouvert en jouant. Plusieurs quêtes, une par onglet ; on le déplace
/// par toute sa bande d'onglets et on le redimensionne par ses bords ou sa
/// poignée, AppKit garde le cadre (`frameAutosaveName`). Ouvert, il ne se
/// montre que devant Dofus (ou Synfus), comme la barre réservée au jeu.
@MainActor
final class QuetePanel: NSObject, ObservableObject {
    static let shared = QuetePanel()

    /// La quête montrée parmi les épinglées.
    @Published private(set) var montree: Int?
    /// Voulu ouvert, qu'il soit à l'écran ou caché derrière une autre app.
    @Published private(set) var ouvert = false
    /// Ouvert depuis une autre app que Dofus (bouton de la barre, menu) : il
    /// reste là jusqu'au prochain changement d'app plutôt que de ne pas
    /// apparaître du tout.
    private var impose = false
    private var panel: NSPanel?

    private override init() { super.init() }

    func basculer() {
        ouvert ? fermer() : ouvrir()
    }

    /// Montre le panneau, sur la quête en cours ; sans quête épinglée, il
    /// invite à en chercher une.
    func ouvrir() {
        ouvert = true
        impose = true
        appliquer(force: true)
    }

    /// Épingle la quête (si elle ne l'est pas) et la montre.
    func ouvrir(_ id: Int) {
        let prefs = Preferences.shared
        if !prefs.quetesEpinglees.contains(id) { prefs.quetesEpinglees.append(id) }
        montree = id
        ouvrir()
    }

    func montrer(_ id: Int) { montree = id }

    /// Coche ou décoche un objectif ; les coches sont gardées par quête.
    func cocher(_ objectif: Int, de quete: Int, _ valide: Bool) {
        let prefs = Preferences.shared
        let avant = prefs.quetesValides[String(quete)] ?? []
        guard avant.contains(objectif) != valide else { return }
        let apres = valide ? avant + [objectif] : avant.filter { $0 != objectif }
        prefs.quetesValides[String(quete)] = apres.isEmpty ? nil : apres
    }

    /// Retire l'onglet ; le panneau se ferme avec le dernier.
    func desepingler(_ id: Int) {
        let prefs = Preferences.shared
        prefs.quetesEpinglees.removeAll { $0 == id }
        if montree == id { montree = prefs.quetesEpinglees.last }
        if prefs.quetesEpinglees.isEmpty { fermer() }
    }

    /// Cache le panneau ; les quêtes restent épinglées pour la prochaine fois.
    func fermer() {
        ouvert = false
        cacher()
    }

    /// À chaque changement d'app active (`force`) et par le filet de
    /// `WindowManager` : la règle de la barre réservée à Dofus, sur
    /// `frontmostPID` — `NSWorkspace` a un tour de retard.
    func revoirVisibilite(force: Bool) {
        if force { impose = false }
        appliquer(force: force)
    }

    private func appliquer(force: Bool) {
        let devant = FloatingBarController.computeVisibility(
            barVisible: ouvert, onlyWithDofus: true,
            frontPID: WindowManager.shared.frontmostPID, frontIsDofus: WindowManager.shared.frontmostIsDofus,
            ownPID: ProcessInfo.processInfo.processIdentifier)
        if devant || (ouvert && impose) {
            let panel = panel ?? construire()
            if force || !panel.isVisible { panel.orderFrontRegardless() }
        } else if panel?.isVisible == true {
            cacher()
        }
    }

    /// Le cadre à l'écran, pour placer la vue agrandie d'une carte à côté.
    var cadre: NSRect? { panel?.isVisible == true ? panel?.frame : nil }

    private func cacher() {
        panel?.orderOut(nil)
        ApercuCarte.shared.cacher()
    }

    private func construire() -> NSPanel {
        let panel = PanneauQuetes(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .fullSizeContentView, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        for bouton in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(bouton)?.isHidden = true
        }
        // La vue couvre aussi la barre de titre, invisible : elle n'en garde
        // pas la marge.
        panel.contentView = NSHostingView(rootView: QueteVue().ignoresSafeArea())
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

/// La poignée du coin bas droit : un glisser agrandit le panneau, son coin
/// haut gauche ne bouge pas. Une boucle d'évènements à soi plutôt que les
/// bords du système, qu'un coin de quelques points rend difficiles à saisir.
struct PoigneeRedimension: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView { Poignee() }
    func updateNSView(_: NSView, context _: Context) {}

    private final class Poignee: NSView {
        override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }

        // Le panneau n'est jamais clé et Synfus n'est pas l'app active : ni
        // `cursorRects` ni `cursorUpdate`, une zone de suivi qui pose le
        // curseur elle-même (cf. `WindowDragArea`).
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            addTrackingArea(NSTrackingArea(rect: bounds,
                                           options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                           owner: self, userInfo: nil))
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { CurseurArrierePlan.autoriser() }
        }

        private var curseur: NSCursor {
            if #available(macOS 15.0, *) { return .frameResize(position: .bottomRight, directions: .all) }
            return .crosshair
        }

        override func mouseEntered(with _: NSEvent) { curseur.set() }
        override func mouseMoved(with _: NSEvent) { curseur.set() }
        override func mouseExited(with _: NSEvent) { NSCursor.arrow.set() }

        override func mouseDown(with _: NSEvent) {
            guard let window else { return }
            let depart = NSEvent.mouseLocation
            let cadre = window.frame
            while let suivant = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]),
                  suivant.type == .leftMouseDragged {
                let point = NSEvent.mouseLocation
                let largeur = max(window.minSize.width, cadre.width + point.x - depart.x)
                let hauteur = max(window.minSize.height, cadre.height - (point.y - depart.y))
                window.setFrame(NSRect(x: cadre.minX, y: cadre.maxY - hauteur, width: largeur, height: hauteur),
                                display: true)
                curseur.set()
            }
        }
    }
}
