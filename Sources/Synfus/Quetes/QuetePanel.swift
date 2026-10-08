import AppKit
import SwiftUI

/// Sans bordure ni barre de titre : une barre de titre, même transparente,
/// garde pour elle les clics de la première ligne et zoome au double-clic.
/// Jamais clé (un clic ne retire pas la frappe à Dofus), jamais zoomé : on
/// le déplace par son en-tête (`WindowDragArea`) et on l'agrandit par ses
/// bords et ses coins du bas (`PoigneeRedimension`). Pas `.resizable` : les
/// bords du système, invisibles et sans curseur pour une app inactive,
/// chevaucheraient nos poignées et le haut de l'en-tête — un glisser pensé
/// pour déplacer agrandirait.
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

    /// Assez étroit pour ne masquer qu'un coin du jeu : la fiche passe ses
    /// étiquettes à la ligne plutôt que de déborder.
    static let tailleMinimale = NSSize(width: 220, height: 200)
    /// Le cadre gardé par AppKit dans les préférences.
    private static let nomDuCadre = "QuetePanel"

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

    /// Retire l'onglet ; le panneau se ferme avec le dernier.
    func desepingler(_ id: Int) {
        let prefs = Preferences.shared
        prefs.quetesEpinglees.removeAll { $0 == id }
        LectureSuivi.shared.oublier([id])
        if montree == id { montree = prefs.quetesEpinglees.last }
        if prefs.quetesEpinglees.isEmpty { fermer() }
    }

    /// Retire toutes les quêtes et cache le panneau.
    func toutDesepingler() {
        LectureSuivi.shared.oublier(Preferences.shared.quetesEpinglees)
        Preferences.shared.quetesEpinglees = []
        montree = nil
        fermer()
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
        if PanneauxJeu.visible(ouvert: ouvert) || (ouvert && impose) {
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
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: QueteVue())
        panel.minSize = Self.tailleMinimale
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Sans `.resizable`, AppKit ne relit le cadre sauvé que de force : sa
        // taille vient de nos poignées.
        if !panel.setFrameAutosaveName(Self.nomDuCadre) || !panel.setFrameUsingName(Self.nomDuCadre, force: true),
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
            etat: lecture.etat, coches: lecture.cochesLues, actives: Set(MenuQuetes.Option.allCases.filter { prefs[keyPath: Self.reglage($0)] }),
            ici: Self.ici(), nom: { store.nom($0) ?? "…" }) {
            switch element {
            case .titre(let titre):
                menu.addItem(.sectionHeader(title: titre))
            case .epinglee(let id, let nom, let montree):
                let item = CibleMenu.shared.element(nom) { QuetePanel.shared.montrer(id) }
                item.state = montree ? .on : .off
                menu.addItem(item)
            case .desepingler(let id, let nom):
                let item = CibleMenu.shared.element(L("quete.menu.desepingler", nom)) { QuetePanel.shared.desepingler(id) }
                item.image = NSImage(systemSymbolName: "pin.slash", accessibilityDescription: nil)
                menu.addItem(item)
            case .ici(let id, let titre, let epinglee):
                let item = CibleMenu.shared.element(titre) { QuetePanel.shared.ouvrir(id) }
                item.image = NSImage(systemSymbolName: epinglee ? "pin.fill" : "exclamationmark.bubble",
                                     accessibilityDescription: nil)
                menu.addItem(item)
            case .toutDesepingler:
                menu.addItem(CibleMenu.shared.element(L("quete.menu.toutDesepingler")) { QuetePanel.shared.toutDesepingler() })
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
            case .option(let option, let actif):
                let item = CibleMenu.shared.element(option.titre) { prefs[keyPath: Self.reglage(option)] = !actif }
                item.state = actif ? .on : .off
                menu.addItem(item)
            case .separateur:
                menu.addItem(.separator())
            }
        }
        return menu
    }
}

extension QuetePanel {
    /// Ce qui commence sur la case du perso devant, d'après sa position lue.
    private static func ici() -> MenuQuetes.Ici? {
        guard let perso = LecteurEcran.shared.positionDuPersoDevant, let quetes = QuetesStore.shared.quetes else { return nil }
        let reseau = CarteStore.shared.reseau, langue = L10n.courante.langue
        return MenuQuetes.Ici(
            coordonnees: perso.coordonnees,
            quetes: QuetesIci.quetes(quetes, perso: perso, reseau: reseau).map {
                .init(id: $0.id, nom: Lieu.traduit($0.noms, langue) ?? "?", niveau: $0.niveau)
            },
            pnjs: QuetesIci.pnjs(quetes, perso: perso, reseau: reseau).compactMap { Lieu.traduit($0.noms, langue) })
    }

    /// Le réglage derrière une option du menu.
    private static func reglage(_ option: MenuQuetes.Option) -> ReferenceWritableKeyPath<Preferences, Bool> {
        switch option {
        case .compact: \.quetesCompact
        case .consigne: \.quetesConsigne
        case .masquerObjets: \.quetesMasquerObjets
        case .cocherSuivi: \.quetesCocherSuivi
        }
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
    /// agrandir le panneau ; `coin` est la poignée visible du coin bas droit,
    /// de la taille de celui de gauche. Les coins passent par-dessus les
    /// bords : saisi près d'un coin, le panneau s'agrandit dans les deux sens.
    func bordsRedimensionnables(coin: some View) -> some View {
        let epaisseur: CGFloat = 6, cote: CGFloat = 22
        return overlay(alignment: .leading) { PoigneeRedimension(bords: .gauche).frame(width: epaisseur) }
            .overlay(alignment: .trailing) { PoigneeRedimension(bords: .droite).frame(width: epaisseur) }
            .overlay(alignment: .bottom) { PoigneeRedimension(bords: .bas).frame(height: epaisseur) }
            .overlay(alignment: .bottomLeading) { PoigneeRedimension(bords: [.gauche, .bas]).frame(width: cote, height: cote) }
            .overlay(alignment: .bottomTrailing) { coin.overlay(PoigneeRedimension(bords: [.droite, .bas])) }
    }
}

/// Une poignée de redimensionnement : un glisser déplace les bords donnés, le
/// bord haut ne bouge pas. Une boucle d'évènements à soi plutôt que les bords
/// du système (le panneau n'est pas `.resizable`) : minces sans bordure, et
/// sans curseur dans une app inactive. Le sien est posé à l'entrée, à l'appui
/// et à chaque pas du glisser — le jeu, devant, réimpose le sien.
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
            curseur.set()
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
