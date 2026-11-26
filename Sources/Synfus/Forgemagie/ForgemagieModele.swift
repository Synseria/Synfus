import Foundation

/// L'assistant de forgemagie, tant que son panneau est ouvert : le catalogue
/// des runes (DofusDB, gardé sur le disque), et une lecture de l'atelier du
/// perso devant toutes les `intervalle` secondes. La première lecture cherche
/// l'atelier dans tout le contenu ; trouvé, les suivantes se bornent à son
/// cadre. Lire et afficher seulement : rien n'est posé ni fusionné.
@MainActor
final class ForgemagieModele: ObservableObject {
    static let shared = ForgemagieModele()

    @Published private(set) var catalogue: CatalogueFM?
    @Published private(set) var suivi = SuiviFM()
    /// L'atelier n'est pas à l'écran, à la dernière lecture.
    @Published private(set) var absent = false

    static let intervalle: Duration = .seconds(2)
    /// Autour du dernier cadre lu : l'atelier se déplace peu, la table s'allonge.
    private static let marge = 0.08

    private var tache: Task<Void, Never>?
    private var region: ZoneEcran?

    private init() {}

    func demarrer() {
        guard tache == nil else { return }
        chargerCatalogue()
        tache = Task { [weak self] in
            while !Task.isCancelled {
                await self?.lire()
                try? await Task.sleep(for: Self.intervalle)
            }
        }
    }

    func arreter() {
        tache?.cancel()
        tache = nil
    }

    private func chargerCatalogue() {
        guard catalogue == nil else { return }
        let gardees = CatalogueFMDofusDB.gardees()
        if let gardees { catalogue = CatalogueFM(effets: gardees.effets, runes: gardees.runes) }
        guard DofusDB.perimee(depuis: gardees?.date, maintenant: Date()) else { return }
        Task {
            guard let neuves = try? await CatalogueFMDofusDB.telecharger() else { return }
            try? CatalogueFMDofusDB.garder(neuves)
            catalogue = CatalogueFM(effets: neuves.effets, runes: neuves.runes)
        }
    }

    private func lire() async {
        guard let catalogue, WindowManager.shared.frontmostIsDofus else { return }
        let zone = region ?? ZoneEcran.entiere
        guard let textes = await LecteurEcran.shared.textesDevant(region: zone) else { return }
        guard let atelier = AtelierFM.lire(textes, catalogue: catalogue) else {
            // Perdu dans le cadre : l'atelier a bougé ou s'est fermé, on le recherche partout.
            if region != nil { region = nil } else if !absent { absent = true }
            return
        }
        absent = false
        region = Self.autour(atelier.cadre)
        var suivi = self.suivi
        suivi.lu(atelier, catalogue: catalogue)
        if suivi != self.suivi { self.suivi = suivi }
    }

    /// Le cadre lu, élargi de `marge` et borné au contenu.
    static func autour(_ cadre: CGRect) -> ZoneEcran {
        let r = cadre.insetBy(dx: -marge, dy: -marge).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return ZoneEcran(x: r.minX, y: r.minY, largeur: r.width, hauteur: r.height)
    }
}
