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
    /// La liste des quêtes à la place de la fiche (`MenuQuetes.liste`) ; sans quête à montrer, elle
    /// y est d'office.
    @Published var enListe = false
    /// Voulu ouvert, qu'il soit à l'écran ou caché derrière une autre app.
    @Published private(set) var ouvert = false
    /// Ouvert depuis une autre app que Dofus (bouton de la barre, menu) : il
    /// reste là jusqu'au prochain changement d'app plutôt que de ne pas
    /// apparaître du tout.
    private var impose = false
    private var panel: NSPanel?
    /// Ce dont dépend `ici()`.
    struct CleIci: Equatable {
        let position: PositionCarte?
        // periphery:ignore - lu par l'Equatable synthétisé, que Periphery ne voit pas
        let quetes: Date?
        // periphery:ignore - lu par l'Equatable synthétisé
        let langue: Langue
        // periphery:ignore - lu par l'Equatable synthétisé
        let reseauLu: Bool
    }

    private var iciGarde = DernierCalcul<CleIci, MenuQuetes.Ici?>()

    private override init() { super.init() }

    func basculer() {
        ouvert ? fermer() : ouvrir()
    }

    /// Montre le panneau, sur la quête en cours ; sans quête épinglée, il
    /// invite à en chercher une. À l'ouverture, il lit le suivi de quêtes du
    /// jeu si l'enregistrement de l'écran est déjà permis — jamais il ne le
    /// demande de lui-même.
    func ouvrir() {
        if !ouvert {
            UsageStore.shared.compter(.quetes)
            if WindowPreviewService.shared.authorized { LectureSuivi.shared.lire() }
        }
        ouvert = true
        impose = true
        appliquer(force: true)
    }

    /// Ajoute la quête au panneau (si elle n'y est pas) et la montre.
    func ouvrir(_ id: Int) {
        let prefs = Preferences.shared
        if !prefs.quetesEpinglees.contains(id) { prefs.quetesEpinglees.append(id) }
        montrer(id)
        ouvrir()
    }

    /// Montre la quête à la place de celle à l'écran (`MenuQuetes.remplacer`).
    func ouvrirALaPlace(_ id: Int) {
        let prefs = Preferences.shared
        let avant = prefs.quetesEpinglees
        let apres = MenuQuetes.remplacer(avant, montree: idMontre, par: id)
        if apres != avant {
            prefs.quetesEpinglees = apres
            LectureSuivi.shared.oublier(avant.filter { !apres.contains($0) })
        }
        montrer(id)
        ouvrir()
    }

    func montrer(_ id: Int) {
        montree = id
        enListe = false
    }

    /// La quête à l'écran : la montrée si elle est encore épinglée, sinon la
    /// dernière épinglée.
    var idMontre: Int? {
        let epinglees = Preferences.shared.quetesEpinglees
        return montree.flatMap { epinglees.contains($0) ? $0 : nil } ?? epinglees.last
    }

    /// Retire la quête ; la dernière retirée laisse le panneau ouvert sur la liste.
    func desepingler(_ id: Int) {
        let prefs = Preferences.shared
        prefs.quetesEpinglees.removeAll { $0 == id }
        LectureSuivi.shared.oublier([id])
        if montree == id { montree = prefs.quetesEpinglees.last }
        if prefs.quetesEpinglees.isEmpty { enListe = true }
    }

    /// Un dernier mot avant : le panneau se vide d'un coup.
    func confirmerToutDesepingler() {
        let nombre = Preferences.shared.quetesEpinglees.count
        if ConfirmationHorsVue.demander(titre: L("quete.menu.toutDesepingler.confirmation", nombre: nombre, nombre),
                                        verbe: L("quete.desepingler")) {
            toutDesepingler()
        }
    }

    /// Retire toutes les quêtes ; le panneau reste ouvert sur la liste, qui
    /// invite à en chercher une — fermer se fait par « ⋯ ».
    func toutDesepingler() {
        LectureSuivi.shared.oublier(Preferences.shared.quetesEpinglees)
        Preferences.shared.quetesEpinglees = []
        montree = nil
        enListe = true
    }

    /// Cache le panneau ; les quêtes restent épinglées pour la prochaine fois.
    func fermer() {
        ouvert = false
        appliquer(force: false)
    }

    /// À chaque changement d'app active (`force`) et par le filet de
    /// `WindowManager` : la règle de la barre réservée à Dofus, sur
    /// `frontmostPID` — `NSWorkspace` a un tour de retard.
    func revoirVisibilite(force: Bool) {
        if force { impose = false }
        appliquer(force: force)
    }

    /// Montré, il fait lire le suivi du jeu au tour, si l'enregistrement de
    /// l'écran est déjà permis ; caché, plus rien n'est lu pour lui.
    private func appliquer(force: Bool) {
        let montre = PanneauxJeu.appliquer(&panel, ouvert: ouvert, impose: impose, force: force, parDefaut: Self.placeParDefaut,
                                           construire: construire, cache: { ApercuCarte.shared.cacher() })
        LecteurEcran.shared.suivreQuetes(montre && WindowPreviewService.shared.authorized)
    }

    private func construire() -> NSPanel {
        let panel = PanneauQuetes(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: QueteVue().racineSynfus())
        panel.minSize = Self.tailleMinimale
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Sans `.resizable`, AppKit ne relit le cadre sauvé que de force : sa
        // taille vient de nos poignées.
        if !panel.setFrameAutosaveName(Self.nomDuCadre) || !panel.setFrameUsingName(Self.nomDuCadre, force: true) {
            PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut)
        }
        return panel
    }

    /// En haut à droite de l'écran.
    private static let placeParDefaut: PanneauxJeu.PlaceParDefaut = { zone, _ in
        NSPoint(x: zone.maxX - 384, y: zone.maxY - 80)
    }

    /// Le panneau ouvert reprend sa place d'origine.
    func recentrer() {
        if ouvert, let panel { PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut) }
    }
}

// MARK: - Menu de l'en-tête

extension QuetePanel {
    /// Le menu « ⋯ » de l'en-tête (`MenuQuetes.reglages`), construit à chaque ouverture.
    func menu() -> NSMenu {
        let prefs = Preferences.shared
        let menu = NSMenu()
        menu.autoenablesItems = false
        for element in MenuQuetes.reglages(epinglees: prefs.quetesEpinglees.count,
                                           actives: Set(MenuQuetes.Option.allCases.filter { prefs[keyPath: Self.reglage($0)] })) {
            Self.ajouter(element, a: menu)
        }
        return menu
    }

    /// La liste du panneau (`MenuQuetes.liste`), refaite à chaque rendu.
    func liste() -> [MenuQuetes.Element] {
        let lecture = LectureSuivi.shared
        let store = QuetesStore.shared
        return MenuQuetes.liste(
            epinglees: Preferences.shared.quetesEpinglees, montree: idMontre, reconnues: lecture.reconnues,
            etat: lecture.etat, ici: ici(),
            autorise: WindowPreviewService.shared.authorized, nom: { store.nom($0) ?? "…" })
    }

    /// Seuls les éléments de `MenuQuetes.reglages` : la liste se dessine dans le panneau.
    private static func ajouter(_ element: MenuQuetes.Element, a menu: NSMenu) {
        let prefs = Preferences.shared
        switch element {
        case .toutDesepingler:
            menu.addItem(CibleMenu.shared.element(L("quete.menu.toutDesepingler")) { QuetePanel.shared.confirmerToutDesepingler() })
        case .affichage(let options):
            let sousMenu = NSMenu()
            sousMenu.autoenablesItems = false
            for option in options { ajouter(option, a: sousMenu) }
            let item = NSMenuItem(title: L("quete.menu.affichage"), action: nil, keyEquivalent: "")
            item.submenu = sousMenu
            menu.addItem(item)
        case .option(let option, let actif):
            let item = CibleMenu.shared.element(option.titre) { prefs[keyPath: Self.reglage(option)] = !actif }
            item.state = actif ? .on : .off
            menu.addItem(item)
        case .fermer:
            menu.addItem(CibleMenu.shared.element(L("panneau.fermer"), raccourci: prefs.quetesHotKey) { QuetePanel.shared.fermer() })
        case .separateur:
            menu.addItem(.separator())
        case .titre, .epinglee, .ici, .iciEnTete, .lireSuivi, .reconnue, .message, .geste:
            break
        }
    }
}

extension QuetePanel {
    /// Le geste qui lève la cause d'un suivi illisible.
    static func faire(_ geste: MenuQuetes.Geste) {
        switch geste {
        case .autoriser: WindowPreviewService.shared.requestAuthorization()
        case .calibrer: SettingsWindowController.shared.show(section: .lecture)
        case .reessayer: Task { try? await QuetesStore.shared.mettreAJour() }
        case .relire: LectureSuivi.shared.lire()
        }
    }

    /// Une quête à chercher : la palette, ouverte sur `/quete`.
    static func chercher() {
        PalettePanel.shared.ouvrir()
        PaletteModele.shared.requete = "/quete "
    }

    /// Le menu des étapes (`MenuEtapes`) : en choisir une la montre.
    func menuEtapes(_ entrees: [MenuEtapes.Entree], choisir: @escaping @MainActor (Int) -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for entree in entrees {
            let item = CibleMenu.shared.element(entree.titre) { choisir(entree.rang) }
            item.state = entree.montree ? .on : .off
            if entree.faite { item.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil) }
            menu.addItem(item)
        }
        return menu
    }
}

extension QuetePanel {
    /// Ce qui commence sur la case du perso devant, d'après sa position lue. L'en-tête le redemande à
    /// chaque rendu : le balayage des quêtes ne se refait que si la case, les quêtes, la langue ou la
    /// carte ont changé.
    func ici() -> MenuQuetes.Ici? {
        let position = LecteurEcran.shared.positionDuPersoDevant
        let reseau = CarteStore.shared.reseau, langue = L10n.courante.langue
        let cle = CleIci(position: position, quetes: QuetesStore.shared.quetes?.date, langue: langue, reseauLu: reseau.estLu)
        return iciGarde.valeur(pour: cle) {
            guard let perso = position, let quetes = QuetesStore.shared.quetes else { return nil }
            return MenuQuetes.Ici(
                coordonnees: perso.coordonnees,
                quetes: QuetesIci.quetes(quetes, perso: perso, reseau: reseau).map {
                    .init(id: $0.id, nom: Lieu.traduit($0.noms, langue) ?? "?", niveau: $0.niveau)
                },
                pnjs: QuetesIci.pnjs(quetes, perso: perso, reseau: reseau).compactMap { Lieu.traduit($0.noms, langue) })
        }
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
    /// agrandir le panneau ; `coin` est la marque du coin bas droit, de la
    /// taille de celui de gauche — posée sur le contenu, sans bande réservée. Les coins passent par-dessus les
    /// bords : saisi près d'un coin, le panneau s'agrandit dans les deux sens.
    func bordsRedimensionnables(coin: some View) -> some View {
        let epaisseur: CGFloat = 6, cote: CGFloat = 14
        return overlay(alignment: .leading) { PoigneeRedimension(bords: .gauche).frame(width: epaisseur) }
            .overlay(alignment: .trailing) { PoigneeRedimension(bords: .droite).frame(width: epaisseur) }
            .overlay(alignment: .bottom) { PoigneeRedimension(bords: .bas).frame(height: epaisseur) }
            .overlay(alignment: .bottomLeading) { PoigneeRedimension(bords: [.gauche, .bas]).frame(width: cote, height: cote) }
            .overlay(alignment: .bottomTrailing) {
                coin.frame(width: cote, height: cote).overlay(PoigneeRedimension(bords: [.droite, .bas]))
            }
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

    private final class Poignee: VueACurseur {
        private let bords: BordsPanneau

        init(bords: BordsPanneau) {
            self.bords = bords
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { nil }

        override var curseur: NSCursor {
            let position: NSCursor.FrameResizePosition = switch bords {
            case .gauche: .left
            case .droite: .right
            case .bas: .bottom
            case [.gauche, .bas]: .bottomLeft
            default: .bottomRight
            }
            return .frameResize(position: position, directions: .all)
        }

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
