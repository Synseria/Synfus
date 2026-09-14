import AppKit
import Combine

/// Observe l'interface du perso au premier plan, une fois par seconde, et
/// pose le verdict combat / hors combat dans `StreamDeckLink.enCombat`.
///
/// Rien ne tourne tant que : la liaison Stream Deck est active, un client
/// Dofus est devant, l'enregistrement de l'écran est accordé, et les deux
/// références sont calibrées. Chaque relevé capture la **seule bande basse**
/// de la fenêtre (`CombatDetector.region`) — quelques milliers de pixels — et
/// la réduit à 64 × 14 : le coût, affiché dans le Diagnostic, est celui d'une
/// vignette au survol, une fois par seconde.
@MainActor
final class CombatWatcher: ObservableObject {
    static let shared = CombatWatcher()

    @Published private(set) var lastReading: CombatDetector.Reading?
    @Published private(set) var lastDuration: TimeInterval = 0
    @Published private(set) var calibrated = false
    @Published private(set) var status = "au repos"

    private var detector: CombatDetector?
    private var timer: Timer?
    private var busy = false
    private var subscriptions: Set<AnyCancellable> = []

    private static let interval: TimeInterval = 1
    private static let directory = AnkamaAssets.supportDirectory.appending(path: "Combat", directoryHint: .isDirectory)

    private init() {
        loadReferences()
    }

    func start() {
        Preferences.shared.$streamDeckEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in enabled ? self?.arm() : self?.disarm() }
            .store(in: &subscriptions)
    }

    private func arm() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { _ in
            MainActor.assumeIsolated { CombatWatcher.shared.tick() }
        }
        timer?.tolerance = 0.2
        status = calibrated ? "actif" : "à calibrer (onglet Sorts)"
    }

    private func disarm() {
        timer?.invalidate()
        timer = nil
        StreamDeckLink.shared.enCombat = nil
        status = "au repos"
    }

    private func tick() {
        guard var detector, !busy else { return }
        let manager = WindowManager.shared
        guard manager.frontmostIsDofus, WindowPreviewService.shared.authorized,
              let client = manager.clients.first(where: { manager.isFrontmost($0) })
        else { return }
        busy = true
        Task {
            defer { busy = false }
            let start = Date()
            guard let image = await WindowPreviewService.shared.capture(client, region: CombatDetector.region),
                  let luma = LumaBitmap(cgImage: image)
            else { return }
            let sample = CombatDetector.sample(luma)
            lastReading = detector.read(sample)
            let verdict = detector.observe(sample)
            self.detector = detector
            lastDuration = Date().timeIntervalSince(start)
            if StreamDeckLink.shared.enCombat != verdict { StreamDeckLink.shared.enCombat = verdict }
            status = "actif — \(verdict.map { $0 ? "en combat" : "hors combat" } ?? "indécis")"
        }
    }

    // MARK: - Calibrage

    /// Capture la bande basse du perso devant et la garde comme référence.
    func calibrate(enCombat: Bool) async -> String {
        let manager = WindowManager.shared
        guard let client = manager.clients.first(where: { manager.isFrontmost($0) }) ?? manager.clients.first
        else { return "Aucun perso connecté." }
        guard let image = await WindowPreviewService.shared.capture(client, region: CombatDetector.region),
              let luma = LumaBitmap(cgImage: image)
        else { return "Capture impossible." }
        let sample = CombatDetector.sample(luma)
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(sample) {
            try? data.write(to: Self.url(enCombat: enCombat), options: .atomic)
        }
        loadReferences()
        return "Référence \(enCombat ? "en combat" : "hors combat") enregistrée depuis « \(client.name) »."
    }

    private static func url(enCombat: Bool) -> URL {
        directory.appending(path: enCombat ? "en-combat.json" : "hors-combat.json")
    }

    private func loadReferences() {
        let decoder = JSONDecoder()
        guard let a = try? Data(contentsOf: Self.url(enCombat: true)),
              let b = try? Data(contentsOf: Self.url(enCombat: false)),
              let enCombat = try? decoder.decode(LumaBitmap.self, from: a),
              let horsCombat = try? decoder.decode(LumaBitmap.self, from: b)
        else { detector = nil; calibrated = false; return }
        detector = CombatDetector(enCombat: enCombat, horsCombat: horsCombat)
        calibrated = true
        if timer != nil { status = "actif" }
    }
}
