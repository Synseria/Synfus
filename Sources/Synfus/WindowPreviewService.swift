import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Vignettes des fenêtres de jeu.
///
/// La capture passe par ScreenCaptureKit, seule voie encore prise en charge :
/// `CGWindowListCreateImage` est déprécié depuis macOS 14. Il n'existe aucune API
/// publique pour passer d'un `AXUIElement` à une fenêtre capturable, d'où
/// l'appariement par `(pid, titre)` — les deux seules données que Synfus tient
/// déjà de chaque client.
///
/// C'est une **seconde autorisation** à accorder, distincte de l'Accessibilité :
/// l'aperçu est donc désactivé tant que l'utilisateur ne l'a pas demandé.
@MainActor
final class WindowPreviewService: ObservableObject {
    static let shared = WindowPreviewService()

    /// Dernière vignette connue de chaque client, par `slotKey`.
    @Published private(set) var previews: [String: NSImage] = [:]
    /// Autorisation « Enregistrement de l'écran ».
    @Published private(set) var authorized = CGPreflightScreenCaptureAccess()
    /// Persos pour lesquels aucune fenêtre capturable n'a été retrouvée, exposé
    /// dans l'onglet Diagnostic : l'appariement par titre est une hypothèse.
    @Published private(set) var unmatched: Set<String> = []

    /// Captures en cours, pour ne pas en empiler quand le rafraîchissement est
    /// plus rapide que ScreenCaptureKit.
    private var inFlight: Set<String> = []

    private init() {}

    /// Largeur maximale d'une vignette. Capturer en pleine résolution pour
    /// afficher 240 points coûterait cher sans rien apporter. `nonisolated` :
    /// la capture s'exécute hors du main actor.
    private nonisolated static let maxWidth = 480

    // MARK: - Capture

    /// Ce qu'une capture a besoin de savoir d'un client. Types simples
    /// uniquement : la capture s'exécute hors du main actor.
    private struct Request: Sendable {
        let key: String
        let pid: pid_t
        let title: String
    }

    /// Rafraîchit toutes les vignettes demandées **en un seul inventaire**.
    ///
    /// C'est le point important : `SCShareableContent` fait le tour de toutes les
    /// fenêtres du système, et la grille d'aperçu se rafraîchit chaque seconde.
    /// Un inventaire par perso revenait à en faire cinq par seconde pour cinq
    /// clients, alors qu'un seul les sert tous.
    func refresh(_ clients: [DofusClient]) {
        guard authorized else { return }
        let requests = clients
            .filter { !inFlight.contains($0.slotKey) }
            .map { Request(key: $0.slotKey, pid: $0.pid, title: $0.rawTitle) }
        guard !requests.isEmpty else { return }

        for request in requests { inFlight.insert(request.key) }

        Task {
            let captured = await Self.capture(requests)
            for request in requests {
                inFlight.remove(request.key)
                if let data = captured[request.key], let image = NSImage(data: data) {
                    previews[request.key] = image
                    unmatched.remove(request.key)
                } else {
                    unmatched.insert(request.key)
                }
            }
        }
    }

    func refresh(_ client: DofusClient) {
        refresh([client])
    }

    /// Oublie les vignettes des persos qui ne sont plus connectés.
    func prune(keeping clients: [DofusClient]) {
        let alive = Set(clients.map(\.slotKey))
        previews = previews.filter { alive.contains($0.key) }
        unmatched = unmatched.intersection(alive)
    }

    /// Capture hors du main actor et rend des PNG : `SCWindow` et `CGImage` ne
    /// franchissent jamais la frontière d'isolation, seules des données le font.
    ///
    /// Le déroulé est séquentiel à dessein : les captures ne peuvent pas partir
    /// en parallèle sans faire traverser un `SCWindow` — qui n'est pas
    /// `Sendable` — vers une tâche fille. Ce n'est de toute façon pas là qu'est
    /// le coût, l'inventaire l'emporte de loin, et il est désormais unique.
    private nonisolated static func capture(_ requests: [Request]) async -> [String: Data] {
        // `onScreenWindowsOnly: false` est indispensable : un client sur un
        // autre bureau, ou en plein écran ailleurs, n'est pas « à l'écran ».
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: false
        ) else { return [:] }

        let candidates = content.windows.map {
            Candidate(
                pid: $0.owningApplication?.processID ?? -1,
                title: $0.title,
                size: $0.frame.size
            )
        }

        var captured: [String: Data] = [:]
        for request in requests {
            guard let index = match(pid: request.pid, title: request.title, among: candidates)
            else { continue }
            if let data = await shot(of: content.windows[index]) {
                captured[request.key] = data
            }
        }
        return captured
    }

    private nonisolated static func shot(of window: SCWindow) async -> Data? {
        let configuration = SCStreamConfiguration()
        let scale = min(1, CGFloat(maxWidth) / max(window.frame.width, 1))
        configuration.width = Int((window.frame.width * scale).rounded())
        configuration.height = Int((window.frame.height * scale).rounded())
        configuration.showsCursor = false

        guard let image = try? await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window),
            configuration: configuration
        ) else { return nil }
        return png(from: image)
    }

    private nonisolated static func png(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    // MARK: - Appariement

    /// Ce qu'il faut savoir d'une fenêtre pour la reconnaître. Réduit à des types
    /// simples, l'appariement se teste sans écran ni autorisation.
    struct Candidate: Sendable, Equatable {
        let pid: pid_t
        let title: String?
        /// Taille de la fenêtre. Sert à écarter les fenêtres de service, pas à
        /// choisir entre deux persos. La valeur par défaut est celle d'une
        /// fenêtre de jeu : un test qui ne parle pas de taille n'en parle pas.
        var size: CGSize = CGSize(width: 1280, height: 720)

        /// Un client de jeu occupe forcément une bonne part de l'écran. Le seuil
        /// est celui de `WindowManager.isGameWindow`, pour que les deux côtés de
        /// Synfus s'accordent sur ce qu'est une fenêtre de jeu.
        var isGameSized: Bool { size.width > 200 && size.height > 200 }
    }

    /// Retrouve la fenêtre d'un client parmi celles que le système expose.
    ///
    /// Le titre départage plusieurs persos d'un même processus. Il peut avoir
    /// changé entre l'inventaire et la capture (reconnexion, changement de
    /// perso) : dans ce cas, un processus qui n'a qu'une fenêtre ne laisse aucune
    /// place au doute.
    ///
    /// Encore faut-il savoir les compter. ScreenCaptureKit expose *toutes* les
    /// fenêtres d'un processus, y compris celles que le jeu n'affiche pas comme
    /// telles — info-bulles, panneaux hors écran. Les compter faisait passer un
    /// client parfaitement ordinaire pour ambigu, et son aperçu restait vide.
    /// Elles sont donc écartées sur la taille, exactement comme le fait
    /// l'inventaire des fenêtres AX. Deux vrais persos dans un même processus
    /// restent, eux, un cas où l'on renonce : mieux vaut aucun aperçu que celui
    /// du mauvais perso.
    nonisolated static func match(pid: pid_t, title: String, among candidates: [Candidate]) -> Int? {
        if let exact = candidates.firstIndex(where: { $0.pid == pid && $0.title == title }) {
            return exact
        }
        let sameProcess = candidates.indices.filter {
            candidates[$0].pid == pid && candidates[$0].isGameSized
        }
        return sameProcess.count == 1 ? sameProcess[0] : nil
    }

    // MARK: - Autorisation

    /// Demande l'autorisation d'enregistrement de l'écran, puis ouvre le panneau
    /// des Réglages Système : macOS n'affiche son invite qu'une fois, et n'y
    /// revient jamais de lui-même après un refus.
    func requestAuthorization() {
        CGRequestScreenCaptureAccess()
        authorized = CGPreflightScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Relit l'autorisation — elle peut avoir été accordée dans les Réglages
    /// pendant que l'app tournait.
    func refreshAuthorization() {
        let granted = CGPreflightScreenCaptureAccess()
        if granted != authorized { authorized = granted }
    }
}
