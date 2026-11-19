import Foundation
import MiseAJour

/// La part de Synfus dans la mise à jour : ses releases, lues de l'API publique de GitHub, le DMG de
/// l'architecture de ce Mac, ses empreintes, et la remise à zéro de ses autorisations.
struct ReleasesDeSynfus: FournisseurDeMiseAJour {
    static let depot = "Synseria/Synfus"
    /// Les releases, préversions comprises (l'API publique écarte d'office les brouillons).
    static let api = URL(string: "https://api.github.com/repos/\(depot)/releases?per_page=30")!

    /// La page d'une release d'après son numéro : celle de la version installée, que l'API n'a pas à dire.
    static func page(de numero: String) -> URL {
        URL(string: "https://github.com/\(depot)/releases/tag/v\(numero)")!
    }

    /// L'architecture du binaire qui tourne : sous Rosetta, celle d'Intel, comme la version installée.
    static var architecture: String {
        #if arch(arm64)
            "arm64"
        #else
            "x86_64"
        #endif
    }

    func derniere(canal: CanalDeMiseAJour) async throws -> ReleasePubliee? {
        guard let (donnees, reponse) = try? await URLSession.shared.data(for: Self.requete(Self.api)),
              Self.reussie(reponse)
        else { throw EchecDeMiseAJour.reseau }
        return Self.lire(donnees, canal: canal, architecture: Self.architecture)
    }

    func telecharger(_ release: ReleasePubliee, dans dossier: URL) async throws -> URL {
        guard let image = Self.image(de: release, architecture: Self.architecture),
              let (fichier, reponse) = try? await URLSession.shared.download(for: Self.requete(image.adresse)),
              Self.reussie(reponse)
        else { throw EchecDeMiseAJour.reseau }
        let destination = dossier.appendingPathComponent(image.nom)
        guard (try? FileManager.default.moveItem(at: fichier, to: destination)) != nil else { throw EchecDeMiseAJour.reseau }
        return destination
    }

    /// Le DMG a l'empreinte publiée avec la release, téléchargée elle aussi par HTTPS depuis GitHub.
    func verifierImage(_ image: URL, de release: ReleasePubliee) async throws {
        guard let adresse = release.fichiers.first(where: { $0.nom == Self.empreintes })?.adresse,
              let (donnees, reponse) = try? await URLSession.shared.data(for: Self.requete(adresse)),
              Self.reussie(reponse)
        else { throw EchecDeMiseAJour.reseau }
        try VerificationDeMiseAJour.empreinteSHA256(image, sommes: String(bytes: donnees, encoding: .utf8) ?? "")
    }

    /// Signée ad hoc, une version n'a pas d'exigence désignée commune avec la précédente : reste une
    /// signature intacte, code imbriqué compris.
    func verifierApp(_ app: URL, contre _: URL) throws {
        try VerificationDeMiseAJour.signatureIntacte(app)
    }

    /// macOS lie les autorisations à l'empreinte du binaire ad hoc : l'entrée de l'ancienne version
    /// resterait cochée sans effet. Effacées, elles se redemandent proprement.
    func apresPose(de _: URL) {
        guard let identifiant = Bundle.main.bundleIdentifier else { return }
        for service in ["Accessibility", "ScreenCapture"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, identifiant]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { continue }
            process.waitUntilExit()
        }
    }

    // MARK: - Lecture

    static let empreintes = "SHA256SUMS.txt"

    /// La release à suivre sur `canal`, d'après la liste de l'API ; nil si elle n'a pas le DMG de
    /// `architecture` ou les empreintes : une release incomplète ne se propose pas.
    static func lire(_ donnees: Data, canal: CanalDeMiseAJour, architecture: String) -> ReleasePubliee? {
        struct Reponse: Decodable {
            struct Fichier: Decodable {
                let name: String
                let browserDownloadUrl: URL
            }

            let tagName: String
            let htmlUrl: URL
            let prerelease: Bool
            let body: String?
            let assets: [Fichier]
        }
        let decodeur = JSONDecoder()
        decodeur.keyDecodingStrategy = .convertFromSnakeCase
        guard let reponses = try? decodeur.decode([Reponse].self, from: donnees) else { return nil }
        let releases = reponses.compactMap { reponse in
            ReleasePubliee(tag: reponse.tagName, preliminaire: reponse.prerelease, notes: reponse.body ?? "",
                           page: reponse.htmlUrl,
                           fichiers: reponse.assets.map { FichierDeRelease(nom: $0.name, adresse: $0.browserDownloadUrl) })
        }
        guard let release = ReleasePubliee.plusHaute(parmi: releases, canal: canal), release.tag.hasPrefix("v"),
              let image = image(de: release, architecture: architecture),
              release.fichiers.contains(where: { $0.nom == empreintes })
        else { return nil }
        return ReleasePubliee(tag: release.tag, numero: release.numero, preliminaire: release.preliminaire, notes: release.notes,
                              page: release.page, fichiers: release.fichiers, macOSMinimum: image.macOSMinimum)
    }

    /// Le DMG de `architecture`, nommé `Synfus-X.Y.Z[-rc.N]-macos<N>-<arch>.dmg` (`MACOS_MINIMUM` de
    /// build.sh), et le macOS qu'il exige, lu dans son nom avant tout téléchargement. Les versions
    /// d'avant, qui ne lisent que `Synfus-X.Y.Z-<arch>.dmg`, ne voient pas une release qu'elles ne
    /// sauraient pas écarter d'un macOS trop ancien : ce nom ne change plus, les versions installées le
    /// cherchent.
    static func image(de release: ReleasePubliee, architecture: String) -> (nom: String, adresse: URL, macOSMinimum: String)? {
        let (debut, fin) = ("Synfus-\(release.numero.texte)-macos", "-\(architecture).dmg")
        for fichier in release.fichiers where fichier.nom.hasPrefix(debut) && fichier.nom.hasSuffix(fin) {
            let minimum = String(fichier.nom.dropFirst(debut.count).dropLast(fin.count))
            if MacOSMinimum.lire(minimum) != nil, let adresse = fichier.adresse { return (fichier.nom, adresse, minimum) }
        }
        return nil
    }

    /// GitHub refuse une requête d'API sans `User-Agent`.
    private static func requete(_ url: URL) -> URLRequest {
        var requete = URLRequest(url: url, timeoutInterval: 60)
        requete.setValue("Synfus/\(AppIntegrity.version ?? "dev")", forHTTPHeaderField: "User-Agent")
        return requete
    }

    private static func reussie(_ reponse: URLResponse) -> Bool {
        (reponse as? HTTPURLResponse)?.statusCode == 200
    }
}
