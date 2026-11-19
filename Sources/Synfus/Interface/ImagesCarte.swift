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
        hote?.rootView = AnyView(vue(carte).racineSynfus())
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
            .clipShape(RoundedRectangle(cornerRadius: Jetons.rayon1, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Jetons.rayon1, style: .continuous).strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.epaisseurFilet))
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
        panel.hasShadow = false
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
                .clipShape(RoundedRectangle(cornerRadius: Jetons.rayon0, style: .continuous))
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

/// Le fond d'une carte de la palette : la carte du jeu sous un seul voile continu, dense sous le texte
/// du haut (titre, sous-titre) et du bas (étiquette, coordonnées), plus léger entre les deux, jamais
/// de bord net ; la plaque sans elle. Choisie, le contour de l'accent sur l'image, le fond du choix
/// sur la plaque.
struct FondCarte: View {
    let carte: Int?
    var choisie = false
    var survole = false
    /// Où finit le texte du haut et où commence celui du bas, en part de la hauteur de la carte : le
    /// voile y est encore dense (1 : pas de pied).
    var finHaut: CGFloat = 0.5
    var debutBas: CGFloat = 1
    private let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
    /// Plus large qu'une case de la grille (trois au rang sur la largeur de la palette), que l'image remplit.
    private static let cote: CGFloat = 240
    /// L'opacité du voile aux bords, sous le titre et les coordonnées ; à la lisière du texte, où se
    /// lit encore le sous-titre ; entre les deux, où l'image reste assombrie : du texte clair se lit
    /// sur n'importe quel décor du jeu, et aucune bande vive ne raye la carte.
    private static let voileBord = 0.85
    private static let voileTexte = 0.72
    private static let voileMilieu = 0.55

    /// Le texte de la carte se pose sur une image : il s'écrit en clair, quel que soit le thème.
    @MainActor static func surImage(_ carte: Int?) -> Bool {
        carte != nil && Preferences.shared.vuesCartes && Ressources.visuelsDuJeu
    }

    var body: some View {
        if Self.surImage(carte), let carte {
            let voile = Color.jeton(\.fondFenetre, en: .nuit)
            Color.jeton(\.creux)
                .overlay { VueCarte(carte: carte, cote: Self.cote).scaledToFill() }
                .overlay {
                    // Seul dégradé de l'app : un voile d'un bord à l'autre, sans palier.
                    LinearGradient(stops: [
                        .init(color: voile.opacity(Self.voileBord), location: 0),
                        .init(color: voile.opacity(Self.voileTexte), location: finHaut),
                        .init(color: voile.opacity(Self.voileMilieu), location: (finHaut + debutBas) / 2),
                        .init(color: voile.opacity(debutBas < 1 ? Self.voileTexte : Self.voileMilieu), location: debutBas),
                        .init(color: voile.opacity(Self.voileBord), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
                .clipShape(forme)
                .overlay {
                    forme.strokeBorder(Color.jeton(choisie ? \.accent : survole ? \.encre3 : \.filet),
                                       lineWidth: choisie ? Jetons.epaisseurFocus : Jetons.epaisseurFilet)
                }
        } else {
            ZStack {
                forme.fill(Color.jeton(\.plaque))
                if choisie || survole { forme.fill(Color.jeton(choisie ? \.selection : \.survol)) }
            }
            .overlay { forme.strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.epaisseurFilet) }
        }
    }
}

/// La loupe d'une carte de la palette : la vue de la carte en grand (`ApercuCarte`) au survol de ce seul
/// bouton, après un court délai — un passage de la souris sur la grille n'ouvre rien —, ou d'un clic.
/// `surImage` : posée sur le voile, dessinée en Nuit.
struct LoupeCarte: View {
    let carte: Int
    var surImage = false
    @State private var attente: Task<Void, Never>?
    /// Le temps de viser la loupe plutôt que de la traverser.
    private static let delai: Duration = .milliseconds(250)

    var body: some View {
        Button { ApercuCarte.shared.montrer(carte) } label: {
            Image(systemName: "magnifyingglass")
                .font(Jetons.typoMicro.font)
        }
        .buttonStyle(BoutonIcone())
        .focusable(false)
        .themeSynseria(ThemeCourant.reglage.theme, nuance: surImage ? .nuit : ThemeCourant.reglage.nuance)
        .accessibilityLabel(L("palette.carte.agrandir"))
        .onHover { dedans in
            attente?.cancel()
            if dedans {
                attente = Task {
                    try? await Task.sleep(for: Self.delai)
                    if !Task.isCancelled { ApercuCarte.shared.montrer(carte) }
                }
            } else {
                ApercuCarte.shared.cacher()
            }
        }
        .onDisappear {
            attente?.cancel()
            ApercuCarte.shared.cacher()
        }
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
