import CoreGraphics
import Foundation

/// L'assistant de forgemagie, tant que son panneau est ouvert : le catalogue
/// des runes (DofusDB, gardé sur le disque), une lecture de l'atelier du perso
/// devant toutes les `intervalle` secondes, une séance par perso, et la cible
/// de jet voulue. La première lecture cherche l'atelier dans tout le contenu ;
/// trouvé, les suivantes se bornent à son cadre. Une image identique à la
/// précédente ne repasse pas par l'OCR. Lire et conseiller seulement : rien
/// n'est posé ni fusionné.
@MainActor
final class ForgemagieModele: ObservableObject {
    static let shared = ForgemagieModele()

    @Published private(set) var catalogue: CatalogueFM?
    /// Le téléchargement du catalogue a échoué, sans copie sur le disque.
    @Published private(set) var catalogueIndisponible = false
    @Published private(set) var suivis: [String: SuiviFM] = [:]
    @Published private(set) var perso: String?
    /// L'atelier n'est pas à l'écran, à la dernière lecture.
    @Published private(set) var absent = false
    /// La cible de jet, par effet, quand elle n'est pas le jet max (le jet parfait).
    @Published private(set) var cibles: [Int: Int] = [:]

    var suivi: SuiviFM { perso.flatMap { suivis[$0] } ?? SuiviFM() }

    static let intervalle: Duration = .seconds(2)
    /// L'atelier absent, on regarde moins souvent : l'OCR du contenu entier coûte.
    static let intervalleAbsent: Duration = .seconds(5)
    /// Autour du dernier cadre lu : l'atelier se déplace peu, la table s'allonge.
    nonisolated private static let marge = 0.08
    /// Après un téléchargement manqué, le suivant attend.
    private static let delaiNouvelEssai: TimeInterval = 60

    private var tache: Task<Void, Never>?
    private var region: ZoneEcran?
    private var empreinte: Int?
    private var telechargement: Task<Void, Never>?
    private var dernierEssai = Date.distantPast

    private init() {}

    func demarrer() {
        guard tache == nil else { return }
        tache = Task { [weak self] in
            while !Task.isCancelled {
                let pause = await self?.lire() ?? Self.intervalle
                try? await Task.sleep(for: pause)
            }
        }
    }

    /// Fermé, le panneau oublie tout : rouvert, il ne compare pas avec un atelier vu il y a longtemps.
    func arreter() {
        tache?.cancel()
        tache = nil
        suivis = [:]
        region = nil
        empreinte = nil
        cibles = [:]
        absent = false
    }

    // MARK: - Cible

    /// La cible d'une ligne : celle choisie, sinon son jet max, sinon sa valeur (une exo).
    func cible(_ ligne: ObjetFM.Ligne) -> Int { cibles[ligne.effet] ?? ligne.max ?? ligne.valeur }

    func changerCible(_ ligne: ObjetFM.Ligne, de pas: Int) {
        let nouvelle = max(0, cible(ligne) + pas)
        cibles[ligne.effet] = nouvelle == (ligne.max ?? ligne.valeur) ? nil : nouvelle
    }

    /// Le jet parfait : chaque ligne vise son jet max.
    func jetParfait() { cibles = [:] }

    // MARK: - Lecture

    private func chargerCatalogue() {
        guard catalogue == nil, telechargement == nil else { return }
        let gardees = CatalogueFMDofusDB.gardees()
        if let gardees { catalogue = CatalogueFM(effets: gardees.effets, runes: gardees.runes) }
        guard DofusDB.perimee(depuis: gardees?.date, maintenant: Date()),
              Date().timeIntervalSince(dernierEssai) >= Self.delaiNouvelEssai else { return }
        dernierEssai = Date()
        telechargement = Task {
            defer { telechargement = nil }
            do {
                let neuves = try await CatalogueFMDofusDB.telecharger()
                try? CatalogueFMDofusDB.garder(neuves)
                catalogue = CatalogueFM(effets: neuves.effets, runes: neuves.runes)
                catalogueIndisponible = false
            } catch {
                catalogueIndisponible = catalogue == nil
            }
        }
    }

    /// Une lecture ; rend la pause avant la suivante.
    private func lire() async -> Duration {
        chargerCatalogue()
        guard let catalogue, WindowManager.shared.frontmostIsDofus, let devant = LecteurEcran.shared.persoDevant
        else { return Self.intervalle }
        let zone = region ?? ZoneEcran.entiere
        guard let image = await LecteurEcran.shared.imageDevant(region: zone), !Task.isCancelled else { return Self.intervalle }
        // Rien n'a bougé : pas d'OCR.
        let signature = Self.empreinte(image)
        guard signature != empreinte else { return absent ? Self.intervalleAbsent : Self.intervalle }
        empreinte = signature
        let textes = Self.dansLeContenu(await LecteurEcran.shared.textes(image: image), region: zone)
        guard !Task.isCancelled else { return Self.intervalle }
        guard let atelier = AtelierFM.lire(textes, catalogue: catalogue) else {
            // Perdu dans le cadre : l'atelier a bougé ou s'est fermé, on le recherche partout.
            if region != nil {
                region = nil
                empreinte = nil
                return Self.intervalle
            }
            if !absent { absent = true }
            return Self.intervalleAbsent
        }
        absent = false
        region = Self.autour(atelier.cadre)
        if perso != devant { perso = devant }
        var suivi = suivis[devant] ?? SuiviFM()
        suivi.lu(atelier, catalogue: catalogue)
        if suivi != suivis[devant] { suivis[devant] = suivi }
        return Self.intervalle
    }

    /// Les cadres des textes d'une région, ramenés au contenu entier.
    nonisolated static func dansLeContenu(_ textes: [DetectionZones.TexteVu], region: ZoneEcran) -> [DetectionZones.TexteVu] {
        let r = region.rect
        return textes.map { texte in
            let c = texte.cadre
            return DetectionZones.TexteVu(texte: texte.texte, cadre: CGRect(
                x: r.minX + c.minX * r.width, y: r.minY + c.minY * r.height, width: c.width * r.width, height: c.height * r.height))
        }
    }

    /// L'empreinte des pixels d'une capture : deux captures identiques ont la même.
    private static func empreinte(_ image: CGImage) -> Int? {
        guard let donnees = image.dataProvider?.data as Data? else { return nil }
        var hasher = Hasher()
        hasher.combine(image.width)
        hasher.combine(donnees)
        return hasher.finalize()
    }

    /// Le cadre lu, élargi de `marge` et borné au contenu.
    nonisolated static func autour(_ cadre: CGRect) -> ZoneEcran {
        let r = cadre.insetBy(dx: -marge, dy: -marge).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return ZoneEcran(x: r.minX, y: r.minY, largeur: r.width, hauteur: r.height)
    }
}
