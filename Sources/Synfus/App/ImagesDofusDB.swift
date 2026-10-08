import AppKit
import SwiftUI

/// Les images que DofusDB héberge (vues des cartes, emblèmes de classe),
/// téléchargées à la demande et gardées dans les caches de l'utilisateur :
/// visuels du jeu, jamais dans le dépôt (CGU Dofus, art. 13.2). Une même
/// image n'est demandée qu'une fois, même par plusieurs vues à la fois.
@MainActor
final class ImagesDofusDB {
    static let shared = ImagesDofusDB()

    private var memoire: [URL: NSImage] = [:]
    private var enCours: [URL: Task<NSImage?, Never>] = [:]
    /// `~/Library/Caches/Synfus/DofusDB`
    private let dossier = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "Synfus/DofusDB", directoryHint: .isDirectory)

    private init() {}

    /// Déjà chargée : pour dessiner sans attendre ni clignoter.
    func enMemoire(_ url: URL) -> NSImage? { memoire[url] }

    /// Du cache disque, sinon du réseau ; `nil` si DofusDB ne l'a pas.
    func charger(_ url: URL) async -> NSImage? {
        if let image = memoire[url] { return image }
        return await obtenir(url, reseauDAbord: false)
    }

    /// Redemandée au réseau ; si DofusDB ne répond pas, la copie du disque
    /// reste — une mise à jour hors ligne n'efface rien.
    func recharger(_ url: URL) async -> NSImage? {
        await obtenir(url, reseauDAbord: true)
    }

    private func obtenir(_ url: URL, reseauDAbord: Bool) async -> NSImage? {
        if let tache = enCours[url] { return await tache.value }
        let fichier = dossier.appending(path: url.pathComponents.suffix(2).joined(separator: "-"))
        let tache = Task<NSImage?, Never> { [dossier] in
            let donnees = await Task.detached { () -> Data? in
                if !reseauDAbord, let locales = try? Data(contentsOf: fichier) { return locales }
                let demande = URLRequest(url: url, cachePolicy: reseauDAbord ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy)
                guard let (recues, reponse) = try? await URLSession.shared.data(for: demande),
                      (reponse as? HTTPURLResponse)?.statusCode == 200, NSImage(data: recues) != nil
                else { return reseauDAbord ? try? Data(contentsOf: fichier) : nil }
                try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
                try? recues.write(to: fichier, options: .atomic)
                return recues
            }.value
            return donnees.flatMap(NSImage.init(data:))
        }
        enCours[url] = tache
        let image = await tache.value
        enCours[url] = nil
        if let image { memoire[url] = image }
        return image
    }
}

/// Une image de DofusDB, rien tant qu'elle n'est pas là.
struct ImageDofusDB: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image ?? ImagesDofusDB.shared.enMemoire(url) {
                Image(nsImage: image).resizable()
            } else {
                Color.clear
            }
        }
        .task(id: url) { image = await ImagesDofusDB.shared.charger(url) }
    }
}
