import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Les images que DofusDB héberge (vues des cartes, pictogrammes des repères,
/// emblèmes de classe), téléchargées à la demande et gardées dans les caches
/// de l'utilisateur : visuels du jeu, jamais dans le dépôt (CGU Dofus, art.
/// 13.2). Une même image n'est demandée qu'une fois, même par plusieurs vues à
/// la fois.
@MainActor
final class ImagesDofusDB {
    static let shared = ImagesDofusDB()

    /// Une image, telle quelle (`cote` nul) ou réduite à `cote` pixels sur son
    /// plus grand côté.
    private struct Demande: Hashable {
        let url: URL
        let cote: Int?

        var cle: NSString { "\(cote ?? 0) \(url.absoluteString)" as NSString }
    }

    /// Les images telles quelles : peu nombreuses (emblèmes, pictogrammes,
    /// vues agrandies), et gardées pour de bon — `ClassesStore` ne redemande
    /// pas un emblème déjà venu.
    private var memoire: [URL: NSImage] = [:]
    /// Les copies réduites, bornées : une liste qu'on fait défiler en montre
    /// des centaines, et une vue de carte décodée pèse plus d'un mégaoctet.
    private let reduites: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 400
        return cache
    }()
    private var enCours: [Demande: Task<NSImage?, Never>] = [:]
    /// `~/Library/Caches/Synfus/DofusDB`
    private let dossier = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "Synfus/DofusDB", directoryHint: .isDirectory)

    private init() {}

    /// Déjà chargée : pour dessiner sans attendre ni clignoter.
    func enMemoire(_ url: URL, cote: Int? = nil) -> NSImage? {
        enMemoire(Demande(url: url, cote: cote))
    }

    /// Du cache disque, sinon du réseau ; `nil` si DofusDB ne l'a pas. Réduite
    /// hors du fil principal quand `cote` est donné.
    func charger(_ url: URL, cote: Int? = nil) async -> NSImage? {
        let demande = Demande(url: url, cote: cote)
        if let image = enMemoire(demande) { return image }
        return await obtenir(demande, reseauDAbord: false)
    }

    /// Redemandée au réseau ; si DofusDB ne répond pas, la copie du disque
    /// reste — une mise à jour hors ligne n'efface rien.
    func recharger(_ url: URL) async -> NSImage? {
        await obtenir(Demande(url: url, cote: nil), reseauDAbord: true)
    }

    private func enMemoire(_ demande: Demande) -> NSImage? {
        guard Ressources.visuelsDuJeu else { return nil }
        return demande.cote == nil ? memoire[demande.url] : reduites.object(forKey: demande.cle)
    }

    private func obtenir(_ demande: Demande, reseauDAbord: Bool) async -> NSImage? {
        guard Ressources.visuelsDuJeu else { return nil }
        if let tache = enCours[demande] { return await tache.value }
        let url = demande.url
        let fichier = dossier.appending(path: url.pathComponents.suffix(2).joined(separator: "-"))
        let tache = Task<NSImage?, Never> {
            let donnees = await Task.detached { () -> Data? in
                let original = await Self.original(url, fichier: fichier, reseauDAbord: reseauDAbord)
                guard let original, let cote = demande.cote else { return original }
                return Self.reduire(original, cote: cote) ?? original
            }.value
            return donnees.flatMap(NSImage.init(data:))
        }
        enCours[demande] = tache
        let image = await tache.value
        enCours[demande] = nil
        if let image {
            if demande.cote == nil { memoire[url] = image } else { reduites.setObject(image, forKey: demande.cle) }
        }
        return image
    }

    /// Du disque, sinon du réseau, qui le remplit — ou du réseau d'abord.
    nonisolated private static func original(_ url: URL, fichier: URL, reseauDAbord: Bool) async -> Data? {
        if !reseauDAbord, let locales = try? Data(contentsOf: fichier) { return locales }
        let requete = URLRequest(url: url, cachePolicy: reseauDAbord ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy)
        guard let (recues, reponse) = try? await URLSession.shared.data(for: requete),
              (reponse as? HTTPURLResponse)?.statusCode == 200, NSImage(data: recues) != nil
        else { return reseauDAbord ? try? Data(contentsOf: fichier) : nil }
        try? FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? recues.write(to: fichier, options: .atomic)
        return recues
    }

    /// Une copie de `cote` pixels au plus, en PNG : ImageIO ne décode que ce
    /// qu'il faut, et le fil principal n'a plus qu'une petite image à lire.
    nonisolated private static func reduire(_ donnees: Data, cote: Int) -> Data? {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: cote] as CFDictionary
        guard let source = CGImageSourceCreateWithData(donnees as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        let sortie = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(sortie, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? sortie as Data : nil
    }
}

/// Une image de DofusDB, le repli tant qu'elle n'est pas là (rien, par
/// défaut). `cote` en demande une copie réduite, en pixels.
struct ImageDofusDB<Repli: View>: View {
    let url: URL
    var cote: Int?
    @ViewBuilder let repli: Repli
    /// L'image et son adresse : une vue réutilisée pour une autre image ne
    /// montre pas l'ancienne en attendant.
    @State private var chargee: (url: URL, image: NSImage)?

    init(url: URL, cote: Int? = nil, @ViewBuilder repli: () -> Repli) {
        self.url = url
        self.cote = cote
        self.repli = repli()
    }

    var body: some View {
        Group {
            if let image = chargee.flatMap({ $0.url == url ? $0.image : nil }) ?? ImagesDofusDB.shared.enMemoire(url, cote: cote) {
                Image(nsImage: image).resizable()
            } else {
                repli
            }
        }
        .task(id: url) {
            if let image = await ImagesDofusDB.shared.charger(url, cote: cote) { chargee = (url, image) }
        }
    }
}

extension ImageDofusDB where Repli == Color {
    init(url: URL, cote: Int? = nil) {
        self.init(url: url, cote: cote) { Color.clear }
    }
}
