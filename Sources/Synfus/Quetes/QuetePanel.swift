import AppKit
import SwiftUI

/// Sans bordure ni barre de titre : une barre de titre, même transparente,
/// garde pour elle les clics de la première ligne et zoome au double-clic.
/// Jamais clé (un clic ne retire pas la frappe à Dofus), jamais zoomé : on
/// le déplace par son en-tête (`WindowDragArea`) et on l'agrandit par ses
/// bords et son coin (`PoigneeRedimension`).
private final class PanneauQuetes: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func zoom(_: Any?) {}
    override func performZoom(_: Any?) {}
}

/// Le panneau des quêtes épinglées : transparent, au-dessus du jeu — on le
/// garde ouvert en jouant. Plusieurs quêtes, une montrée à la fois ; on le
/// déplace par son en-tête et on le redimensionne par ses bords ou sa
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
    /// invite à en chercher une. À l'ouverture, il lit le suivi de quêtes du
    /// jeu si l'enregistrement de l'écran est déjà permis — jamais il ne le
    /// demande de lui-même.
    func ouvrir() {
        if !ouvert, WindowPreviewService.shared.authorized { LectureSuivi.shared.lire() }
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

    /// La quête à l'écran : la montrée si elle est encore épinglée, sinon la
    /// dernière épinglée.
    var idMontre: Int? {
        let epinglees = Preferences.shared.quetesEpinglees
        return montree.flatMap { epinglees.contains($0) ? $0 : nil } ?? epinglees.last
    }

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

    private func cacher() {
        panel?.orderOut(nil)
        ApercuCarte.shared.cacher()
    }

    private func construire() -> NSPanel {
        let panel = PanneauQuetes(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
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

// MARK: - Menu de l'en-tête

extension QuetePanel {
    /// Le menu de l'en-tête (`MenuQuetes`), construit à chaque ouverture.
    func menu() -> NSMenu {
        let lecture = LectureSuivi.shared
        let store = QuetesStore.shared
        let prefs = Preferences.shared
        let menu = NSMenu()
        menu.autoenablesItems = false
        for element in MenuQuetes.elements(
            epinglees: prefs.quetesEpinglees, montree: idMontre, reconnues: lecture.reconnues,
            etat: lecture.etat, masquerObjets: prefs.quetesMasquerObjets, nom: { store.nom($0) ?? "…" }) {
            switch element {
            case .titre(let titre):
                menu.addItem(.sectionHeader(title: titre))
            case .epinglee(let id, let nom, let montree):
                let item = CibleMenu.shared.element(nom) { QuetePanel.shared.montrer(id) }
                item.state = montree ? .on : .off
                menu.addItem(item)
            case .lireSuivi(let enCours):
                let item = CibleMenu.shared.element(enCours ? L("quete.suivi.enCours") : L("quete.suivi.lire")) { lecture.lire() }
                item.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
                item.isEnabled = !enCours
                menu.addItem(item)
            case .reconnue(let reconnue, let titre, let epinglee):
                let item = CibleMenu.shared.element(titre) { lecture.choisir(reconnue) }
                item.image = epinglee ? NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil) : nil
                item.indentationLevel = 1
                menu.addItem(item)
            case .message(let texte):
                let item = NSMenuItem(title: texte, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            case .masquerObjets(let actif):
                let item = CibleMenu.shared.element(L("quetes.masquerObjets")) { prefs.quetesMasquerObjets = !actif }
                item.state = actif ? .on : .off
                menu.addItem(item)
            case .separateur:
                menu.addItem(.separator())
            }
        }
        return menu
    }
}

/// Les éléments du menu portent leur action (`representedObject`) : le menu
/// se reconstruit à chaque ouverture, une cible commune les déclenche.
@MainActor
private final class CibleMenu: NSObject {
    static let shared = CibleMenu()

    private final class Action {
        let agir: @MainActor () -> Void
        init(_ agir: @escaping @MainActor () -> Void) { self.agir = agir }
    }

    func element(_ titre: String, agir: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: titre, action: #selector(declencher(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = Action(agir)
        return item
    }

    @objc private func declencher(_ item: NSMenuItem) {
        (item.representedObject as? Action)?.agir()
    }
}

/// Ouvre un `NSMenu` sous la vue au clic. Plutôt qu'un `Menu` SwiftUI : un
/// `popUp` suit la souris dans un panneau jamais clé d'une app inactive sans
/// activer Synfus, comme le menu de la barre de menus.
struct DeclencheurMenu: NSViewRepresentable {
    let fabrique: @MainActor () -> NSMenu

    func makeNSView(context _: Context) -> Declencheur { Declencheur(fabrique: fabrique) }
    func updateNSView(_ vue: Declencheur, context _: Context) { vue.fabrique = fabrique }

    final class Declencheur: NSView {
        var fabrique: @MainActor () -> NSMenu

        init(fabrique: @escaping @MainActor () -> NSMenu) {
            self.fabrique = fabrique
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { nil }

        override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }

        override func mouseDown(with _: NSEvent) {
            fabrique().popUp(positioning: nil, at: NSPoint(x: 0, y: isFlipped ? bounds.maxY + 2 : -2), in: self)
        }
    }
}

/// Les bords qu'une poignée déplace. Le haut n'en est pas : c'est l'en-tête,
/// qui déplace le panneau.
struct BordsPanneau: OptionSet, Sendable {
    let rawValue: Int

    static let gauche = BordsPanneau(rawValue: 1)
    static let droite = BordsPanneau(rawValue: 2)
    static let bas = BordsPanneau(rawValue: 4)

    /// Le cadre après un glisser de `decalage` (repère de l'écran, y vers le
    /// haut) : le bord haut ne bouge jamais, ni le bord opposé à celui qu'on
    /// tire, et la taille ne passe pas sous `minimum`.
    func cadre(_ depart: NSRect, decalage: CGVector, minimum: NSSize) -> NSRect {
        var largeur = depart.width, hauteur = depart.height, x = depart.minX
        if contains(.droite) { largeur = max(minimum.width, depart.width + decalage.dx) }
        if contains(.gauche) {
            largeur = max(minimum.width, depart.width - decalage.dx)
            x = depart.maxX - largeur
        }
        if contains(.bas) { hauteur = max(minimum.height, depart.height - decalage.dy) }
        return NSRect(x: x, y: depart.maxY - hauteur, width: largeur, height: hauteur)
    }
}

extension View {
    /// Les bords gauche, droit et bas et les coins du bas, à saisir pour
    /// agrandir le panneau ; `coin` est la poignée visible du coin bas droit.
    func bordsRedimensionnables(coin: some View) -> some View {
        let epaisseur: CGFloat = 4
        return overlay(alignment: .leading) { PoigneeRedimension(bords: .gauche).frame(width: epaisseur) }
            .overlay(alignment: .trailing) { PoigneeRedimension(bords: .droite).frame(width: epaisseur) }
            .overlay(alignment: .bottom) { PoigneeRedimension(bords: .bas).frame(height: epaisseur) }
            .overlay(alignment: .bottomLeading) { PoigneeRedimension(bords: [.gauche, .bas]).frame(width: 12, height: 12) }
            .overlay(alignment: .bottomTrailing) { coin.overlay(PoigneeRedimension(bords: [.droite, .bas])) }
    }
}

/// Une poignée de redimensionnement : un glisser déplace les bords donnés, le
/// bord haut ne bouge pas. Une boucle d'évènements à soi plutôt que les bords
/// du système, minces sur un panneau sans bordure et difficiles à saisir.
struct PoigneeRedimension: NSViewRepresentable {
    let bords: BordsPanneau

    func makeNSView(context _: Context) -> NSView { Poignee(bords: bords) }
    func updateNSView(_: NSView, context _: Context) {}

    private final class Poignee: NSView {
        private let bords: BordsPanneau

        init(bords: BordsPanneau) {
            self.bords = bords
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { nil }

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
            if #available(macOS 15.0, *) {
                let position: NSCursor.FrameResizePosition = switch bords {
                case .gauche: .left
                case .droite: .right
                case .bas: .bottom
                case [.gauche, .bas]: .bottomLeft
                default: .bottomRight
                }
                return .frameResize(position: position, directions: .all)
            }
            switch bords {
            case .gauche, .droite: return .resizeLeftRight
            case .bas: return .resizeUpDown
            default: return .crosshair
            }
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
                window.setFrame(bords.cadre(cadre, decalage: CGVector(dx: point.x - depart.x, dy: point.y - depart.y),
                                            minimum: window.minSize),
                                display: true)
                curseur.set()
            }
        }
    }
}
