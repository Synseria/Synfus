import AppKit
import ImageIO
import SwiftUI

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

    /// Les images telles quelles : petites et peu nombreuses (emblèmes,
    /// pictogrammes), gardées pour de bon — `ClassesStore` ne redemande pas un
    /// emblème déjà venu. Une vue de carte n'y entre jamais : `VueCarte` la
    /// demande réduite.
    private var memoire: [URL: NSImage] = [:]
    /// Les copies réduites, bornées en octets décodés : une liste qu'on fait
    /// défiler en montre des centaines, une vue de carte entière pèse 1,8 Mo.
    private let reduites: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 64 << 20
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

    /// Du cache disque, sinon du réseau ; `nil` si DofusDB ne l'a pas. Décodée
    /// — et réduite quand `cote` est donné — hors du fil principal.
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
            let decodee = await Task.detached { () -> CGImage? in
                guard let original = await Self.original(url, fichier: fichier, reseauDAbord: reseauDAbord) else { return nil }
                return Self.decoder(original, cote: demande.cote)
            }.value
            guard let decodee else { return nil }
            let image = NSImage(cgImage: decodee, size: .zero)
            if demande.cote == nil {
                memoire[url] = image
            } else {
                reduites.setObject(image, forKey: demande.cle, cost: decodee.bytesPerRow * decodee.height)
            }
            return image
        }
        enCours[demande] = tache
        let image = await tache.value
        enCours[demande] = nil
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

    /// Les pixels, décodés ici : une image lue paresseusement se décoderait au
    /// premier dessin, sur le fil principal. Avec `cote`, `cote` pixels au plus
    /// sur le plus grand côté, jamais agrandie.
    nonisolated static func decoder(_ donnees: Data, cote: Int?) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(donnees as CFData, nil) else { return nil }
        guard let cote else {
            return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceShouldCacheImmediately: true,
                       kCGImageSourceThumbnailMaxPixelSize: cote] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
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
