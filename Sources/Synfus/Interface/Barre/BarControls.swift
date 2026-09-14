import SwiftUI

/// Poignée de déplacement adossée à AppKit.
///
/// `performDrag(with:)` confie le déplacement au gestionnaire de fenêtres du
/// système : la fenêtre suit le curseur au rythme du compositeur. Une version
/// SwiftUI à base de `DragGesture` qui repositionne la fenêtre à chaque
/// évènement reste toujours un cran derrière la souris — c'est ce qui rendait
/// la barre poussive.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
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

/// Le menu de rangement des fenêtres, au gabarit des bascules de mode. Un menu
/// et non une bascule : il propose des gestes, il ne porte pas d'état.
struct ArrangeMenuButton: View {
    @State private var survole = false

    var body: some View {
        Menu {
            ForEach(Disposition.allCases) { disposition in
                Button {
                    WindowArranger.shared.appliquer(disposition)
                } label: {
                    Label(disposition.label, systemImage: disposition.symbolName)
                }
            }
            Divider()
            Button("Tout en plein écran") { WindowArranger.shared.toutEnPleinEcran() }
            Button("Tout sortir du plein écran") { WindowArranger.shared.toutSortirDuPleinEcran() }
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

