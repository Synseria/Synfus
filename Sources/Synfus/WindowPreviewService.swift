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

    func refresh(_ clients: [DofusClient]) {
        for client in clients { refresh(client) }
    }

    func refresh(_ client: DofusClient) {
        guard authorized, !inFlight.contains(client.slotKey) else { return }
        inFlight.insert(client.slotKey)

        let key = client.slotKey
        let pid = client.pid
        let title = client.rawTitle

        Task {
            let data = await Self.captureWindow(pid: pid, title: title)
            inFlight.remove(key)
            if let data, let image = NSImage(data: data) {
                previews[key] = image
                unmatched.remove(key)
            } else {
                unmatched.insert(key)
            }
        }
    }

    /// Oublie les vignettes des persos qui ne sont plus connectés.
    func prune(keeping clients: [DofusClient]) {
        let alive = Set(clients.map(\.slotKey))
        previews = previews.filter { alive.contains($0.key) }
        unmatched = unmatched.intersection(alive)
    }

    /// Capture hors du main actor et rend un PNG : `SCWindow` et `CGImage` ne
    /// franchissent jamais la frontière d'isolation, seules des données le font.
    private nonisolated static func captureWindow(pid: pid_t, title: String) async -> Data? {
        do {
            // `onScreenWindowsOnly: false` est indispensable : un client sur un
            // autre bureau, ou en plein écran ailleurs, n'est pas « à l'écran ».
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false
            )
            let candidates = content.windows.map {
                Candidate(pid: $0.owningApplication?.processID ?? -1, title: $0.title)
            }
            guard let index = match(pid: pid, title: title, among: candidates) else { return nil }
            let window = content.windows[index]

            let configuration = SCStreamConfiguration()
            let scale = min(1, CGFloat(maxWidth) / max(window.frame.width, 1))
            configuration.width = Int((window.frame.width * scale).rounded())
            configuration.height = Int((window.frame.height * scale).rounded())
            configuration.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: window),
                configuration: configuration
            )
            return png(from: image)
        } catch {
            return nil
        }
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
    }

    /// Retrouve la fenêtre d'un client parmi celles que le système expose.
    ///
    /// Le titre départage plusieurs persos d'un même processus. Il peut avoir
    /// changé entre l'inventaire et la capture (reconnexion, changement de
    /// perso) : dans ce cas, un processus qui n'a qu'une fenêtre ne laisse aucune
    /// place au doute.
    nonisolated static func match(pid: pid_t, title: String, among candidates: [Candidate]) -> Int? {
        if let exact = candidates.firstIndex(where: { $0.pid == pid && $0.title == title }) {
            return exact
        }
        let sameProcess = candidates.indices.filter { candidates[$0].pid == pid }
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
