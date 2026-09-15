import SwiftUI

/// Poignée de déplacement adossée à AppKit.
///
/// `performDrag(with:)` confie le déplacement au gestionnaire de fenêtres du
/// système : la fenêtre suit le curseur au rythme du compositeur. Une version
/// SwiftUI à base de `DragGesture` qui repositionne la fenêtre à chaque
/// évènement reste toujours un cran derrière la souris — c'est ce qui rendait
/// la barre poussive.
///
/// La vue est posée **par-dessus** la poignée (`overlay`), pas derrière : sous
/// un `glassEffect`, ce qui est en fond ne reçoit plus le clic. Et le panneau
/// n'est jamais fenêtre clé : sans `acceptsFirstMouse`, le premier clic ne
/// servirait qu'à le « réveiller » et le glisser ne partirait pas.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }

        /// Le curseur dit ce que la zone fait : main ouverte au survol, fermée
        /// pendant le glisser. Les `cursorRects` seuls ne suffisent pas sur un
        /// panneau non-clé — une zone de suivi les remplace.
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            addTrackingArea(NSTrackingArea(rect: bounds,
                                           options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                           owner: self, userInfo: nil))
        }
        // `cursorUpdate` n'est pas livré à un panneau qui n'est jamais clé :
        // on pose le curseur nous-mêmes à l'entrée, et on le rend à la sortie.
        override func mouseEntered(with event: NSEvent) { NSCursor.openHand.set() }
        override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }
        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.set()
            window?.performDrag(with: event)
            NSCursor.openHand.set()
        }
    }
}

/// Fond de la barre : Liquid Glass sur macOS 26, matériau translucide en deçà.
/// Un seul binaire couvre les deux — la bascule se fait à l'exécution, il n'y a
/// donc pas de build séparé à maintenir pour les versions antérieures.
struct BarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
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

/// Gabarit commun des bascules de mode — flèche d'enchaînement, éclair du
/// passage automatique. Au repos le bouton est nu : le fond n'apparaît qu'au
/// survol ou quand le mode est actif, la barre ne montre plus une rangée de
/// carrés gris en permanence.
struct ModeButton: View {
    let icone: String
    let teinte: Color
    let actif: Bool
    let aide: String
    let action: () -> Void
    @State private var survole = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icone)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(actif ? teinte : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22, height: 22)
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
        .help(aide)
    }

    private var fond: Color {
        if actif { return teinte.opacity(survole ? 0.22 : 0.18) }
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
        Button("Tout en plein écran") { Task { await WindowArranger.shared.toutEnPleinEcran() } }
        Button("Tout sortir du plein écran") { Task { await WindowArranger.shared.toutSortirDuPleinEcran() } }
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
            Button("Lancer la session") { WindowManager.shared.lancerSession() }
        } label: {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(survole ? Color.primary.opacity(0.08) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { survole = $0 }
        .animation(.easeOut(duration: 0.15), value: survole)
        .help("Ranger les fenêtres — dispositions, plein écran, lancer la session")
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
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(survole ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                .frame(width: 22, height: 22)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .help("Réglages de Synfus")
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
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.orange, lineWidth: 1.5)
            .opacity(pulse ? 1 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    pulse = true
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
            .strokeBorder(Color.accentColor, lineWidth: 1.5)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(Circle().fill(Color.accentColor))
                    .offset(x: 4, y: -4)
            }
            .transition(.opacity)
            .allowsHitTesting(false)
    }
}
