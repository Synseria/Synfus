import AppKit
import SwiftUI

/// La vue d'une carte en grand, au survol de sa miniature dans le panneau des
/// quêtes : un panneau à part, à côté de celui des quêtes (trop étroit pour
/// elle), qui laisse passer la souris — il ne vole pas le survol qui l'a
/// ouvert.
@MainActor
final class ApercuCarte {
    static let shared = ApercuCarte()

    /// La demi-taille de DofusDB, telle quelle.
    private static let taille = NSSize(width: 638, height: 438)
    private static let marge: CGFloat = 8

    private var panel: NSPanel?
    private var hote: NSHostingView<AnyView>?

    private init() {}

    func montrer(_ carte: Int) {
        guard let cadre = QuetePanel.shared.cadre,
              let ecran = NSScreen.screens.first(where: { $0.frame.intersects(cadre) })?.visibleFrame
        else { return }
        let panel = panel ?? construire()
        hote?.rootView = AnyView(vue(carte))
        let taille = Self.taille
        // À gauche du panneau s'il y a la place, à droite sinon ; à hauteur de
        // la souris, dans l'écran.
        let gauche = cadre.minX - Self.marge - taille.width
        let x = gauche >= ecran.minX ? gauche : min(cadre.maxX + Self.marge, ecran.maxX - taille.width)
        let y = min(max(NSEvent.mouseLocation.y - taille.height / 2, ecran.minY), ecran.maxY - taille.height)
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: taille), display: true)
        panel.orderFrontRegardless()
    }

    func cacher() {
        panel?.orderOut(nil)
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
