// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 040a56e0df16d7e2 · contenu 84a8a18f704afde0
// Le travail bloquant d'une mise à jour, hors du main actor : télécharger, vérifier, extraire l'app du
// DMG et la contrôler ; puis la poser à la place de l'app installée.

import Foundation

/// Sort d'une release une app prête à poser. Un acteur à exécuteur dédié : `hdiutil` et `ditto`
/// durent, et ne doivent pas affamer le pool coopératif.
actor PreparationDeMiseAJour {
    private let queue = DispatchSerialQueue(label: "synseriakit.miseajour", qos: .utility)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let fournisseur: any FournisseurDeMiseAJour
    private let installee: URL
    private let dossier: URL
    private let systeme: OperatingSystemVersion

    init(fournisseur: any FournisseurDeMiseAJour, installee: URL, dossier: URL, systeme: OperatingSystemVersion) {
        self.fournisseur = fournisseur
        self.installee = installee
        self.dossier = dossier
        self.systeme = systeme
    }

    /// L'app de `release`, extraite dans `dossier` (vidé d'abord) et contrôlée.
    func preparer(_ release: ReleasePubliee) async throws -> URL {
        try? FileManager.default.removeItem(at: dossier)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let image = try await fournisseur.telecharger(release, dans: dossier)
        try await fournisseur.verifierImage(image, de: release)
        let app = try extraire(image)
        try? FileManager.default.removeItem(at: image)
        try Self.controler(app, release: release, installee: installee, systeme: systeme)
        try fournisseur.verifierApp(app, contre: installee)
        return app
    }

    /// L'app du DMG — celle qui porte le nom de l'app installée, sinon la seule à sa racine —,
    /// recopiée hors du DMG, démonté quoi qu'il arrive.
    private func extraire(_ image: URL) throws -> URL {
        let montage = dossier.appendingPathComponent("montage")
        guard Self.lancer("/usr/bin/hdiutil", ["attach", image.path, "-nobrowse", "-readonly", "-noverify", "-noautoopen",
                                               "-mountpoint", montage.path])
        else { throw EchecDeMiseAJour.image }
        defer { _ = Self.lancer("/usr/bin/hdiutil", ["detach", montage.path, "-force"]) }
        let apps = ((try? FileManager.default.contentsOfDirectory(at: montage, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "app" }
        guard let source = apps.first(where: { $0.lastPathComponent == installee.lastPathComponent })
            ?? (apps.count == 1 ? apps[0] : nil)
        else { throw EchecDeMiseAJour.image }
        let app = dossier.appendingPathComponent(installee.lastPathComponent)
        guard Self.lancer("/usr/bin/ditto", [source.path, app.path]) else { throw EchecDeMiseAJour.image }
        return app
    }

    /// Les contrôles communs : c'est cette app (même identifiant que l'installée), au numéro annoncé,
    /// et ce Mac l'ouvre (`LSMinimumSystemVersion`, le second filet après le nom du DMG).
    static func controler(_ app: URL, release: ReleasePubliee, installee: URL, systeme: OperatingSystemVersion) throws {
        guard let infos = lire(app), let identifiant = infos["CFBundleIdentifier"] as? String,
              identifiant == lire(installee)?["CFBundleIdentifier"] as? String
        else { throw EchecDeMiseAJour.app }
        guard infos["CFBundleShortVersionString"] as? String == release.numero.texte else { throw EchecDeMiseAJour.version }
        guard MacOSMinimum.atteint(infos["LSMinimumSystemVersion"] as? String, par: systeme) else { throw EchecDeMiseAJour.systeme }
    }

    /// L'Info.plist lu sur le disque, jamais par `Bundle(url:)` : il garde le premier paquet vu à un
    /// chemin, et la préparation suivante, au même endroit, y relirait l'ancienne version.
    private static func lire(_ app: URL) -> [String: Any]? {
        guard let donnees = try? Data(contentsOf: app.appending(path: "Contents/Info.plist")) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: donnees, format: nil)) as? [String: Any]
    }

    /// Vrai si la commande se termine sans erreur. Bloquant : sur l'exécuteur de l'acteur, où
    /// `waitUntilExit` rend sur le fil même du `run()`.
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
