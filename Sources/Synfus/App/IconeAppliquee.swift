import AppKit

/// L'icône de l'app choisie (`Preferences.iconeApp`), posée sur l'app en
/// marche (alertes, « À propos ») et sur son bundle (Finder, Launchpad) ; et
/// ses vignettes pour les Réglages. Le seul endroit qui la pose.
///
/// `setIcon` écrit dans le bundle un fichier `Icon\r` et l'attribut
/// `com.apple.FinderInfo`. Le code signé n'est pas touché : lancement et
/// autorisations TCC tiennent, mais `codesign --verify --strict` refuse
/// désormais le bundle installé. Rien ne le vérifie : la mise à jour contrôle
/// l'app téléchargée, puis remplace le bundle entier — d'où la repose au lancement.
@MainActor
enum IconeAppliquee {

    /// Les tailles de l'`iconset`, une représentation chacune : le Finder prend
    /// la plus proche, et le treillis de l'Œuf change en petit.
    private nonisolated static let tailles = [16, 32, 64, 128, 256, 512, 1024]

    /// Le dernier choix : un rendu plus lent qu'un choix suivant ne l'écrase pas.
    private static var demande = 0

    private static var vignettes: [Vignette: NSImage] = [:]

    private struct Vignette: Hashable {
        let icone: IconeApp
        let cote: CGFloat
    }

    /// Une mise à jour remplace le bundle, et l'icône qui y était posée.
    static func auLancement() {
        let icone = Preferences.shared.iconeApp
        if icone != .parDefaut { appliquer(icone) }
    }

    /// Le défaut retire l'icône posée : le bundle reprend `Synfus.icns`.
    /// Hors bundle (`swift run`, tests), rien.
    static func appliquer(_ icone: IconeApp) {
        let bundle = Bundle.main.bundlePath
        guard bundle.hasSuffix(".app") else { return }
        demande += 1
        let numero = demande
        guard icone != .parDefaut else { return poser(nil, sur: bundle) }
        Task {
            // Sept tailles de l'Œuf : trop long pour main.
            let rendus = await Task.detached(priority: .userInitiated) {
                tailles.compactMap { SynfusMark.image(pixelSize: $0, icone: icone) }
            }.value
            guard numero == demande else { return }
            let image = NSImage(size: NSSize(width: 512, height: 512))
            for rendu in rendus {
                let representation = NSBitmapImageRep(cgImage: rendu)
                representation.size = image.size
                image.addRepresentation(representation)
            }
            poser(image, sur: bundle)
        }
    }

    private static func poser(_ image: NSImage?, sur bundle: String) {
        NSApp.applicationIconImage = image
        if !NSWorkspace.shared.setIcon(image, forFile: bundle, options: []) {
            NSLog("Synfus: icône de l'app non posée sur \(bundle)")
        }
    }

    /// L'icône à `cote` points, rendue à la résolution de l'écran qui l'affiche.
    static func vignette(_ icone: IconeApp, cote: CGFloat) -> NSImage {
        let cle = Vignette(icone: icone, cote: cote)
        if let gardee = vignettes[cle] { return gardee }
        let image = NSImage(size: NSSize(width: cote, height: cote), flipped: false) { cadre in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let pixels = Int(ctx.convertToDeviceSpace(cadre).width.magnitude.rounded())
            guard let rendu = SynfusMark.image(pixelSize: max(pixels, 1), icone: icone) else { return false }
            ctx.draw(rendu, in: cadre)
            return true
        }
        vignettes[cle] = image
        return image
    }
}
