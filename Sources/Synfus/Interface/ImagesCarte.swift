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
        ImageDofusDB(url: DofusDB.imageCarte(carte))
            .aspectRatio(contentMode: .fit)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.15)))
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

/// La vue d'une carte en vignette, réduite hors du fil principal ; au survol,
/// en grand (`ApercuCarte`). Rien quand les vues des cartes sont coupées
/// (`Preferences.vuesCartes`). `onHover` suit la souris même sur un panneau
/// jamais clé d'une app inactive (ses zones de suivi sont actives en
/// permanence, comme celles des pastilles de la barre) — une bulle d'aide,
/// elle, n'y apparaît pas.
struct MiniatureCarte: View {
    let carte: Int
    var taille = CGSize(width: 52, height: 36)
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        if prefs.vuesCartes {
            // Deux pixels par point : nette sur un écran Retina.
            ImageDofusDB(url: DofusDB.imageCarte(carte), cote: Int(2 * max(taille.width, taille.height)))
                .aspectRatio(contentMode: .fill)
                .frame(width: taille.width, height: taille.height)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .onHover { dedans in
                    if dedans { ApercuCarte.shared.montrer(carte) } else { ApercuCarte.shared.cacher() }
                }
                .onDisappear { ApercuCarte.shared.cacher() }
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
