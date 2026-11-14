import SwiftUI

/// Poignée de déplacement adossée à AppKit — et, avec `menu`, bouton de menu
/// qu'on peut aussi glisser (le titre des quêtes).
///
/// `performDrag(with:)` confie le déplacement au gestionnaire de fenêtres du
/// système : la fenêtre suit le curseur au rythme du compositeur. Une version
/// SwiftUI à base de `DragGesture` qui repositionne la fenêtre à chaque
/// évènement reste toujours un cran derrière la souris — c'est ce qui rendait
/// la barre poussive.
///
/// Avec un menu, l'appui ne dit pas encore ce qu'il veut : une courte boucle
/// d'évènements attend le relâchement (le menu s'ouvre) ou un mouvement franc
/// (`estUnGlisser`), puis remet l'appui **d'origine** à `performDrag` — AppKit
/// prévoit ce passage de main après examen de l'appui, ce qui garde un seul
/// mécanisme de déplacement plutôt qu'une boucle qui déplacerait la fenêtre
/// elle-même. Le menu est un `NSMenu` en `popUp` plutôt qu'un `Menu` SwiftUI :
/// il suit la souris dans un panneau jamais clé d'une app inactive sans
/// activer Synfus, comme le menu de la barre de menus.
///
/// La vue est posée **par-dessus** ce qu'elle rend saisissable (`overlay`) :
/// une image, un texte ou un `glassEffect` au-dessus d'elle garderaient le
/// clic. Et le panneau n'est jamais fenêtre clé : sans `acceptsFirstMouse`, le
/// premier clic ne servirait qu'à le « réveiller » et le glisser ne partirait pas.
struct WindowDragArea: NSViewRepresentable {
    /// Le menu qu'ouvre un clic sans glisser, sous la zone.
    var menu: (@MainActor () -> NSMenu)?

    /// En deçà, un appui qui tremble reste un clic : le menu s'ouvre plutôt
    /// que le panneau ne parte à la dérive.
    nonisolated static let seuilGlisser: CGFloat = 3

    nonisolated static func estUnGlisser(depuis depart: NSPoint, jusqua point: NSPoint) -> Bool {
        hypot(point.x - depart.x, point.y - depart.y) > seuilGlisser
    }

    func makeNSView(context _: Context) -> DragView { DragView(fabriqueMenu: menu) }
    func updateNSView(_ nsView: DragView, context _: Context) { nsView.fabriqueMenu = menu }

    final class DragView: VueACurseur {
        var fabriqueMenu: (@MainActor () -> NSMenu)?

        init(fabriqueMenu: (@MainActor () -> NSMenu)?) {
            self.fabriqueMenu = fabriqueMenu
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { nil }

        /// Main ouverte au survol, fermée pendant le glisser.
        override var curseur: NSCursor { .openHand }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            guard let fabriqueMenu else { return glisser(window, appui: event) }
            let depart = NSEvent.mouseLocation
            while let suivant = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
                if suivant.type == .leftMouseUp {
                    fabriqueMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: isFlipped ? bounds.maxY + 2 : -2), in: self)
                    return
                }
                if WindowDragArea.estUnGlisser(depuis: depart, jusqua: NSEvent.mouseLocation) {
                    return glisser(window, appui: event)
                }
            }
        }

        /// `performDrag` rend la main tout de suite, le serveur de fenêtres
        /// menant le glisser : la main fermée reste jusqu'au premier mouvement
        /// sans bouton, qui rend la main ouverte.
        private func glisser(_ window: NSWindow, appui: NSEvent) {
            NSCursor.closedHand.set()
            window.performDrag(with: appui)
        }
    }
}

/// Une vue qui pose son curseur dans un panneau jamais clé d'une app inactive
/// — zone de glisser, poignées du panneau des quêtes. Ni `cursorRects` ni
/// `cursorUpdate` n'y sont livrés : une zone de suivi active en permanence
/// pose `curseur` à l'entrée et le repose à chaque mouvement (le jeu, au
/// premier plan, réimpose le sien en continu), la flèche à la sortie. Le
/// premier clic agit (`acceptsFirstMouse`) : sans lui, il ne servirait qu'à
/// « réveiller » le panneau.
class VueACurseur: NSView {
    var curseur: NSCursor { .arrow }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

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

    override func mouseEntered(with _: NSEvent) { curseur.set() }
    override func mouseMoved(with _: NSEvent) { curseur.set() }
    override func mouseExited(with _: NSEvent) { NSCursor.arrow.set() }
}

/// Permet à Synfus de poser le curseur alors qu'il n'est pas l'app active.
///
/// C'est le cas de la barre en permanence : l'app est en mode accessory, le
/// panneau n'est jamais clé, le jeu reste devant. Or macOS ignore
/// `NSCursor.set()` venu d'une app d'arrière-plan — la main ouverte de la
/// poignée n'apparaissait jamais. Aucune API publique ne lève la limite ; la
/// propriété de connexion `SetsCursorInBackground` du serveur de fenêtres le
/// fait, celle qu'utilisent les utilitaires de barre de menus. Résolue par
/// `dlsym` : si elle disparaît d'une version de macOS, on retombe
/// silencieusement sur le curseur du système, rien ne casse.
enum CurseurArrierePlan {
    private static let fait: Bool = {
        typealias Connexion = @convention(c) () -> Int32
        typealias Propriete = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        guard let lien = dlopen(nil, RTLD_LAZY),
              let connexion = dlsym(lien, "_CGSDefaultConnection"),
              let propriete = dlsym(lien, "CGSSetConnectionProperty")
        else { return false }
        let cid = unsafeBitCast(connexion, to: Connexion.self)()
        let resultat = unsafeBitCast(propriete, to: Propriete.self)(
            cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        return resultat == 0
    }()

    /// Une fois par processus, au premier appel.
    static func autoriser() { _ = fait }
}

/// Gabarit commun des bascules de mode — éclair du passage automatique, menu
/// de rangement. Au repos le bouton est nu : le fond n'apparaît qu'au
/// survol ou quand le mode est actif, la barre ne montre plus une rangée de
/// carrés gris en permanence.
struct ModeButton: View {
    let icone: String
    let actif: Bool
    let aide: String
    let action: () -> Void
    @State private var survole = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icone)
                .font(Jetons.Typo.note.police)
                .foregroundStyle(etat.encre)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
                .fondEtat(etat)
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .aide(aide)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }

    /// Un mode allumé est un choix : la voix teintée.
    private var etat: EtatVisuel { actif ? .choisi : EtatVisuel(survole: survole) }
}

/// Les entrées du menu de rangement — les mêmes sous le bouton de la barre et
/// dans son menu contextuel, écrites une fois. La disposition en cours est
/// cochée : un `Toggle` de menu, dont la seule écriture est le rangement.
struct ArrangementMenuItems: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        let enCours = Disposition.enCours(derniere: prefs.lastArrangement)
        ForEach(Disposition.allCases) { disposition in
            Toggle(isOn: Binding(
                get: { disposition == enCours },
                set: { _ in Task { await WindowArranger.shared.appliquer(disposition) } }
            )) {
                Label(disposition.label, systemImage: disposition.symbolName)
            }
        }
        Divider()
        Button(L("rangement.toutPleinEcran")) { Task { await WindowArranger.shared.toutEnPleinEcran() } }
        Button(L("rangement.toutSortirPleinEcran")) { Task { await WindowArranger.shared.toutSortirDuPleinEcran() } }
    }
}

/// Le menu de rangement des fenêtres, au gabarit des bascules de mode. Un menu
/// et non une bascule : il propose des gestes, il ne porte pas d'état.
struct ArrangeMenuButton: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var survole = false

    var body: some View {
        Menu {
            ArrangementMenuItems()
            Divider()
            Button(L("menu.lancerSession")) { WindowManager.shared.lancerSession() }
            // Un `Menu` n'a pas de clic droit à lui : l'entrée va dans le menu même.
            Divider()
            MasquerBouton(bouton: .rangement)
        } label: {
            Image(systemName: BoutonBarre.rangement.symbole)
                .font(Jetons.Typo.note.police)
                .foregroundStyle(Color.jeton(\.encre))
                .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
                .fondEtat(EtatVisuel(survole: survole))
        }
        .menuStyle(.borderlessButton)
        .tint(Color.jeton(\.encre))
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { survole = $0 }
        .aide(BoutonBarre.rangement.infobulle(
            touche: BoutonBarre.rangement.raccourci(prefs)?.displayString))
    }
}

/// L'entrée « Masquer ce bouton » du menu d'un bouton de la barre ; il revient
/// par Réglages › Barre.
struct MasquerBouton: View {
    let bouton: BoutonBarre

    var body: some View {
        Button(L("barre.masquerBouton")) { Preferences.shared.montrer(bouton, false) }
    }
}

/// L'engrenage d'accès aux réglages. Plus discret que les bascules — pas de
/// fond, contour seulement — : c'est une porte, pas un état.
struct GearButton: View {
    @State private var survole = false

    var body: some View {
        Button {
            SettingsWindowController.shared.show()
        } label: {
            Image(systemName: "gearshape")
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(survole ? Color.jeton(\.encre) : Color.jeton(\.encreSecondaire))
                .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
                .fondEtat(EtatVisuel(survole: survole))
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .aide(L("barre.reglagesAide"))
    }
}

/// Contour d'alerte qui pulse autour d'une pastille dont le perso réclame
/// l'attention.
///
/// L'animation est portée par cette vue, et cette vue n'existe que le temps de
/// l'alerte : `repeatForever` ne tourne donc que quand il y a quelque chose à
/// montrer. Une version antérieure posait la boucle au `onAppear` de la barre
/// et l'appliquait, invisible, à toutes les pastilles — la barre se redessinait
/// deux fois par seconde en permanence, alerte ou pas.
struct AlertPulse: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous)
            .strokeBorder(Color.jeton(\.alerte), lineWidth: Jetons.Trait.etat)
            .modifier(Battement(bas: 0.2, demiPeriode: Jetons.Duree.feuille * 2))
    }
}

/// L'opacité d'un signal qui bat, pleine sous « Réduire les animations ». Remettre
/// `haut` à vrai sans animation est ce qui arrête un `repeatForever` en cours.
private struct Battement: ViewModifier {
    let bas: Double
    let demiPeriode: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var sansMouvement
    @State private var haut = true

    func body(content: Content) -> some View {
        content
            .opacity(haut ? 1 : bas)
            .onChange(of: sansMouvement, initial: true) {
                if sansMouvement {
                    haut = true
                } else {
                    withAnimation(Jetons.Duree.animation(demiPeriode).repeatForever(autoreverses: true)) {
                        haut = false
                    }
                }
            }
    }
}


/// Le témoin d'une invitation copiée : un presse-papiers en coin de pastille,
/// le temps que `InvitationClipboard` l'efface. En overlay, il ne change rien
/// à la taille de la barre.
struct CopiedBadge: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous)
            .strokeBorder(Color.jeton(\.primaire), lineWidth: Jetons.Trait.etat)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(Jetons.Typo.micro.police)
                    .foregroundStyle(Color.jeton(\.encreSurPrimaire))
                    .padding(Jetons.Espace.un)
                    .background(Circle().fill(Color.jeton(\.primaire)))
                    .offset(x: Jetons.Espace.un, y: -Jetons.Espace.un)
            }
            .transition(.opacity)
            .allowsHitTesting(false)
    }
}


/// Le perso sur lequel Synfus vient de basculer : sa pastille clignote le
/// temps que `WindowManager.basculeSignalee` la désigne, puis la vue
/// disparaît — et son animation avec elle, comme `AlertPulse`.
///
/// En enchaînant au fn-clic, l'œil est sur la carte : la seule surbrillance
/// de la pastille active ne se remarquait pas, et l'on perdait le fil. Un
/// contour qui clignote se voit du coin de l'œil, sans rien poser sur le jeu.
struct SwitchBlink: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous)
            .strokeBorder(Color.jeton(\.encreSurPrimaire), lineWidth: Jetons.Trait.focus)
            .modifier(Battement(bas: 0.1, demiPeriode: Jetons.Duree.menu))
            .allowsHitTesting(false)
    }
}

/// L'état de combat d'un perso sur sa pastille, en overlay — la barre ne
/// change pas de taille. À son tour : un contour au rose du bouton « Fin de
/// tour » et le décompte, tenu localement à partir de l'échéance lue une fois
/// (`EtatCombat.monTour`). En combat sans que ce soit son tour : une épée.
///
/// Le `TimelineView` n'existe que pendant le tour du perso : rien ne se
/// redessine chaque seconde en dehors.
struct CombatBadge: View {
    let etat: EtatCombat

    /// Le rose du bouton « Fin de tour » du jeu : la barre répète la couleur qu'on lit à l'écran, elle
    /// n'est pas à nous.
    static let rose = Color(red: 0.76, green: 0.44, blue: 0.73)

    var body: some View {
        switch etat {
        case .monTour(let fin):
            TimelineView(.periodic(from: .now, by: 1)) { contexte in
                let reste = fin.map { max(0, Int($0.timeIntervalSince(contexte.date).rounded())) }
                ZStack(alignment: .topTrailing) {
                    contourDuTour(critique: reste.map(Self.estCritique) ?? false)
                    pastille(reste.map(String.init))
                        .help(L("barre.combat.monTour", reste ?? 0))
                }
            }
            .allowsHitTesting(false)
        case .placement, .pasMonTour:
            // En combat, pas son tour : le cadre en retrait, l'épée grise.
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous)
                    .strokeBorder(Color.jeton(\.encreTertiaire), lineWidth: Jetons.Trait.etat)
                pastille(nil)
            }
            .help(L("barre.combat.enCombat"))
            .allowsHitTesting(false)
        case .horsCombat:
            EmptyView()
        }
    }

    /// En deçà, un tour qui expire se remarque sans lire le chiffre : le contour bat.
    static let secondesCritiques = 5

    static func estCritique(_ reste: Int) -> Bool { reste <= secondesCritiques }

    /// Le battement ne vit que dans les dernières secondes : hors de là, rien ne s'anime.
    @ViewBuilder
    private func contourDuTour(critique: Bool) -> some View {
        let contour = RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous)
            .strokeBorder(Self.rose, lineWidth: Jetons.Trait.focus)
        if critique {
            contour.modifier(Battement(bas: 0.3, demiPeriode: Jetons.Duree.menu))
        } else {
            contour
        }
    }

    /// Le rose du jeu marque mon tour ; hors de là, la pastille est neutre.
    private var surRose: Bool {
        if case .monTour = etat { return true }
        return false
    }

    /// Le décompte s'il est connu, l'épée sinon.
    @ViewBuilder
    private func pastille(_ texte: String?) -> some View {
        Group {
            if let texte {
                Text(texte)
                    .font(Jetons.Typo.micro.police)
                    .monospacedDigit()
                    .padding(.horizontal, Jetons.Espace.un)
            } else {
                Image(systemName: "figure.fencing")
                    .font(Jetons.Typo.micro.police)
                    .padding(Jetons.Espace.un)
            }
        }
        // Le blanc ne vaut que sur le rose du jeu ; sur l'encre du thème, c'est la couleur de la fenêtre qui contraste.
        .foregroundStyle(surRose ? Color.white : Color.jeton(\.fenetre))
        .background(Capsule().fill(surRose ? Self.rose : Color.jeton(\.encreSecondaire)))
        .offset(x: Jetons.Espace.un, y: -Jetons.Espace.un)
    }
}
