import AppKit
import ImageIO
import UniformTypeIdentifiers

/// L'outil d'exploration de la reconnaissance des sorts, dans le Diagnostic :
/// capturer la fenêtre du perso actif, la garder sur disque, y chercher la
/// barre et nommer chaque case — avec les scores, pour juger sur pièces.
///
/// C'est l'étape « faisabilité » : rien ici ne configure quoi que ce soit.
/// Les captures vont dans `~/Library/Logs/Synfus/captures/` — jamais dans le
/// dépôt — et forment le corpus sur lequel se prend la décision go/no-go.
@MainActor
final class SpellRecognitionProbe: ObservableObject {
    static let shared = SpellRecognitionProbe()

    @Published private(set) var report = ""
    @Published private(set) var busy = false
    /// La dernière capture, prête à être analysée.
    private var lastCapture: (image: LumaBitmap, classe: String?, url: URL)?

    static let capturesDirectory: URL = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appending(path: "Logs/Synfus/captures", directoryHint: .isDirectory)

    private init() {}

    // MARK: - Capture

    /// Capture la fenêtre du perso au premier plan — à défaut, du premier de
    /// la barre — en résolution native, et l'enregistre.
    func captureActive() {
        let manager = WindowManager.shared
        guard let client = manager.clients.first(where: { manager.isFrontmost($0) }) ?? manager.clients.first
        else { report = "Aucun perso connecté."; return }
        guard WindowPreviewService.shared.authorized else {
            report = "L'enregistrement de l'écran n'est pas autorisé (onglet Raccourcis → Aperçus)."
            return
        }
        busy = true
        Task {
            defer { busy = false }
            let start = Date()
            guard let image = await WindowPreviewService.shared.capture(client) else {
                report = "Capture impossible pour « \(client.name) » — fenêtre introuvable côté ScreenCaptureKit."
                return
            }
            let name = "\(Self.stamp())-\(client.name.replacingOccurrences(of: "/", with: "_")).png"
            let url = Self.capturesDirectory.appending(path: name)
            Self.save(image, to: url)
            guard let luma = LumaBitmap(cgImage: image) else { report = "Conversion en niveaux de gris impossible."; return }
            lastCapture = (luma, client.characterClass, url)
            report = """
            Capture de « \(client.name) » (\(client.characterClass ?? "classe inconnue")) : \
            \(image.width) × \(image.height) px en \(Self.ms(since: start)).
            → \(url.path)
            """
        }
    }

    /// Analyse un PNG du corpus, choisi par l'utilisateur. La classe vient du
    /// nom de fichier si on l'y trouve (`…-Nom.png` ne la porte pas : on
    /// demande alors toutes les classes, plus lent mais parlant).
    func analyzeFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png]
        panel.directoryURL = Self.capturesDirectory
        panel.message = "Une capture de fenêtre Dofus à analyser"
        guard panel.runModal() == .OK, let url = panel.url,
              let luma = LumaBitmap(contentsOf: url)
        else { return }
        let classe = WindowManager.shared.clients.first.flatMap(\.characterClass)
        lastCapture = (luma, classe, url)
        analyzeLast()
    }

    // MARK: - Analyse

    func analyzeLast() {
        guard let capture = lastCapture else { report = "Aucune capture à analyser."; return }
        let start = Date()
        var lines = ["Analyse de \(capture.url.lastPathComponent) (\(capture.image.width) × \(capture.image.height))"]

        guard let bar = SpellBarLocator.locate(in: capture.image) else {
            lines.append("✗ Aucune barre de sorts trouvée en \(Self.ms(since: start)) — regarder la capture : la barre est-elle dans le tiers bas ? les cases ont-elles un cadre net ?")
            report = lines.joined(separator: "\n")
            return
        }
        let region = bar.region(in: CGSize(width: capture.image.width, height: capture.image.height))
        lines.append("✓ Barre : \(bar.cells.count) cases de \(bar.side) px, pas \(bar.pitch) px, en \(Self.ms(since: start))")
        lines.append(String(format: "  zone relative x %.3f y %.3f l %.3f h %.3f", region.minX, region.minY, region.width, region.height))

        let candidates = Self.candidates(forClass: capture.classe)
        guard !candidates.isEmpty else {
            lines.append("✗ Aucune icône de sort connue" + (capture.classe.map { " pour « \($0) »" } ?? "")
                         + " — lancer Tools/fetch-ankama-assets.sh puis ./build.sh --install.")
            report = lines.joined(separator: "\n")
            return
        }
        lines.append("Candidats : \(candidates.count)" + (capture.classe.map { " (\($0))" } ?? " (toutes classes)"))

        let matching = Date()
        var confident = 0
        for (index, cell) in bar.cells.enumerated() {
            let crop = capture.image.cropped(to: cell)
            guard let match = SpellRecognizer.identify(cell: crop, among: candidates) else { continue }
            if match.isConfident { confident += 1 }
            lines.append(String(format: "  case %2d : %@ %-28@ score %.2f  marge %.2f",
                                index + 1, match.isConfident ? "✓" : "?", match.nom, match.score, match.margin))
        }
        lines.append("\(confident)/\(bar.cells.count) cases sûres, comparaison en \(Self.ms(since: matching)), total \(Self.ms(since: start))")
        report = lines.joined(separator: "\n")
    }

    /// Les icônes de la classe, réduites — ou de toutes les classes si elle
    /// est inconnue.
    private static func candidates(forClass classe: String?) -> [SpellRecognizer.Candidate] {
        guard let index = SpellIndex.load() else { return [] }
        let key = classe.flatMap(DofusClass.key(for:))
        let entries = key.map { index.entries(forClass: $0) } ?? index.entries
        return entries.compactMap { entry in
            guard let url = AnkamaAssets.spellIconURL(classe: entry.classe, id: entry.id),
                  let icon = LumaBitmap(contentsOf: url)
            else { return nil }
            return SpellRecognizer.candidate(id: entry.id, nom: entry.nom, icon: icon)
        }
    }

    // MARK: - Disque

    func revealCaptures() {
        try? FileManager.default.createDirectory(at: Self.capturesDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.capturesDirectory)
    }

    private static func save(_ image: CGImage, to url: URL) {
        try? FileManager.default.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func ms(since start: Date) -> String {
        "\(Int(Date().timeIntervalSince(start) * 1000)) ms"
    }
}
