import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Les profils de sorts, un fichier JSON par perso dans
/// `~/Library/Application Support/Synfus/Profils/<perso>.json`.
///
/// Le dossier est l'état ; les profils sont chargés au démarrage et réécrits
/// à chaque modification, atomiquement. Un fichier déposé à la main est relu
/// par `reload()`.
@MainActor
final class SpellProfileStore: ObservableObject {
    static let shared = SpellProfileStore()

    @Published private(set) var profiles: [String: SpellProfile] = [:]

    let directory: URL = AnkamaAssets.supportDirectory.appending(path: "Profils", directoryHint: .isDirectory)

    private init() { reload() }

    func reload() {
        var loaded: [String: SpellProfile] = [:]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  var profile = try? JSONDecoder().decode(SpellProfile.self, from: data)
            else { continue }
            profile.normalize()
            loaded[profile.perso] = profile
        }
        profiles = loaded
    }

    /// Le profil d'un perso — vide s'il n'en a pas encore, sans rien écrire.
    func profile(for perso: String, classe: String?) -> SpellProfile {
        profiles[perso] ?? .empty(perso: perso, classe: classe)
    }

    func save(_ profile: SpellProfile) {
        profiles[profile.perso] = profile
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profile) {
            try? data.write(to: url(for: profile.perso), options: .atomic)
        }
    }

    func remove(_ perso: String) {
        profiles[perso] = nil
        try? FileManager.default.removeItem(at: url(for: perso))
    }

    func url(for perso: String) -> URL {
        directory.appending(path: "\(Self.safeName(perso)).json")
    }

    /// Le dossier des vignettes d'un perso — les cases lues à l'écran.
    func thumbnailsDirectory(for perso: String) -> URL {
        directory.appending(path: Self.safeName(perso), directoryHint: .isDirectory)
    }

    /// Enregistre une vignette et rend son nom de fichier, à mettre dans le `SpellSlot`.
    func saveThumbnail(_ image: CGImage, perso: String, bar: Int, position: Int) -> String? {
        let dir = thumbnailsDirectory(for: perso)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "barre\(bar + 1)-case\(position + 1).png"
        guard let destination = CGImageDestinationCreateWithURL(dir.appending(path: name) as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? name : nil
    }

    func thumbnailURL(perso: String, name: String) -> URL {
        thumbnailsDirectory(for: perso).appending(path: name)
    }

    /// Capture la fenêtre d'un perso connecté, reconnaît les rangées de sorts
    /// affichées — jusqu'à trois, une par barre — et remplit son profil : les
    /// cases sûres par leur sort, les autres par leur vignette d'écran. Rend
    /// le compte rendu, à afficher. Un seul foyer : l'onglet Sorts et l'appui
    /// long sur « Menu » du Stream Deck passent tous deux par ici.
    func recognize(_ client: DofusClient) async -> String {
        let perso = client.name
        let classe = client.characterClass
        guard let image = await WindowPreviewService.shared.capture(client),
              let luma = LumaBitmap(cgImage: image)
        else { return "Capture impossible : " + (WindowPreviewService.shared.lastCaptureError ?? "raison inconnue") }
        let analysis = SpellRecognition.analyze(luma, classe: classe)
        guard let found = analysis.bar else {
            return "Aucune barre de sorts trouvée dans la capture (voir Diagnostic pour les détails)."
        }
        guard analysis.candidateCount > 0 else {
            return "Aucune icône de sort connue pour cette classe — lancer Tools/fetch-ankama-assets.sh puis ./build.sh --install."
        }
        var p = profile(for: perso, classe: classe)
        p.classe = classe ?? p.classe
        var filled = 0, pictured = 0
        for cell in analysis.cells where cell.row < SpellProfile.barCount && cell.position < SpellProfile.slotsPerBar {
            if let match = cell.match, match.isConfident {
                p.set(SpellSlot(sortId: match.id, nom: match.nom), bar: cell.row, position: cell.position)
                filled += 1
            } else if cell.match != nil {
                // Pas un sort connu — objet, emote, sort inconnu — mais pas
                // vide : on garde ce que l'écran montre, c'est ce que le
                // Stream Deck affichera. Un sort choisi à la main reste.
                let existing = p.slot(bar: cell.row, position: cell.position)
                guard existing?.sortId == nil,
                      found.rows[cell.row].indices.contains(cell.position),
                      let crop = image.cropping(to: found.rows[cell.row][cell.position]),
                      let name = saveThumbnail(crop, perso: perso, bar: cell.row, position: cell.position)
                else { continue }
                p.set(SpellSlot(sortId: nil, nom: existing?.nom ?? "Case \(cell.position + 1)", vignette: name),
                      bar: cell.row, position: cell.position)
                pictured += 1
            } else {
                p.set(nil, bar: cell.row, position: cell.position)
            }
        }
        save(p)
        return "\(found.rows.count) rangée(s) de \(found.rows.first?.count ?? 0) cases trouvées : \(filled) sorts reconnus, "
            + "\(pictured) cases gardées en vignette d'écran (objets, emotes, inconnus). Le détail est dans Diagnostic."
    }

    static func safeName(_ perso: String) -> String {
        perso.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    }
}
