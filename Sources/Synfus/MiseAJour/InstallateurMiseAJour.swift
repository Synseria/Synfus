import CryptoKit
import Foundation

/// Le travail bloquant d'une mise à jour, hors main : interroger GitHub,
/// télécharger le DMG, en vérifier l'empreinte, en extraire l'app et la
/// contrôler. Acteur sans état : n'en sortent que des valeurs `Sendable`.
actor InstallateurMiseAJour {
    enum Echec: Error, Equatable {
        case reseau, empreinte, image, app, ecriture
    }

    /// La dernière release, ou `nil` si GitHub ne répond pas ou si elle est
    /// incomplète.
    func derniere() async -> VersionPubliee? {
        guard let reponse = try? await URLSession.shared.data(for: Self.requete(VersionPubliee.api)),
              Self.reussie(reponse.1)
        else { return nil }
        return VersionPubliee.lire(reponse.0, architecture: VersionPubliee.architecture)
    }

    /// L'app de `version`, extraite et contrôlée dans `dossier` (vide, créé par
    /// l'appelant) : téléchargée par HTTPS depuis GitHub, son DMG a l'empreinte
    /// publiée avec la release, et l'app qu'il contient a le même identifiant
    /// que celle-ci, le numéro annoncé et une signature intacte.
    func preparer(_ version: VersionPubliee, identifiant: String, dans dossier: URL) async throws(Echec) -> URL {
        let image = dossier.appendingPathComponent(version.nomImage)
        guard let telechargement = try? await URLSession.shared.download(for: Self.requete(version.image)),
              Self.reussie(telechargement.1),
              (try? FileManager.default.moveItem(at: telechargement.0, to: image)) != nil,
              let sommes = try? await URLSession.shared.data(for: Self.requete(version.empreintes)),
              Self.reussie(sommes.1)
        else { throw .reseau }

        guard let texte = String(bytes: sommes.0, encoding: .utf8),
              let attendue = VersionPubliee.empreinte(de: version.nomImage, dans: texte),
              let contenu = try? Data(contentsOf: image, options: .mappedIfSafe),
              SHA256.hash(data: contenu).map({ String(format: "%02x", $0) }).joined() == attendue
        else { throw .empreinte }

        let montage = dossier.appendingPathComponent("montage")
        let app = dossier.appendingPathComponent("Synfus.app")
        guard Self.lancer("/usr/bin/hdiutil", ["attach", image.path, "-nobrowse", "-readonly", "-noautoopen",
                                               "-mountpoint", montage.path])
        else { throw .image }
        let copiee = Self.lancer("/usr/bin/ditto", [montage.appendingPathComponent("Synfus.app").path, app.path])
        _ = Self.lancer("/usr/bin/hdiutil", ["detach", montage.path, "-force"])
        try? FileManager.default.removeItem(at: image)
        guard copiee else { throw .image }

        guard let infos = Bundle(url: app)?.infoDictionary,
              infos["CFBundleIdentifier"] as? String == identifiant,
              infos["CFBundleShortVersionString"] as? String == version.numero,
              Self.lancer("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        else { throw .app }
        return app
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

    /// Vrai si la commande se termine sans erreur.
    private static func lancer(_ outil: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: outil)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
