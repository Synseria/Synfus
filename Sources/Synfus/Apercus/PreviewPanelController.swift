import AppKit
import SwiftUI

/// Panneau d'aperçu : passif, au-dessus du jeu, jamais dans le chemin du clavier
/// ni de la souris.
private final class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Affiche les vignettes des fenêtres, soit une seule au survol d'une pastille,
/// soit toutes en grille tant qu'un raccourci est maintenu.
///
/// C'est un panneau distinct de la barre, et non un `popover` greffé dedans : la
/// barre se dimensionne sur son contenu (`fixedSize` + `preferredContentSize`) et
/// se recentre à chaque changement de taille — y insérer un aperçu la ferait
/// sauter à chaque survol.
@MainActor
final class PreviewPanelController: NSObject, ObservableObject {
    static let shared = PreviewPanelController()

    enum Mode: Equatable {
        /// Un seul perso, ancré sous sa pastille.
        case single(DofusClient)
        /// Tous les persos, en grille au centre de l'écran.
        case grid([DofusClient])

        var clients: [DofusClient] {
            switch self {
            case .single(let client): return [client]
            case .grid(let clients): return clients
            }
        }
    }

    @Published private(set) var mode: Mode?

    private var panel: NSPanel?
    /// Cadre écran de la pastille survolée, sous laquelle l'aperçu se place.
    private var anchor: CGRect?
    private var timer: Timer?

    private override init() { super.init() }

    // MARK: - Affichage

    /// Aperçu d'un seul perso, sous la pastille dont le cadre est donné en
    /// coordonnées écran.
    func show(_ client: DofusClient, below rect: CGRect) {
        anchor = rect
        present(.single(client))
    }

    /// Grille de tous les persos, au centre de l'écran.
    func showGrid(_ clients: [DofusClient]) {
        guard !clients.isEmpty else { return }
        anchor = nil
        present(.grid(clients))
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        mode = nil
        anchor = nil
        panel?.orderOut(nil)
    }

    /// Masque l'aperçu s'il montre ce perso-là — le survol d'une pastille ne doit
    /// pas fermer l'aperçu qu'un autre survol vient d'ouvrir.
    ///
    /// La comparaison porte sur l'**identité** (`slotKey`), pas sur l'égalité de
    /// `DofusClient` : celle-ci regarde aussi `dormant` et le nom, qu'un
    /// `refresh()` peut changer entre l'entrée et la sortie du survol — un perso
    /// passé dormant ou en cours de fermeture n'était plus « le même », et
    /// l'aperçu restait affiché.
    func hide(ifShowing client: DofusClient) {
        guard case .single(let shown) = mode, shown.slotKey == client.slotKey else { return }
        hide()
    }

    /// Masque l'aperçu ancré sous une pastille. La grille, elle, n'est liée à
    /// aucune pastille : elle suit le raccourci maintenu, pas la barre.
    func hideAnchored() {
        guard case .single = mode else { return }
        hide()
    }

    /// Réaligne l'aperçu sur la liste des persos : un perso qui n'y figure plus
    /// — déconnecté, fermé, ou dont la fermeture vient d'être demandée — n'a plus
    /// de vignette à montrer. Sans ce point d'appel, l'aperçu ouvert sur une
    /// pastille survivait à la fermeture du perso : le menu contextuel a déjà
    /// emporté le `mouseExited`, plus rien ne venait le fermer.
    func reconcile(with clients: [DofusClient]) {
        let next = Self.surviving(mode, among: clients)
        guard next != mode else { return }
        if next == nil { hide() } else { mode = next }
    }

    /// Règle pure : que reste-t-il de l'aperçu une fois la liste des persos mise
    /// à jour ? Un aperçu simple ne survit que si son perso est encore là ; une
    /// grille se resserre sur les persos restants et disparaît avec le dernier.
    /// La liste fait foi sur l'identité seule : les persos y reviennent avec
    /// un autre état (dormant, titre) sans cesser d'être les mêmes.
    static func surviving(_ mode: Mode?, among clients: [DofusClient]) -> Mode? {
        let present = Set(clients.map(\.slotKey))
        switch mode {
        case nil:
            return nil
        case .single(let client):
            return present.contains(client.slotKey) ? mode : nil
        case .grid(let shown):
            let kept = shown.filter { present.contains($0.slotKey) }
            return kept.isEmpty ? nil : .grid(kept)
        }
    }

    private func present(_ newMode: Mode) {
        let service = WindowPreviewService.shared
        service.refreshAuthorization()
        if panel == nil { build() }

        mode = newMode
        service.refresh(newMode.clients)
        panel?.orderFrontRegardless()
        reposition()

        // Un aperçu figé n'apprend rien pendant un combat : on le tient à jour
        // tant qu'il est affiché, sans jamais capturer quand il ne l'est pas.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let mode = self?.mode else { return }
                WindowPreviewService.shared.refresh(mode.clients)
            }
        }
    }

    private func build() {
        let hosting = NSHostingController(rootView: PreviewPanelView())
        hosting.sizingOptions = [.preferredContentSize]

        let panel = PreviewPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 180),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        // Purement informatif : il ne doit intercepter ni clic ni survol, sans
        // quoi il masquerait la pastille qui l'a fait apparaître.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        self.panel = panel
        NotificationCenter.default.addObserver(
            self, selector: #selector(panelResized),
            name: NSWindow.didResizeNotification, object: panel
        )
    }

    /// La taille réelle n'est connue qu'une fois SwiftUI passé : le placement se
    /// refait à chaque changement de taille.
    @objc private func panelResized() { reposition() }

    private func reposition() {
        guard let panel, mode != nil else { return }
        let size = panel.frame.size
        guard let screen = panel.screen ?? NSScreen.main else { return }

        let origin: CGPoint
        if let anchor {
            origin = CGPoint(
                x: anchor.midX - size.width / 2,
                y: anchor.minY - size.height - Self.gap
            )
        } else {
            origin = CGPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2
            )
        }
        panel.setFrameOrigin(clamp(origin, size: size, in: screen.visibleFrame))
    }

    /// Garde l'aperçu entièrement à l'écran, même sous une pastille de bord.
    private func clamp(_ origin: CGPoint, size: CGSize, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, frame.minX + 4), frame.maxX - size.width - 4).rounded(),
            y: min(max(origin.y, frame.minY + 4), frame.maxY - size.height - 4).rounded()
        )
    }

    /// Écart entre la pastille et son aperçu.
    private static let gap: CGFloat = 6
}

// MARK: - Vue

private struct PreviewPanelView: View {
    @ObservedObject private var controller = PreviewPanelController.shared
    @ObservedObject private var service = WindowPreviewService.shared

    /// Encombrement d'une vignette à l'écran.
    ///
    /// La **hauteur** est imposée, elle aussi, et ce n'est pas cosmétique : sans
    /// elle, la taille du panneau suivait celle de l'image, donc l'instant où la
    /// capture arrivait. Le premier perso survolé avait le temps de se faire
    /// capturer, les suivants s'ouvraient sur le cadre d'attente — plus court —,
    /// puis le panneau se redimensionnait et se replaçait une fois l'image là.
    /// Vu de l'utilisateur : le premier aperçu était bon, les autres s'affichaient
    /// de travers. Un cadre fixe rend le panneau prévisible avant même la capture.
    private static let thumbnailWidth: CGFloat = 240
    private static let thumbnailHeight: CGFloat = 150

    var body: some View {
        Group {
            switch controller.mode {
            case .single(let client):
                thumbnail(for: client)
            case .grid(let clients):
                grid(clients)
            case nil:
                EmptyView()
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                )
        )
        .fixedSize()
    }

    private func grid(_ clients: [DofusClient]) -> some View {
        let columns = min(clients.count, 3)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
            spacing: 8
        ) {
            ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                thumbnail(for: client, number: index + 1)
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for client: DofusClient, number: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Color.primary.opacity(0.06)
                if let image = service.previews[client.slotKey] {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fit)
                } else {
                    placeholder
                }
            }
            .frame(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            HStack(spacing: 5) {
                if let number {
                    Text("\(number)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text(client.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(width: Self.thumbnailWidth, alignment: .leading)
        }
    }

    /// Occupe le cadre de la vignette sans en décider la taille : c'est le cadre
    /// fixe qui commande, l'attente s'y loge.
    private var placeholder: some View {
        Text(service.authorized
             ? L("apercu.captureEnCours")
             : L("apercu.autorisationRequise"))
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(8)
    }
}
