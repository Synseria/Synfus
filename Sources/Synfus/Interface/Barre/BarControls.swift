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

/// Fond de la barre : Liquid Glass sur macOS 26, matériau translucide en deçà.
/// Un seul binaire couvre les deux — la bascule se fait à l'exécution, il n'y a
/// donc pas de build séparé à maintenir pour les versions antérieures.
struct BarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if Ressources.captureDocumentation {
            // `cacheDisplay` ne dessine ni le verre ni les matériaux, qui
            // échantillonnent l'écran : un fond plein, à leur teinte.
            content.background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(white: 0.2))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 13))
        } else {
            content.background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            )
        }
    }
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
                .font(.synfus(.note))
                .foregroundStyle(actif ? Couleurs.accentTexte : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(fond)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .animation(.easeOut(duration: 0.15), value: survole)
        .animation(.easeOut(duration: 0.15), value: actif)
        .aide(aide)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }

    private var fond: Color {
        if actif { return Couleurs.accent.opacity(survole ? 0.22 : 0.18) }
        return survole ? Color.primary.opacity(0.08) : .clear
    }
}

/// Les entrées du menu de rangement — les mêmes sous le bouton de la barre et
/// dans son menu contextuel, écrites une fois.
struct ArrangementMenuItems: View {
    var body: some View {
        ForEach(Disposition.allCases) { disposition in
            Button {
                Task { await WindowArranger.shared.appliquer(disposition) }
            } label: {
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
    @State private var survole = false

    var body: some View {
        Menu {
            ArrangementMenuItems()
            Divider()
            Button(L("menu.lancerSession")) { WindowManager.shared.lancerSession() }
        } label: {
            Image(systemName: "rectangle.3.group")
                .font(.synfus(.note))
                .foregroundStyle(Color.secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(survole ? Color.primary.opacity(0.08) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .tint(Color.secondary)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { survole = $0 }
        .animation(.easeOut(duration: 0.15), value: survole)
        .aide(L("barre.rangerAide"))
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
                .font(.synfus(.petit))
                .foregroundStyle(survole ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                .frame(width: 24, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .aide(L("barre.reglagesAide"))
    }
}

/// Contour orange qui pulse autour d'une pastille dont le perso réclame
/// l'attention.
///
/// L'animation est portée par cette vue, et cette vue n'existe que le temps de
/// l'alerte : `repeatForever` ne tourne donc que quand il y a quelque chose à
/// montrer. Une version antérieure posait la boucle au `onAppear` de la barre
/// et l'appliquait, invisible, à toutes les pastilles — la barre se redessinait
/// deux fois par seconde en permanence, alerte ou pas.
struct AlertPulse: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Couleurs.alerte, lineWidth: 1.5)
            .modifier(Battement(bas: 0.2, demiPeriode: 0.55))
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
                    withAnimation(.easeInOut(duration: demiPeriode).repeatForever(autoreverses: true)) {
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
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Couleurs.accent, lineWidth: 1.5)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.synfus(.marque, gras: true))
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(Circle().fill(Couleurs.accentPlein))
                    .offset(x: 4, y: -4)
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
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.white, lineWidth: 2)
            .shadow(color: Couleurs.accent, radius: 4)
            .modifier(Battement(bas: 0.1, demiPeriode: 0.2))
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

    static let rose = Color(red: 0.76, green: 0.44, blue: 0.73)

    var body: some View {
        switch etat {
        case .monTour(let fin):
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Self.rose, lineWidth: 2)
                TimelineView(.periodic(from: .now, by: 1)) { contexte in
                    pastille(fin.map { "\(max(0, Int($0.timeIntervalSince(contexte.date).rounded())))" })
                        .help(L("barre.combat.monTour",
                                fin.map { max(0, Int($0.timeIntervalSince(contexte.date).rounded())) } ?? 0))
                }
            }
            .allowsHitTesting(false)
        case .placement, .pasMonTour:
            // En combat, pas son tour : le cadre en retrait, l'épée grise.
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Self.rose.opacity(0.4), lineWidth: 1.5)
                pastille(nil).opacity(0.8)
            }
            .help(L("barre.combat.enCombat"))
            .allowsHitTesting(false)
        case .horsCombat:
            EmptyView()
        }
    }

    /// Le décompte s'il est connu, l'épée sinon.
    @ViewBuilder
    private func pastille(_ texte: String?) -> some View {
        Group {
            if let texte {
                Text(texte)
                    .font(.synfus(.marque, gras: true, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 3)
            } else {
                Image(systemName: "figure.fencing")
                    .font(.synfus(.marque, gras: true))
                    .padding(2)
            }
        }
        .foregroundStyle(.white)
        .background(Capsule().fill(etat.enCombat && etat != .pasMonTour && etat != .placement ? Self.rose : Color.gray))
        .offset(x: 5, y: -5)
    }
}
