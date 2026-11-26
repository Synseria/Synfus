import AppKit
import SwiftUI
import SynseriaDesign

// Le redimensionnement des panneaux posés sur le jeu : bords à saisir, tailles minimale et
// maximale, largeur suivie par la vue de ceux qui prennent la hauteur de leur contenu.

/// Les bords qu'une poignée déplace. Le haut n'en est pas : c'est l'en-tête, qui déplace le panneau.
struct BordsPanneau: OptionSet, Sendable {
    let rawValue: Int

    static let gauche = BordsPanneau(rawValue: 1)
    static let droite = BordsPanneau(rawValue: 2)
    static let bas = BordsPanneau(rawValue: 4)
    /// Ceux d'un panneau à la hauteur de son contenu : la largeur seule se règle.
    static let cotes: BordsPanneau = [.gauche, .droite]
    static let tous: BordsPanneau = [.gauche, .droite, .bas]

    /// Le cadre après un glisser de `decalage` (repère de l'écran, y vers le haut) : le bord haut ne
    /// bouge jamais, ni le bord opposé à celui qu'on tire, et la taille reste entre `minimum` et
    /// `maximum`. Sans `.bas`, la hauteur est celle de `depart`.
    func cadre(_ depart: NSRect, decalage: CGVector, minimum: NSSize, maximum: NSSize) -> NSRect {
        func borne(_ valeur: CGFloat, _ bas: CGFloat, _ haut: CGFloat) -> CGFloat { min(max(valeur, bas), max(bas, haut)) }
        var largeur = depart.width, hauteur = depart.height, x = depart.minX
        if contains(.droite) { largeur = borne(depart.width + decalage.dx, minimum.width, maximum.width) }
        if contains(.gauche) {
            largeur = borne(depart.width - decalage.dx, minimum.width, maximum.width)
            x = depart.maxX - largeur
        }
        if contains(.bas) { hauteur = borne(depart.height - decalage.dy, minimum.height, maximum.height) }
        return NSRect(x: x, y: depart.maxY - hauteur, width: largeur, height: hauteur)
    }
}

extension View {
    /// Les bords donnés, et les coins du bas avec `.bas`, à saisir pour agrandir le panneau, sans
    /// marque : tout panneau posé sur le jeu s'agrandit, le curseur le dit au survol. Les coins passent
    /// par-dessus les bords : saisi près d'un coin, le panneau s'agrandit dans les deux sens.
    func bordsRedimensionnables(_ bords: BordsPanneau = .tous) -> some View {
        let epaisseur: CGFloat = 6, cote: CGFloat = 14
        return overlay(alignment: .leading) {
            if bords.contains(.gauche) { PoigneeRedimension(bords: .gauche).frame(width: epaisseur) }
        }
        .overlay(alignment: .trailing) {
            if bords.contains(.droite) { PoigneeRedimension(bords: .droite).frame(width: epaisseur) }
        }
        .overlay(alignment: .bottom) {
            if bords.contains(.bas) { PoigneeRedimension(bords: .bas).frame(height: epaisseur) }
        }
        .overlay(alignment: .bottomLeading) {
            if bords.isSuperset(of: [.gauche, .bas]) { PoigneeRedimension(bords: [.gauche, .bas]).frame(width: cote, height: cote) }
        }
        .overlay(alignment: .bottomTrailing) {
            if bords.isSuperset(of: [.droite, .bas]) { PoigneeRedimension(bords: [.droite, .bas]).frame(width: cote, height: cote) }
        }
    }
}

/// Une poignée de redimensionnement : un glisser déplace les bords donnés, le bord haut ne bouge pas,
/// la taille reste entre `minSize` et `maxSize` de la fenêtre. Une boucle d'évènements à soi plutôt
/// que les bords du système (le panneau n'est pas `.resizable`) : minces sans bordure, et sans
/// curseur dans une app inactive. Le sien est posé à l'entrée, à l'appui et à chaque pas du glisser
/// — le jeu, devant, réimpose le sien.
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
                // Sans le bas, la hauteur est celle du moment : le contenu, qui se replie autrement,
                // la change pendant le glisser.
                var base = cadre
                if !bords.contains(.bas) { base.origin.y = window.frame.minY; base.size.height = window.frame.height }
                window.setFrame(bords.cadre(base, decalage: CGVector(dx: point.x - depart.x, dy: point.y - depart.y),
                                            minimum: window.minSize, maximum: window.maxSize),
                                display: true)
                curseur.set()
            }
        }
    }
}

/// La largeur d'un panneau à la hauteur de son contenu : celle de sa fenêtre, que la vue reprend
/// (`largeurPanneau`) — la fenêtre suit la taille de sa vue, la vue doit suivre les poignées.
@MainActor
final class LargeurPanneau: ObservableObject {
    @Published var valeur: CGFloat
    init(_ valeur: CGFloat) { self.valeur = valeur }
}

extension EnvironmentValues {
    /// La largeur choisie du panneau qui montre la vue ; `nil` hors d'un panneau (captures).
    @Entry var largeurPanneau: CGFloat?
}

/// La racine d'un panneau à largeur réglable : sa vue reçoit la largeur de la fenêtre.
struct AvecLargeurPanneau<Contenu: View>: View {
    @ObservedObject var largeur: LargeurPanneau
    let contenu: Contenu

    var body: some View {
        contenu.environment(\.largeurPanneau, largeur.valeur)
    }
}
