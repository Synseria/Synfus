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
    /// Pourquoi la dernière capture à la demande a échoué — le Diagnostic le
    /// montre, sinon « ça ne marche pas » n'a pas de cause.
    @Published private(set) var lastCaptureError: String?

    /// Captures en cours, pour ne pas en empiler quand le rafraîchissement est
    /// plus rapide que ScreenCaptureKit.
    private var inFlight: Set<String> = []

    /// Le moteur de capture, seul détenteur de l'inventaire ScreenCaptureKit.
    private let engine = PreviewCaptureEngine()

    private init() {}

    // MARK: - Capture

    /// Rafraîchit toutes les vignettes demandées **en un seul inventaire** — et
    /// le plus souvent sans inventaire du tout, cf. `PreviewCaptureEngine`.
    ///
    /// C'est le point important : `SCShareableContent` fait le tour de toutes les
    /// fenêtres du système, et la grille d'aperçu se rafraîchit chaque seconde.
    /// Un inventaire par perso revenait à en faire cinq par seconde pour cinq
    /// clients, alors qu'un seul les sert tous.
    ///
    /// L'autorisation n'est **jamais demandée** ici : sans elle, rien ne part.
    /// Le survol d'une pastille compte dessus pour préchauffer la capture.
    func refresh(_ clients: [DofusClient]) {
        guard authorized else { return }
        let requests = clients
            .filter { !inFlight.contains($0.slotKey) }
            .map { PreviewRequest(key: $0.slotKey, pid: $0.pid, title: $0.rawTitle,
                                  maxWidth: PreviewCaptureEngine.thumbnailWidth, region: nil) }
        guard !requests.isEmpty else { return }

        for request in requests { inFlight.insert(request.key) }

        Task {
            let captured = await engine.capture(requests)
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

    /// Une capture à la demande, hors vignettes : pleine résolution, et
    /// éventuellement limitée à une zone de la fenêtre — en fractions de sa
    /// largeur et de sa hauteur, origine en haut à gauche. C'est la capture de
    /// la reconnaissance des sorts et de la détection de combat : le même
    /// moteur, le même appariement, un seul foyer.
    func capture(_ client: DofusClient, region: CGRect? = nil) async -> CGImage? {
        guard authorized else { lastCaptureError = "enregistrement de l'écran non autorisé"; return nil }
        let request = PreviewRequest(key: client.slotKey, pid: client.pid, title: client.rawTitle,
                                     maxWidth: nil, region: region)
        switch await engine.captureOne(request) {
        case .success(let data):
            lastCaptureError = nil
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                lastCaptureError = "PNG illisible"
                return nil
            }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        case .failure(let failure):
            lastCaptureError = failure.description
            return nil
        }
    }

    /// Oublie les vignettes des persos qui ne sont plus connectés.
    func prune(keeping clients: [DofusClient]) {
        let alive = Set(clients.map(\.slotKey))
        previews = previews.filter { alive.contains($0.key) }
        unmatched = unmatched.intersection(alive)
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
        /// À l'écran (sur un espace visible) ou non. Un client garde parfois
        /// une fenêtre de jeu fantôme hors écran, du même titre que la vraie.
        var onScreen = true

        /// Un client de jeu occupe forcément une bonne part de l'écran. Le seuil
        /// est celui d'`AccessibilityReader.isGameWindow`, pour que les deux côtés
        /// de Synfus s'accordent sur ce qu'est une fenêtre de jeu.
        var isGameSized: Bool { AccessibilityReader.isGameWindow(subrole: nil, size: size) }
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
    ///
    /// Entre les deux, le **nom du perso** : le titre change de version ou de
    /// suffixe au fil d'une session, mais son premier segment reste le perso.
    /// Un client dont la fenêtre principale est doublée d'une seconde de
    /// taille de jeu (mesuré : le jeu en garde parfois une hors écran) était
    /// « ambigu » et son aperçu restait vide, alors que le nom tranchait.
    nonisolated static func match(pid: pid_t, title: String, among candidates: [Candidate]) -> Int? {
        let exact = candidates.indices.filter { candidates[$0].pid == pid && candidates[$0].title == title }
        if exact.count == 1 { return exact[0] }
        if exact.count > 1 {
            let visible = exact.filter { candidates[$0].onScreen }
            return visible.count == 1 ? visible[0] : exact[0]
        }
        let sameProcess = candidates.indices.filter {
            candidates[$0].pid == pid && candidates[$0].isGameSized
        }
        if sameProcess.count == 1 { return sameProcess[0] }
        let name = WindowTitle.characterName(fromTitle: title)
        var byName = sameProcess
        if !name.isEmpty {
            byName = sameProcess.filter { WindowTitle.characterName(fromTitle: candidates[$0].title ?? "") == name }
            if byName.count == 1 { return byName[0] }
        }
        // Même nom, plusieurs fenêtres : celle qui est à l'écran. Mesuré : une
        // fenêtre de jeu peut survivre hors écran dans le processus, du même
        // titre — la capture visait l'une ou l'autre, d'où un aperçu tantôt
        // bon, tantôt cassé, réparé en fermant la fenêtre.
        let visible = byName.filter { candidates[$0].onScreen }
        return visible.count == 1 ? visible[0] : nil
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

// MARK: - Moteur de capture

/// Ce qu'une capture a besoin de savoir d'un client. Types simples uniquement :
/// c'est ce qui entre dans le moteur, et rien d'autre.
private struct PreviewRequest: Sendable {
    let key: String
    let pid: pid_t
    let title: String
    /// Largeur maximale de l'image ; `nil` pour la résolution native.
    let maxWidth: Int?
    /// Zone de la fenêtre à capturer, en fractions (0…1) de sa largeur et de
    /// sa hauteur, origine en haut à gauche ; `nil` pour la fenêtre entière.
    let region: CGRect?
}

/// Ce qui a empêché une capture — pour le dire plutôt que rendre `nil`.
enum CaptureFailure: Error, CustomStringConvertible, Sendable {
    case inventory(String)
    case notFound(sameProcess: Int, gameSized: Int)
    case screenshot(String)

    var description: String {
        switch self {
        case .inventory(let e): return "inventaire ScreenCaptureKit impossible — \(e)"
        case .notFound(let same, let sized):
            return "fenêtre introuvable côté ScreenCaptureKit (\(same) fenêtre(s) du processus, \(sized) de taille de jeu — titre changé ? deux persos dans le même client ?)"
        case .screenshot(let e): return "capture refusée — \(e)"
        }
    }
}

/// Inventaire ScreenCaptureKit et captures, hors du main actor.
///
/// La règle d'isolation est celle d'avant, déplacée autour de cet acteur : il
/// n'en entre que des requêtes et il n'en sort que des PNG. `SCWindow`,
/// `SCShareableContent` et `CGImage` ne franchissent jamais sa frontière.
///
/// Ce qu'il apporte, c'est la **mémoire de l'inventaire**. `SCShareableContent`
/// fait le tour de toutes les fenêtres du système et coûte bien plus que la
/// capture elle-même ; le panneau d'aperçu se rafraîchit chaque seconde tant
/// qu'il est ouvert, et refaisait ce tour à chaque fois. Les fenêtres de jeu ne
/// naissent pas toutes les secondes : l'inventaire est gardé et ne se refait
/// que s'il date de plus de `maxAge`, ou si un perso demandé n'y trouve pas sa
/// fenêtre — un client qui vient de se connecter, ou dont la fenêtre a changé.
private actor PreviewCaptureEngine {
    private var content: SCShareableContent?
    private var inventoriedAt: Date = .distantPast

    /// Au-delà, l'inventaire est réputé périmé.
    private static let maxAge: TimeInterval = 3
    /// Largeur maximale d'une vignette. Capturer en pleine résolution pour
    /// afficher 240 points coûterait cher sans rien apporter.
    static let thumbnailWidth = 480

    /// Rend les PNG des persos retrouvés, par clé. Un perso absent du résultat
    /// n'a pas de fenêtre capturable — l'appariement est une hypothèse.
    func capture(_ requests: [PreviewRequest]) async -> [String: Data] {
        var captured: [String: Data] = [:]
        var pending = requests

        // Premier passage sur l'inventaire en mémoire, s'il est encore frais.
        if let content, Date().timeIntervalSince(inventoriedAt) < Self.maxAge {
            captured = await shots(pending, in: content)
            pending = pending.filter { captured[$0.key] == nil }
        }
        guard !pending.isEmpty else { return captured }

        // Inventaire périmé, ou un perso sans fenêtre dedans : on refait le
        // tour, une fois, pour les seuls persos qui restent.
        //
        // `onScreenWindowsOnly: false` est indispensable : un client sur un
        // autre bureau, ou en plein écran ailleurs, n'est pas « à l'écran ».
        guard let fresh = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: false
        ) else { return captured }
        content = fresh
        inventoriedAt = Date()

        captured.merge(await shots(pending, in: fresh)) { _, new in new }
        return captured
    }

    /// Une capture, avec sa raison d'échec : l'inventaire est toujours refait
    /// — c'est une demande explicite, la fraîcheur prime.
    func captureOne(_ request: PreviewRequest) async -> Result<Data, CaptureFailure> {
        let fresh: SCShareableContent
        do {
            fresh = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            return .failure(.inventory(error.localizedDescription))
        }
        content = fresh
        inventoriedAt = Date()
        let candidates = fresh.windows.map {
            WindowPreviewService.Candidate(pid: $0.owningApplication?.processID ?? -1,
                                           title: $0.title, size: $0.frame.size, onScreen: $0.isOnScreen)
        }
        guard let index = WindowPreviewService.match(pid: request.pid, title: request.title, among: candidates)
        else {
            let same = candidates.filter { $0.pid == request.pid }
            return .failure(.notFound(sameProcess: same.count, gameSized: same.filter(\.isGameSized).count))
        }
        do {
            return .success(try await shotThrowing(of: fresh.windows[index], request: request))
        } catch {
            return .failure(.screenshot(error.localizedDescription))
        }
    }

    /// Le déroulé est séquentiel à dessein : les captures ne peuvent pas partir
    /// en parallèle sans faire traverser un `SCWindow` — qui n'est pas
    /// `Sendable` — vers une tâche fille. Ce n'est de toute façon pas là qu'est
    /// le coût, l'inventaire l'emporte de loin.
    private func shots(_ requests: [PreviewRequest], in content: SCShareableContent) async -> [String: Data] {
        let candidates = content.windows.map {
            WindowPreviewService.Candidate(
                pid: $0.owningApplication?.processID ?? -1,
                title: $0.title,
                size: $0.frame.size,
                onScreen: $0.isOnScreen
            )
        }

        var captured: [String: Data] = [:]
        for request in requests {
            guard let index = WindowPreviewService.match(
                pid: request.pid, title: request.title, among: candidates
            ) else { continue }
            if let data = await shot(of: content.windows[index], request: request) {
                captured[request.key] = data
            }
        }
        return captured
    }

    private func shot(of window: SCWindow, request: PreviewRequest) async -> Data? {
        try? await shotThrowing(of: window, request: request)
    }

    private enum ShotError: Error { case encoding }

    private func shotThrowing(of window: SCWindow, request: PreviewRequest) async throws -> Data {
        let configuration = SCStreamConfiguration()
        // La zone demandée d'abord — en points de la fenêtre —, puis l'échelle :
        // une capture de la seule barre de sorts pèse cent fois moins qu'une
        // fenêtre entière, et c'est ce qui rend supportable une lecture répétée.
        var size = window.frame.size
        if let region = request.region {
            let rect = CGRect(x: region.minX * size.width, y: region.minY * size.height,
                              width: region.width * size.width, height: region.height * size.height)
            configuration.sourceRect = rect
            size = rect.size
        }
        // Résolution native : les écrans Retina rendent deux pixels par point,
        // et la reconnaissance veut ces pixels-là.
        let pixelsPerPoint = request.maxWidth == nil ? await Self.backingScale : 1
        let scale = request.maxWidth.map { min(1, CGFloat($0) / max(size.width, 1)) } ?? pixelsPerPoint
        configuration.width = Int((size.width * scale).rounded())
        configuration.height = Int((size.height * scale).rounded())
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window),
            configuration: configuration
        )
        guard let data = Self.png(from: image) else { throw ShotError.encoding }
        return data
    }

    private static func png(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    /// Le facteur Retina de l'écran principal — lu sur main, `NSScreen` y vit.
    @MainActor private static var backingScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2
    }
}
