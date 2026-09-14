import AppKit
import SwiftUI

/// Icônes de classe fournies par l'utilisateur.
///
/// Le dépôt n'embarque aucune image de classe : les portraits du jeu
/// appartiennent à Ankama et n'ont pas à être redistribués. Chacun met les
/// siennes, rangées dans un dossier ouvrable depuis les réglages — ou les
/// télécharge pour son build (`Tools/fetch-ankama-assets.sh`), auquel cas
/// `AnkamaAssets` les trouve dans le bundle quand le dossier n'en a pas.
///
/// Ce dossier est l'unique état modifiable : rien n'est dupliqué dans les
/// préférences, et déposer un fichier à la main y suffit — le nom du fichier
/// (`iop.png`) est la clé de la classe. `revision` sert seulement à redessiner
/// les vues.
@MainActor
final class ClassIconStore: ObservableObject {
    static let shared = ClassIconStore()

    @Published private(set) var revision = 0

    /// `~/Library/Application Support/Synfus/Classes`
    let directory: URL

    /// L'absence d'icône est mémorisée elle aussi : la barre se redessine à
    /// chaque rafraîchissement, inutile de retoucher le disque à chaque fois.
    private var cache: [String: NSImage?] = [:]

    private init() {
        directory = AnkamaAssets.classIconsDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Lecture

    func icon(for className: String?) -> NSImage? {
        guard let key = DofusClass.key(for: className) else { return nil }
        return icon(forKey: key)
    }

    func icon(forKey key: String) -> NSImage? {
        if let known = cache[key] { return known }
        let image = AnkamaAssets.classIconURL(key: key).flatMap { NSImage(contentsOf: $0) }
        cache[key] = image
        return image
    }

    /// L'emplacement **modifiable** de l'icône — celui du dossier de
    /// l'utilisateur, que la copie embarquée existe ou non.
    func url(forKey key: String) -> URL {
        directory.appendingPathComponent("\(key).png")
    }

    /// L'icône vient-elle du bundle plutôt que du dossier ? Retirer celle du
    /// dossier fera alors réapparaître l'embarquée — les réglages le disent.
    func isBundled(forKey key: String) -> Bool {
        !FileManager.default.fileExists(atPath: url(forKey: key).path)
            && AnkamaAssets.classIconURL(key: key) != nil
    }

    /// Variante à la taille d'un menu. `NSMenuItem` affiche l'image à sa taille
    /// intrinsèque : on en dimensionne une copie plutôt que celle du cache,
    /// partagée avec la barre.
    func menuIcon(for className: String?) -> NSImage? {
        guard let source = icon(for: className),
              let sized = source.copy() as? NSImage
        else { return nil }
        sized.size = NSSize(width: 16, height: 16)
        return sized
    }

    // MARK: - Écriture

    /// Importe une image et la range au format PNG sous la clé de la classe.
    ///
    /// On réencode plutôt que de copier : le fichier d'origine peut être un JPEG
    /// de plusieurs mégaoctets, alors que la barre n'en affiche jamais plus de
    /// 20 points. 128 points de côté couvrent le Retina avec de la marge.
    @discardableResult
    func setIcon(from source: URL, forKey key: String) -> Bool {
        guard let image = NSImage(contentsOf: source), image.isValid,
              let data = png(from: image)
        else { return false }

        do {
            try data.write(to: url(forKey: key), options: .atomic)
        } catch {
            return false
        }
        invalidate(key)
        return true
    }

    func removeIcon(forKey key: String) {
        try? FileManager.default.removeItem(at: url(forKey: key))
        invalidate(key)
    }

    /// À appeler après un dépôt de fichiers directement dans le dossier.
    func reloadAll() {
        cache.removeAll()
        revision &+= 1
    }

    private func invalidate(_ key: String) {
        cache[key] = nil
        revision &+= 1
    }

    private func png(from image: NSImage, side: CGFloat = 128) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        // Jamais d'agrandissement : une petite image reste nette telle quelle.
        let scale = min(side / size.width, side / size.height, 1)
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard width > 0, height > 0,
              let target = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0
              )
        else { return nil }

        target.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: target)
        image.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        return target.representation(using: .png, properties: [:])
    }
}
