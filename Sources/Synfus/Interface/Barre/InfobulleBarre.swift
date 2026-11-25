import AppKit
import SwiftUI

/// L'infobulle de la barre, dans sa **propre fenêtre** : un panneau de jeu rogne
/// ce qu'il rend au-delà de ses bords (celle sous une pastille y était coupée),
/// et la barre est en haut de l'écran, où l'infobulle système (`.help`) serait
/// rognée elle aussi. Ici : nom à gauche, raccourci à droite quand il existe,
/// posée **sous** le contrôle survolé.
///
/// La fenêtre n'est jamais clé et ignore la souris : elle ne prend ni le clavier
/// au jeu, ni le clic. Elle se montre après un bref survol (le délai est posé par
/// l'appelant, comme l'aperçu) et se cache au départ de la souris.
@MainActor
final class InfobulleBarre: ObservableObject {
    static let shared = InfobulleBarre()

    /// Le contenu montré : nom, et raccourci à droite quand il existe.
    @Published private(set) var nom: String?
    @Published private(set) var touche: String?

    private var fenetre: NSPanel?
    private var hosting: NSHostingController<AnyView>?

    private init() {}

    /// Montre l'infobulle sous `cadre` (coordonnées écran du contrôle).
    func montrer(nom: String, touche: String?, sous cadre: CGRect) {
        self.nom = nom
        self.touche = touche
        let fenetre = fenetre ?? construire()
        guard let hosting else { return }
        // Taille au contenu, puis pose sous le contrôle, dans les limites de l'écran.
        hosting.rootView = AnyView(InfobulleVue(nom: nom, touche: touche).racineSynfus())
        let taille = hosting.view.fittingSize
        let centre = NSPoint(x: cadre.midX, y: cadre.midY)
        guard let ecran = NSScreen.screens.first(where: { $0.frame.contains(centre) }) ?? NSScreen.main
        else { return cacher() }
        let visible = ecran.visibleFrame
        let x = min(max(cadre.midX - taille.width / 2, visible.minX + 4), visible.maxX - taille.width - 4)
        let y = cadre.minY - taille.height - 6
        fenetre.setFrame(NSRect(x: x, y: max(y, visible.minY + 4), width: taille.width, height: taille.height),
                         display: true)
        fenetre.orderFrontRegardless()
    }

    func cacher() {
        nom = nil
        touche = nil
        fenetre?.orderOut(nil)
    }

    private func construire() -> NSPanel {
        let hosting = NSHostingController(rootView: AnyView(InfobulleVue(nom: nil, touche: nil).racineSynfus()))
        hosting.sizingOptions = [.preferredContentSize]
        let fenetre = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 80, height: 24),
                              styleMask: [.nonactivatingPanel, .borderless],
                              backing: .buffered, defer: false)
        fenetre.contentViewController = hosting
        fenetre.level = .statusBar + 1
        fenetre.backgroundColor = .clear
        fenetre.isOpaque = false
        fenetre.hasShadow = true
        fenetre.ignoresMouseEvents = true
        fenetre.hidesOnDeactivate = false
        fenetre.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.hosting = hosting
        self.fenetre = fenetre
        return fenetre
    }
}

extension View {
    /// L'infobulle flottante de la barre **sous** ce contrôle, après un bref
    /// survol (0,5 s) : nom à gauche, raccourci à droite. Le cadre du contrôle
    /// se lit dans le repère de la barre, converti en coordonnées écran.
    func infobulleBarre(nom: String, touche: String?) -> some View {
        modifier(InfobulleFlottante(nom: nom, touche: touche))
    }
}

private struct InfobulleFlottante: ViewModifier {
    let nom: String
    let touche: String?
    @State private var survole = false
    @State private var cadre: CGRect = .zero
    @State private var attente: Task<Void, Never>?

    private static let delai: Duration = .milliseconds(500)

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                let cadre = geo.frame(in: .named(BarView.barSpace))
                Color.clear
                    .onAppear { self.cadre = cadre }
                    .onChange(of: cadre) { _, nouveau in self.cadre = nouveau }
            })
            .onHover { dedans in
                survole = dedans
                attente?.cancel()
                if dedans {
                    attente = Task {
                        try? await Task.sleep(for: Self.delai)
                        guard !Task.isCancelled, survole,
                              let ecran = FloatingBarController.shared.screenFrame(fromBarFrame: cadre)
                        else { return }
                        InfobulleBarre.shared.montrer(nom: nom, touche: touche, sous: ecran)
                    }
                } else {
                    InfobulleBarre.shared.cacher()
                }
            }
    }
}

/// Le dessin de l'infobulle : la pastille de la barre, nom et touche.
private struct InfobulleVue: View {
    let nom: String?
    let touche: String?

    var body: some View {
        HStack(spacing: Jetons.espace3) {
            if let nom { Text(nom).lineLimit(1) }
            if let touche {
                Text(touche)
                    .font(Jetons.typoMicro.font)
                    .foregroundStyle(Color.jeton(\.encre2))
            }
        }
        .font(Jetons.typoMeta.font)
        .foregroundStyle(Color.jeton(\.encre))
        .padding(.horizontal, Jetons.espace2)
        .padding(.vertical, Jetons.espace1)
        .background(Capsule().fill(Color.jeton(\.plaque)))
        .overlay(Capsule().strokeBorder(Color.traitSurVerre, lineWidth: Jetons.epaisseurFilet))
        .fixedSize()
    }
}
