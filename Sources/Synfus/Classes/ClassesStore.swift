import AppKit
import SwiftUI

/// Les classes en vigueur et leurs emblèmes, pour tout Synfus.
///
/// La liste : la table intégrée, rafraîchie depuis DofusDB au démarrage quand
/// elle a plus de `DofusDB.peremption` et au clic « Mettre à jour »
/// (`ClassesDofusDB`) ; un échec garde ce qui est là. L'emblème : celui que
/// l'utilisateur a posé dans le dossier, sinon celui de DofusDB, gardé dans
/// les caches (`ImagesDofusDB`) — rien du jeu dans le bundle ni le dépôt
/// (CGU Dofus, art. 13.2).
///
/// Le dossier est l'unique état modifiable des icônes : rien n'est dupliqué
/// dans les préférences, et déposer un fichier à la main y suffit — le nom du
/// fichier (`iop.png`) est la clé de la classe.
@MainActor
final class ClassesStore: ObservableObject {
    static let shared = ClassesStore()

    @Published private(set) var catalogue: DofusClass.Catalogue
    /// Celle de la liste téléchargée ; `nil` tant qu'il n'y a que la table intégrée.
    @Published private(set) var date: Date?
    @Published private(set) var chargement = false
    @Published private(set) var echec: String?
    /// Sert seulement à redessiner les vues quand une icône change ou arrive.
    @Published private(set) var revision = 0

    /// `~/Library/Application Support/Synfus/Classes`
    let directory: URL

    /// L'absence d'icône est mémorisée elle aussi : la barre se redessine à
    /// chaque rafraîchissement, inutile de retoucher le disque à chaque fois.
    private var siennes: [String: NSImage?] = [:]
    /// Les emblèmes déjà demandés à DofusDB : une barre qui se redessine ne
    /// relance pas à chaque image un téléchargement qui a échoué.
    private var demandes: Set<URL> = []

    private init() {
        directory = Ressources.dossierUtilisateur.appending(path: "Classes", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let gardees = ClassesDofusDB.gardees()
        catalogue = ClassesDofusDB.catalogue(gardees?.classes ?? [])
        date = gardees?.date
    }

    func start() {
        guard DofusDB.perimee(depuis: date, maintenant: Date()) else { return }
        Task { try? await mettreAJour() }
    }

    /// La liste, puis chaque emblème, redemandés à DofusDB ; le dossier de
    /// l'utilisateur relu au passage.
    func mettreAJour() async throws {
        guard !chargement else { return }
        chargement = true
        echec = nil
        defer { chargement = false }
        do {
            let nouvelles = try await ClassesDofusDB.telecharger()
            try? ClassesDofusDB.garder(nouvelles)
            catalogue = ClassesDofusDB.catalogue(nouvelles.classes)
            date = nouvelles.date
        } catch {
            echec = error.localizedDescription
            throw error
        }
        let emblemes = catalogue.breeds.compactMap(\.embleme).map { url in
            Task { _ = await ImagesDofusDB.shared.recharger(url) }
        }
        for embleme in emblemes { await embleme.value }
        reloadAll()
    }

    // MARK: - Lecture

    func icon(for className: String?) -> NSImage? {
        guard let key = catalogue.key(for: className) else { return nil }
        return icon(forKey: key)
    }

    func icon(forKey key: String) -> NSImage? {
        switch provenance(forKey: key) {
        case .tienne:
            return sienne(key)
        case .dofusDB(let url):
            if let image = ImagesDofusDB.shared.enMemoire(url) { return image }
            demander(url)
            return nil
        case nil:
            return nil
        }
    }

    /// D'où vient l'icône de la classe — les réglages l'affichent, et seule
    /// la tienne se retire.
    func provenance(forKey key: String) -> DofusClass.Provenance? {
        DofusClass.provenance(tienne: sienne(key) != nil, embleme: catalogue.breed(forKey: key)?.embleme)
    }

    /// L'emplacement **modifiable** de l'icône, celui du dossier de l'utilisateur.
    func url(forKey key: String) -> URL {
        directory.appendingPathComponent("\(key).png")
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

    private func sienne(_ key: String) -> NSImage? {
        if let connue = siennes[key] { return connue }
        let image = NSImage(contentsOf: url(forKey: key))
        siennes[key] = image
        return image
    }

    /// Une fois par URL et par lancement (ou par rechargement) : arrivé,
    /// l'emblème fait redessiner les vues.
    private func demander(_ url: URL) {
        guard demandes.insert(url).inserted else { return }
        Task {
            if await ImagesDofusDB.shared.charger(url) != nil { revision &+= 1 }
        }
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

    /// À appeler après un dépôt de fichiers directement dans le dossier ; un
    /// emblème qui n'avait pas pu venir de DofusDB est redemandé.
    func reloadAll() {
        siennes.removeAll()
        demandes.removeAll()
        revision &+= 1
    }

    private func invalidate(_ key: String) {
        siennes[key] = nil
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
