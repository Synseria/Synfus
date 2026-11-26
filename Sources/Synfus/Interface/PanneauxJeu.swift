import AppKit
import SwiftUI
import SynseriaDesign

/// Ce que partagent les panneaux posés sur le jeu — quêtes, chasse, aide aux
/// boss, recette : quand ils se montrent, et les boutons de leur en-tête.
@MainActor
enum PanneauxJeu {
    /// Chaque panneau revoit s'il se montre — au changement d'app (`force`),
    /// par le filet de `WindowManager`, quand le réglage change. Le seul
    /// endroit qui les énumère : un panneau de plus ne s'oublie nulle part.
    static func revoir(force: Bool) {
        QuetePanel.shared.revoirVisibilite(force: force)
        ChassePanel.shared.revoirVisibilite(force: force)
        BossPanel.shared.revoirVisibilite(force: force)
        RecettePanel.shared.revoirVisibilite(force: force)
        ForgemagiePanel.shared.revoirVisibilite(force: force)
    }

    /// Remet à leur place d'origine les panneaux ouverts, avec la barre : le geste du menu pour un
    /// panneau que rien ne ramène — sans bordure ni barre de titre, macOS ne le fait pas.
    static func recentrerBarreEtPanneaux() {
        FloatingBarController.shared.recenter()
        QuetePanel.shared.recentrer()
        ChassePanel.shared.recentrer()
        BossPanel.shared.recentrer()
        RecettePanel.shared.recentrer()
        ForgemagiePanel.shared.recentrer()
    }

    // MARK: - Pliage

    /// Le panneau est-il plié sur son en-tête ?
    static func plie(_ panneau: PanneauJeu, dans prefs: Preferences = .shared) -> Bool {
        prefs.panneauxPlies[panneau.rawValue] != nil
    }

    /// Un panneau rouvert garde son pliage ; ouvert sur quelque chose de précis (une quête, un boss,
    /// une recette), il le montre et se déplie.
    ///
    /// Plie le panneau, en gardant `hauteur` (celle de son cadre déplié), ou le déplie : rend alors
    /// la hauteur gardée. Un panneau à la taille de son contenu n'en fait rien : il suit sa vue.
    @discardableResult
    static func basculerPliage(_ panneau: PanneauJeu, hauteur: CGFloat, dans prefs: Preferences = .shared) -> CGFloat? {
        if let avant = prefs.panneauxPlies[panneau.rawValue] {
            prefs.panneauxPlies[panneau.rawValue] = nil
            return CGFloat(avant)
        }
        prefs.panneauxPlies[panneau.rawValue] = Double(hauteur)
        return nil
    }

    // MARK: - Construction

    /// Un panneau à la hauteur de son contenu et à la largeur réglable entre `largeurs`, `largeur`
    /// d'abord : sans
    /// bordure, au niveau de la barre, sur tous les espaces, sa place et sa largeur gardées par
    /// AppKit sous `nom` — relues de force, un panneau non `.resizable` ne reprend pas sa taille sinon.
    static func construire<Vue: View>(_ type: PanneauDeJeu.Type = PanneauDeJeu.self, nom: String,
                                      largeur: CGFloat, largeurs: ClosedRange<CGFloat>, vue: Vue,
                                      parDefaut: PlaceParDefaut) -> PanneauDeJeu {
        let panel = type.init()
        panel.minSize = NSSize(width: largeurs.lowerBound, height: 0)
        panel.maxSize = NSSize(width: largeurs.upperBound, height: .greatestFiniteMagnitude)
        let suivie = LargeurPanneau(largeur)
        panel.largeurSuivie = suivie
        panel.setFrame(NSRect(x: 0, y: 0, width: largeur, height: 200), display: false)
        let hosting = NSHostingController(rootView: AvecLargeurPanneau(largeur: suivie, contenu: vue).racineSynfus())
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if !panel.setFrameAutosaveName(nom) || !panel.setFrameUsingName(nom, force: true) {
            placer(panel, parDefaut: parDefaut)
        }
        return panel
    }

    // MARK: - Place d'un panneau

    /// Où paraît un panneau qui n'a pas de place gardée, ou que son écran a quittée : le coin haut
    /// gauche de son cadre, sur la zone visible de l'écran principal et pour sa taille.
    typealias PlaceParDefaut = (_ zoneVisible: NSRect, _ taille: NSSize) -> NSPoint

    /// La marge dont un point peut déborder d'un écran et compter encore dessus, et la taille du
    /// bandeau d'un panneau qui doit rester sur un écran pour rester saisissable.
    nonisolated private static let margeEcran: CGFloat = 40

    /// Un point est-il sur l'un des écrans ? La règle de la barre, qui évite de restaurer sa position
    /// sur un écran débranché depuis.
    nonisolated static func surUnEcran(_ point: CGPoint, ecrans: [CGRect]) -> Bool {
        ecrans.contains { $0.insetBy(dx: -margeEcran, dy: -margeEcran).contains(point) }
    }

    static func surUnEcran(_ point: CGPoint) -> Bool {
        surUnEcran(point, ecrans: NSScreen.screens.map(\.frame))
    }

    /// Un panneau se tient par son bandeau, en haut : il est atteignable tant qu'une part de ce
    /// bandeau — au moins la marge de large — reste sur un écran, même poussé à moitié hors de l'autre.
    nonisolated static func bandeauAtteignable(de cadre: NSRect, ecrans: [CGRect]) -> Bool {
        let bandeau = CGRect(x: cadre.minX, y: cadre.maxY - margeEcran, width: cadre.width, height: margeEcran)
        return ecrans.contains {
            let commun = $0.intersection(bandeau)
            return !commun.isNull && commun.width >= margeEcran && commun.height >= margeEcran / 2
        }
    }

    /// Pose le panneau à sa place d'origine.
    static func placer(_ panel: NSPanel, parDefaut: PlaceParDefaut) {
        guard let zone = NSScreen.main?.visibleFrame else { return }
        panel.setFrameTopLeftPoint(parDefaut(zone, panel.frame.size))
    }

    /// Un panneau dont le bandeau n'est sur aucun écran — l'écran où il était est débranché — reprend
    /// sa place d'origine ; un autre reste où il est.
    static func rattraper(_ panel: NSPanel, parDefaut: PlaceParDefaut) {
        if !bandeauAtteignable(de: panel.frame, ecrans: NSScreen.screens.map(\.frame)) {
            placer(panel, parDefaut: parDefaut)
        }
    }

    /// Montre ou cache un panneau voulu `ouvert` : devant Dofus (`visible`),
    /// ou `impose` — ouvert depuis une autre app (menu, bouton de la barre),
    /// il reste là jusqu'au prochain changement d'app plutôt que de ne pas
    /// paraître. Construit à sa première apparition, rattrapé s'il paraît hors
    /// de tout écran ; `cache` suit le masquage d'un panneau qui était à
    /// l'écran. Rend s'il est montré.
    @discardableResult
    static func appliquer(_ panel: inout NSPanel?, ouvert: Bool, impose: Bool, force: Bool,
                          parDefaut: PlaceParDefaut, construire: () -> NSPanel, cache: () -> Void = {}) -> Bool {
        let montre = visible(ouvert: ouvert) || (ouvert && impose)
        if montre {
            let affiche = panel ?? construire()
            panel = affiche
            if force || !affiche.isVisible {
                rattraper(affiche, parDefaut: parDefaut)
                affiche.orderFrontRegardless()
            }
        } else if let panel, panel.isVisible {
            panel.orderOut(nil)
            cache()
        }
        return montre
    }

    /// Un panneau ouvert se montre-t-il ? Avec `panneauxSeulementDofus`,
    /// seulement devant Dofus (ou Synfus) : la règle de la barre réservée au
    /// jeu, sur `frontmostPID` — `NSWorkspace` a un tour de retard.
    static func visible(ouvert: Bool) -> Bool {
        let manager = WindowManager.shared
        return FloatingBarController.computeVisibility(
            barVisible: ouvert, onlyWithDofus: Preferences.shared.panneauxSeulementDofus,
            frontPID: manager.frontmostPID, frontIsDofus: manager.frontmostIsDofus,
            ownPID: ProcessInfo.processInfo.processIdentifier)
    }
}

/// Les panneaux posés sur le jeu, nommés : la clé de leur pliage dans les préférences.
enum PanneauJeu: String, Sendable {
    case quetes, chasse, boss, recette, forgemagie
}

/// Un panneau posé sur le jeu, à la taille de son contenu, jamais clé : la frappe reste au jeu, un
/// clic dessus ne la lui retire pas. Il se tient par son en-tête : quand son contenu change de
/// hauteur, le haut reste où on l'a posé — AppKit garderait le bas, et l'en-tête sauterait. Jamais
/// zoomé : un double-clic sur l'en-tête ne l'agrandit pas. Ouvert à l'héritage pour la chasse, seule
/// à prendre le clavier.
class PanneauDeJeu: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func zoom(_: Any?) {}
    override func performZoom(_: Any?) {}

    private let suiviCurseur = SuiviCurseur()

    /// Le contenu posé — directement ou par son contrôleur —, le curseur le suit.
    override var contentView: NSView? {
        didSet { suiviCurseur.suivre(contentView) }
    }

    override var contentViewController: NSViewController? {
        didSet { suiviCurseur.suivre(contentView) }
    }

    /// Sans bordure ni activation : ce que tous les panneaux posés sur le jeu sont.
    required convenience init() {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
                  styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    }

    /// À la hauteur de son contenu, sa largeur réglée : la vue la reprend (`AvecLargeurPanneau`).
    var largeurSuivie: LargeurPanneau?

    override func setFrame(_ cadre: NSRect, display: Bool) {
        var cadre = cadre
        // Seul un changement de hauteur sur place (la taille du contenu) garde le haut ; un
        // déplacement ou une place restaurée passent tels quels.
        if cadre.origin == frame.origin, cadre.height != frame.height {
            cadre.origin.y = frame.maxY - cadre.height
        }
        // Une largeur restaurée ou venue de la vue reste entre les bornes, d'où qu'elle vienne.
        if largeurSuivie != nil { cadre.size.width = min(max(cadre.width, minSize.width), maxSize.width) }
        super.setFrame(cadre, display: display)
        if let largeurSuivie, largeurSuivie.valeur != frame.width { largeurSuivie.valeur = frame.width }
    }
}

/// Un bouton d'icône d'un panneau : une cible de 24 pt, quelle que soit l'icône, au même dessin partout.
/// `copie` : l'icône devient la coche de copie le temps du signal (`IconeCopie`) ; `discret` : encre
/// secondaire au repos, pleine au survol.
struct BoutonEnTete: View {
    let icone: String
    let aide: String
    var copie = false
    var discret = false
    let action: () -> Void
    @State private var survole = false

    var body: some View {
        Button(action: action) {
            IconeCopie(icone: icone, copie: copie)
                .font(Jetons.typoMicro.font)
                .frame(width: Jetons.hauteurCase, height: Jetons.hauteurCase)
                .foregroundStyle(discret && !survole ? Color.jeton(\.encre2) : Color.jeton(\.encre))
        }
        .buttonStyle(.etat(nue: true))
        .onHover { survole = $0 }
        .aide(aide)
    }
}

/// Le curseur d'un panneau posé sur le jeu, que macOS ne pose pas pour une app inactive : la main
/// des boutons de SwiftUI (`curseurDeClic`) n'y paraît jamais. Sur chaque mouvement, toujours suivi
/// (`.activeAlways`), il prend celui de ce qui est sous la souris : le sien pour une zone qui en a un
/// (`VueACurseur` : en-tête, poignées), la main pour ce que l'accessibilité dit cliquable, le trait
/// d'un champ, la flèche ailleurs.
@MainActor
private final class SuiviCurseur: NSObject {
    private weak var vue: NSView?
    private var zone: NSTrackingArea?

    func suivre(_ vue: NSView?) {
        if let ancienne = self.vue, let zone { ancienne.removeTrackingArea(zone) }
        self.vue = vue
        guard let vue else { return }
        CurseurArrierePlan.autoriser()
        let zone = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        vue.addTrackingArea(zone)
        self.zone = zone
    }

    @objc func mouseEntered(with event: NSEvent) { poser(event) }
    @objc func mouseMoved(with event: NSEvent) { poser(event) }
    @objc func mouseExited(with _: NSEvent) { NSCursor.arrow.set() }

    private static let cliquables: Set<NSAccessibility.Role> = [
        .button, .link, .checkBox, .radioButton, .popUpButton, .menuButton, .disclosureTriangle, .incrementor,
    ]
    private static let champs: Set<NSAccessibility.Role> = [.textField, .textArea, .comboBox]

    private func poser(_ event: NSEvent) {
        guard let vue, let fenetre = vue.window,
              let touche = vue.hitTest(vue.convert(event.locationInWindow, from: nil)) else { return }
        // Une zone à curseur pose le sien à chaque pas : ne pas le lui reprendre.
        if touche is VueACurseur { return }
        let element = vue.accessibilityHitTest(fenetre.convertPoint(toScreen: event.locationInWindow))
        let accessible = element as? NSAccessibilityProtocol
        let role = accessible?.accessibilityRole()
        if let role, Self.cliquables.contains(role), accessible?.isAccessibilityEnabled() ?? true {
            NSCursor.pointingHand.set()
        } else if let role, Self.champs.contains(role) {
            NSCursor.iBeam.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}

/// « − » qui plie un panneau sur son en-tête, « ⌄ » qui le déplie : le même dans chaque panneau,
/// juste avant son dernier bouton (« × » ou « ⋯ »).
struct BoutonPliage: View {
    let plie: Bool
    let action: () -> Void

    var body: some View {
        BoutonEnTete(icone: plie ? "chevron.down" : "minus", aide: plie ? L("panneau.deplier") : L("panneau.plier"),
                     discret: true, action: action)
    }
}

/// L'en-tête d'une ligne d'un panneau posé sur le jeu : l'icône, le titre,
/// l'espace libre, les boutons. Tout, sauf les boutons, déplace le panneau ;
/// avec `menu` ou `clic`, un clic sur le titre agit et seul un glisser le déplace
/// (`WindowDragArea`). La zone est posée par-dessus l'icône et le titre — une
/// image ou un texte au-dessus d'une `NSView` lui prennent le clic — et jamais
/// sur un bouton, qu'elle priverait du sien.
struct EnTetePanneau<Titre: View, Boutons: View>: View {
    let icone: String
    let teinte: Color
    /// Le menu qu'ouvre un clic sur le titre.
    var menu: (@MainActor () -> NSMenu)?
    /// Ce que fait un clic sur le titre, à la place d'un menu.
    var clic: (@MainActor () -> Void)?
    @ViewBuilder let titre: Titre
    @ViewBuilder let boutons: Boutons

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: icone)
                .foregroundStyle(teinte)
                .padding(.leading, Jetons.espace2)
                .padding(.trailing, Jetons.espace1)
                .frame(maxHeight: .infinity)
                .overlay(WindowDragArea())
            // Le titre d'abord : sans priorité, la zone de glisser, flexible
            // elle aussi, lui prenait la moitié de la place et le tronquait.
            // Une seule zone sur tout le titre, indicateur de lecture compris :
            // le menu s'ouvre sous son bord gauche.
            HStack(spacing: 0) { titre }
                .frame(maxHeight: .infinity)
                .overlay(WindowDragArea(menu: menu, clic: clic))
                .layoutPriority(1)
            WindowDragArea().frame(minWidth: 4, maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: Jetons.espace1) { boutons }
                .padding(.vertical, Jetons.espace1)
        }
        .padding(.trailing, Jetons.espace1)
        .font(Jetons.typoMeta.font)
        // Les zones de glisser prennent la hauteur des boutons, sans tirer
        // l'en-tête vers le bas.
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// La forme des panneaux posés sur le jeu (le bandeau `.sw .bar` du SDS) : l'en-tête dans un bandeau
/// d'un bord à l'autre — le verre en trois couches du SDS : le bandeau porte du texte, voilé de la
/// page à `verreOpaciteBarre`, fermé du filet du verre (`Color.traitSurVerre`) —, puis le corps sur
/// une plaque pleine à `espace2` du verre. `plie` : le bandeau seul. Le corps ne pousse jamais
/// le panneau : plus large que la place, il est rogné à sa plaque — sinon tout le contenu
/// s'élargissait et la fenêtre en rognait le verre et la fin de l'en-tête.
struct CadrePanneau<EnTete: View, Corps: View>: View {
    var plie = false
    @ViewBuilder let enTete: EnTete
    @ViewBuilder let corps: Corps
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            enTete
                .padding(.vertical, Jetons.espace1)
                .background(c.fondFenetre.voile(Jetons.verreOpaciteBarre).couleur)
                .overlay(alignment: .bottom) {
                    if !plie { Color.traitSurVerre.frame(height: Jetons.epaisseurFilet) }
                }
            if !plie {
                corps
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular))
                    .plaquePleine()
                    .padding(Jetons.espace2)
            }
        }
        .font(Jetons.typoMeta.font)
        .clipShape(RoundedRectangle(cornerRadius: Jetons.rayon3, style: .continuous))
        .surfaceFlottante()
    }
}

/// Les éléments du menu portent leur action (`representedObject`) : le menu
/// se reconstruit à chaque ouverture, une cible commune les déclenche.
@MainActor
final class CibleMenu: NSObject {
    static let shared = CibleMenu()

    private final class Action {
        let agir: @MainActor () -> Void
        init(_ agir: @escaping @MainActor () -> Void) { self.agir = agir }
    }

    func element(_ titre: String, raccourci: HotKey? = nil, agir: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: titre, action: #selector(declencher(_:)), keyEquivalent: "")
        item.target = self
        item.afficher(raccourci)
        item.representedObject = Action(agir)
        return item
    }

    @objc private func declencher(_ item: NSMenuItem) {
        (item.representedObject as? Action)?.agir()
    }
}
