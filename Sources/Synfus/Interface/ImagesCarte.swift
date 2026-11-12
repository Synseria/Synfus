import AppKit
import SwiftUI

// Les images de la carte du jeu dans l'interface : la vue d'une carte en
// vignette, agrandie au survol, et le pictogramme d'un repère. Toutes viennent
// de DofusDB (`ImagesDofusDB`), jamais du dépôt.

/// La vue d'une carte en grand, au survol de sa vignette : un panneau à part,
/// à côté de la fenêtre de la vignette (palette, réglages, panneau des
/// quêtes), qui laisse passer la souris — il ne vole pas le survol qui l'a
/// ouvert — et ne prend jamais le clavier : sans bordure, il ne peut devenir
/// clé, et la palette garde sa frappe.
@MainActor
final class ApercuCarte {
    static let shared = ApercuCarte()

    /// La demi-taille de DofusDB, telle quelle.
    private static let taille = NSSize(width: 638, height: 438)
    nonisolated private static let marge: CGFloat = 8

    private var panel: NSPanel?
    private var hote: NSHostingView<AnyView>?

    private init() {}

    func montrer(_ carte: Int) {
        let souris = NSEvent.mouseLocation
        guard let ecran = NSScreen.screens.first(where: { $0.frame.contains(souris) })?.visibleFrame else { return }
        let panel = panel ?? construire()
        hote?.rootView = AnyView(vue(carte))
        let cadre = Self.cadre(taille: Self.taille, fenetre: fenetreSous(souris), souris: souris, ecran: ecran)
        panel.setFrame(cadre, display: true)
        panel.orderFrontRegardless()
    }

    func cacher() {
        panel?.orderOut(nil)
    }

    /// À gauche de la fenêtre s'il y a la place, à droite sinon ; à défaut,
    /// à gauche de la souris — par-dessus la fenêtre, pas sur la vignette.
    /// À hauteur de la souris, dans l'écran.
    nonisolated static func cadre(taille: NSSize, fenetre: NSRect?, souris: NSPoint, ecran: NSRect) -> NSRect {
        let x: CGFloat
        if let fenetre, fenetre.minX - marge - taille.width >= ecran.minX {
            x = fenetre.minX - marge - taille.width
        } else if let fenetre, fenetre.maxX + marge + taille.width <= ecran.maxX {
            x = fenetre.maxX + marge
        } else {
            x = max(souris.x - 3 * marge - taille.width, ecran.minX)
        }
        let y = min(max(souris.y - taille.height / 2, ecran.minY), ecran.maxY - taille.height)
        return NSRect(origin: NSPoint(x: x, y: y), size: taille)
    }

    /// La fenêtre de Synfus sous la souris : celle de la vignette survolée.
    private func fenetreSous(_ point: NSPoint) -> NSRect? {
        let numero = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        guard let fenetre = NSApp.window(withWindowNumber: numero), fenetre !== panel else { return nil }
        return fenetre.frame
    }

    private func vue(_ carte: Int) -> some View {
        VueCarte(carte: carte, cote: max(Self.taille.width, Self.taille.height))
            .aspectRatio(contentMode: .fit)
            .background(Color.jeton(\.creux))
            .clipShape(RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous).strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.Trait.filet))
    }

    private func construire() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.taille),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let hote = NSHostingView(rootView: AnyView(EmptyView()))
        panel.contentView = hote
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel
        self.hote = hote
        return panel
    }
}

/// La vue d'une carte du jeu, réduite à ce qu'elle occupe : deux pixels par
/// point de son plus grand côté (`cote`), jamais plus que l'image. Le seul
/// chemin des vues de carte vers `ImagesDofusDB` : entière, une vue décodée
/// pèse 1,8 Mo et resterait en mémoire pour de bon.
struct VueCarte: View {
    let carte: Int
    /// En points.
    let cote: CGFloat

    var body: some View {
        ImageDofusDB(url: DofusDB.imageCarte(carte), cote: Int(2 * cote))
    }
}

/// La vue d'une carte en vignette, réduite hors du fil principal ; au survol,
/// en grand (`apercuCarteAuSurvol`), sauf quand c'est la ligne qui la porte
/// qui l'agrandit. Rien quand les vues des cartes sont coupées
/// (`Preferences.vuesCartes`).
struct MiniatureCarte: View {
    let carte: Int
    var taille = CGSize(width: 52, height: 36)
    var agrandir = true
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        if prefs.vuesCartes, Ressources.visuelsDuJeu {
            VueCarte(carte: carte, cote: max(taille.width, taille.height))
                .aspectRatio(contentMode: .fill)
                .frame(width: taille.width, height: taille.height)
                .background(Color.jeton(\.creux))
                .clipShape(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille, style: .continuous))
                .apercuCarteAuSurvol(agrandir ? carte : nil)
        }
    }
}

extension View {
    /// La vue de `carte` en grand (`ApercuCarte`) tant que la souris est sur
    /// cette vue, cachée quand elle en sort ou disparaît ; rien sans carte ni
    /// quand les vues des cartes sont coupées. `onHover` suit la souris même
    /// sur un panneau jamais clé d'une app inactive (ses zones de suivi sont
    /// actives en permanence, comme celles des pastilles de la barre) — une
    /// bulle d'aide, elle, n'y apparaît pas.
    func apercuCarteAuSurvol(_ carte: Int?) -> some View {
        onHover { dedans in
            if dedans, let carte, Preferences.shared.vuesCartes, Ressources.visuelsDuJeu {
                ApercuCarte.shared.montrer(carte)
            } else if carte != nil {
                ApercuCarte.shared.cacher()
            }
        }
        .onDisappear { if carte != nil { ApercuCarte.shared.cacher() } }
    }
}

/// Le fond d'une case de zaap — réglages et palette : la vue de sa carte à
/// un quart d'opacité sur un fond uni, assombrie vers le bas où sont la zone
/// et les coordonnées, pour que le texte reste lisible sur n'importe quelle
/// carte ; `teinte` (la case choisie) par-dessus. Le fond uni tient la taille
/// de la case, l'image en déborde et la forme la rogne.
struct FondCarte: View {
    let carte: Int?
    /// Choisie, la case prend le contour `primaire` ; son fond ne se teinte que sans image, qu'un
    /// voile de couleur salirait.
    var choisie = false
    @ObservedObject private var prefs = Preferences.shared
    private let forme = RoundedRectangle(cornerRadius: Jetons.Rayon.carte, style: .continuous)
    /// Plus large qu'une case de la grille (palette : 4 au rang sur 660 pt ;
    /// réglages : 3), que l'image remplit.
    private static let cote: CGFloat = 200
    private static let voileImage = 0.25
    private static let voileTexte = 0.7

    var body: some View {
        if prefs.vuesCartes, Ressources.visuelsDuJeu, let carte {
            // L'image ne sert que d'ambiance et le texte de la case passe dessus : elle est voilée de
            // `surface`, plus franchement vers le bas où le texte se pose. Seul dégradé de l'app.
            Color.jeton(\.surface)
                .overlay { VueCarte(carte: carte, cote: Self.cote).scaledToFill().opacity(Self.voileImage) }
                .overlay {
                    LinearGradient(colors: [.clear, Color.jeton(\.surface).opacity(Self.voileTexte)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .clipShape(forme)
                .overlay(contour)
        } else {
            forme.fill(choisie ? Color.jeton(\.primaireFond) : Color.jeton(\.surface)).overlay(contour)
        }
    }

    private var contour: some View {
        forme.strokeBorder(choisie ? Color.jeton(\.primaire) : Color.jeton(\.filet),
                           lineWidth: choisie ? Jetons.Trait.etat : Jetons.Trait.filet)
    }
}

/// Le pictogramme d'un repère tel que la carte du jeu le montre ; le symbole
/// tant qu'il n'est pas venu, ou quand le repère n'en a pas.
struct PictogrammeLieu<Symbole: View>: View {
    let gfx: Int?
    @ViewBuilder let symbole: Symbole

    var body: some View {
        if let gfx {
            ImageDofusDB(url: DofusDB.pictogramme(gfx)) { symbole }
                .aspectRatio(contentMode: .fit)
        } else {
            symbole
        }
    }
}
