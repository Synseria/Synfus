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

    static func safeName(_ perso: String) -> String {
        perso.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    }
}
