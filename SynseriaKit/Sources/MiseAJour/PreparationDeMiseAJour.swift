// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 25f4236349ad81d5 · contenu 229a6d43433a2bff
// Le travail bloquant d'une mise à jour, hors du main actor : télécharger, vérifier, extraire l'app du
// DMG et la contrôler ; la recontrôler avant de la poser ; ce que l'app fait après la pose.

import Foundation

/// Sort d'une release une app prête à poser. Un acteur à exécuteur dédié : `hdiutil` et `ditto`
/// durent, et ne doivent pas affamer le pool coopératif. Réentrant à chaque `await` : une seule
/// préparation à la fois, c'est `SuiviDeMiseAJour` qui la garantit par son état.
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

    private var montage: URL { dossier.appendingPathComponent("montage") }

    /// L'app de `release`, extraite dans `dossier` (vidé d'abord) et contrôlée.
    func preparer(_ release: ReleasePubliee) async throws -> URL {
        try PoseDeMiseAJour.verifierEcriture(installee)
        // Un DMG resté monté (préparation interrompue) ferait échouer le vidage, puis chaque montage.
        _ = Self.lancer("/usr/bin/hdiutil", ["detach", montage.path, "-force"])
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

    /// Juste avant la pose : l'app prête a pu attendre des jours dans un cache qu'on nettoie. Elle
    /// est encore entière, cette app, et signée comme à sa préparation.
    func recontroler(_ app: URL) throws {
        guard Self.estUnDossier(app), let identifiant = Self.lire(app)?["CFBundleIdentifier"] as? String,
              identifiant == Self.lire(installee)?["CFBundleIdentifier"] as? String
        else { throw EchecDeMiseAJour.app }
        try fournisseur.verifierApp(app, contre: installee)
    }

    func apresPose() {
        fournisseur.apresPose(de: installee)
    }

    /// L'app du DMG — celle qui porte le nom de l'app installée, sinon la seule à sa racine —,
    /// recopiée hors du DMG, démonté quoi qu'il arrive. Un lien symbolique n'est pas une app : recopié
    /// tel quel, il ferait poser un lien à la place de l'app.
    private func extraire(_ image: URL) throws -> URL {
        guard Self.lancer("/usr/bin/hdiutil", ["attach", image.path, "-nobrowse", "-readonly", "-noverify", "-noautoopen",
                                               "-mountpoint", montage.path])
        else { throw EchecDeMiseAJour.image }
        defer { _ = Self.lancer("/usr/bin/hdiutil", ["detach", montage.path, "-force"]) }
        let apps = ((try? FileManager.default.contentsOfDirectory(at: montage, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "app" && Self.estUnDossier($0) }
        guard let source = apps.first(where: { $0.lastPathComponent == installee.lastPathComponent })
            ?? (apps.count == 1 ? apps[0] : nil)
        else { throw EchecDeMiseAJour.image }
        let app = dossier.appendingPathComponent(installee.lastPathComponent)
        guard Self.lancer("/usr/bin/ditto", [source.path, app.path]), Self.estUnDossier(app) else { throw EchecDeMiseAJour.image }
        return app
    }

    /// Les contrôles communs : c'est cette app (même identifiant que l'installée), au numéro annoncé,
    /// et ce Mac l'ouvre (`LSMinimumSystemVersion`, le second filet après le nom du DMG).
    static func controler(_ app: URL, release: ReleasePubliee, installee: URL, systeme: OperatingSystemVersion) throws {
        guard estUnDossier(app), let infos = lire(app), let identifiant = infos["CFBundleIdentifier"] as? String,
              identifiant == lire(installee)?["CFBundleIdentifier"] as? String
        else { throw EchecDeMiseAJour.app }
        guard infos["CFBundleShortVersionString"] as? String == release.numero.texte else { throw EchecDeMiseAJour.version }
        guard MacOSMinimum.atteint(infos["LSMinimumSystemVersion"] as? String, par: systeme) else { throw EchecDeMiseAJour.systeme }
    }

    /// Un vrai dossier, pas un lien vers un dossier (les valeurs de ressource ne suivent pas les liens).
    private static func estUnDossier(_ url: URL) -> Bool {
        guard let valeurs = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return valeurs.isDirectory == true && valeurs.isSymbolicLink != true
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
