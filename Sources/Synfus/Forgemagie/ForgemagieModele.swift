import AppKit
import CoreGraphics
import Foundation

/// L'assistant de forgemagie, tant que son panneau est ouvert : le catalogue
/// des runes (DofusDB, gardé sur le disque), une lecture de l'atelier du perso
/// devant toutes les `intervalle` secondes, une séance par perso, et la cible
/// de jet voulue. La première lecture cherche l'atelier dans tout le contenu ;
/// trouvé, les suivantes se bornent à son cadre. Une image identique à la
/// précédente ne repasse pas par l'OCR. Un clic du joueur dans l'atelier fait
/// relire aussitôt, et vite, jusqu'à une lecture sûre (`enLecture`) ; la rune
/// conseillée est entourée sur le jeu (`CalqueSurJeu`). Lire et conseiller
/// seulement : le clic est observé, jamais émis ; rien n'est posé ni fusionné.
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
    /// Un clic dans l'atelier attend sa lecture sûre : le conseil d'avant ne vaut plus.
    @Published private(set) var enLecture = false

    var suivi: SuiviFM { perso.flatMap { suivis[$0] } ?? SuiviFM() }

    static let intervalle: Duration = .milliseconds(1500)
    /// Après un clic : le temps que le jeu montre la fusion, puis des lectures serrées.
    static let attenteApresClic: Duration = .milliseconds(250)
    static let intervalleApresClic: Duration = .milliseconds(350)
    /// L'atelier absent, on regarde moins souvent : l'OCR du contenu entier coûte.
    static let intervalleAbsent: Duration = .seconds(5)
    /// Autour du dernier cadre lu : l'atelier se déplace peu, la table s'allonge.
    nonisolated private static let marge = 0.08
    /// Après un téléchargement manqué, le suivant attend.
    private static let delaiNouvelEssai: TimeInterval = 60

    private var tache: Task<Void, Never>?
    private var region: ZoneEcran?
    private var empreinte: Int?
    /// La dernière lecture de l'atelier : une image inchangée la confirme sans OCR.
    private var derniereLecture: (perso: String, atelier: AtelierFM)?
    private var telechargement: Task<Void, Never>?
    private var dernierEssai = Date.distantPast
    /// L'observation des clics (passive : rien n'est intercepté ni émis).
    private var moniteurClic: Any?
    /// Le clic en attente de sa lecture sûre.
    private var clic: SuiviFM.AttenteClic?
    // Paresseux : la vue observe `shared`, qui ne doit pas se construire pendant sa propre initialisation.
    private lazy var calque = CalqueSurJeu(CalqueForgemagie())

    private init() {}

    func demarrer() {
        guard tache == nil else { return }
        if moniteurClic == nil {
            moniteurClic = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
                MainActor.assumeIsolated { ForgemagieModele.shared.clique() }
            }
        }
        boucler(apres: .zero)
    }

    private func boucler(apres attente: Duration) {
        tache?.cancel()
        tache = Task { [weak self] in
            try? await Task.sleep(for: attente)
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
        if let moniteurClic { NSEvent.removeMonitor(moniteurClic) }
        moniteurClic = nil
        clic = nil
        enLecture = false
        calque.poser(sur: nil)
        suivis = [:]
        region = nil
        empreinte = nil
        derniereLecture = nil
        cibles = [:]
        absent = false
    }

    // MARK: - Cible

    /// La cible d'une ligne : celle choisie, sinon son jet max, sinon sa valeur (une exo).
    func cible(_ ligne: ObjetFM.Ligne) -> Int { cibles[ligne.effet] ?? ligne.max ?? ligne.valeur }

    /// Un cran de cible : la puissance de la plus petite rune de l'effet (5 en Vitalité, 10 en Initiative).
    func changerCible(_ ligne: ObjetFM.Ligne, de sens: Int) {
        let pas = catalogue?.runes[ligne.effet]?.first?.puissance ?? 1
        let nouvelle = max(0, cible(ligne) + sens * pas)
        cibles[ligne.effet] = nouvelle == (ligne.max ?? ligne.valeur) ? nil : nouvelle
    }

    /// Le jet parfait : chaque ligne vise son jet max.
    func jetParfait() { cibles = [:] }

    /// Les runes conseillées sur la dernière lecture sûre, la meilleure d'abord.
    func propositions(nombre: Int) -> [ConseilFM.Proposition] {
        guard let catalogue, let atelier = suivi.atelier else { return [] }
        return ConseilFM.propositions(objet: atelier.objet, cible: cible, reliquat: atelier.reliquat,
                                      catalogue: catalogue, nombre: nombre)
    }

    // MARK: - Clic et calque

    /// Un clic du joueur dans l'atelier (une fusion, peut-être) : on relit tout
    /// de suite, puis serré, jusqu'à une lecture sûre.
    private func clique() {
        guard tache != nil, !absent, let region, let fenetre = FenetreJeu.devant(), fenetre.perso == perso,
              let pointeur = fenetre.pointeur(), region.rect.contains(pointeur) else { return }
        clic = SuiviFM.AttenteClic(le: Date(), avant: suivi.atelier)
        if !enLecture { enLecture = true }
        revoirCalque()
        boucler(apres: Self.attenteApresClic)
    }

    /// Une lecture depuis le clic (`nil` : rien de lu) ; sûre, le conseil revient.
    private func suivreClic(_ atelier: AtelierFM?) {
        guard var attente = clic else { return }
        if attente.lu(atelier, a: Date()) {
            clic = nil
            enLecture = false
        } else {
            clic = attente
        }
    }

    /// Le calque sur le jeu : la rune conseillée entourée, tant que l'atelier
    /// du perso devant est lu, sûr, et sans clic en attente.
    func revoirCalque() {
        let fenetre = FenetreJeu.devant()
        let montre = tache != nil && !absent && !enLecture && fenetre?.perso == perso && runeEntouree != nil
        calque.poser(sur: montre ? fenetre : nil)
    }

    /// La case de la meilleure rune, en fractions du contenu, et l'écart entre deux cases.
    var runeEntouree: (centre: CGPoint, pas: CGFloat)? {
        guard let rune = propositions(nombre: 1).first?.rune, let runes = suivi.atelier?.runes,
              let centre = runes.centre(effet: rune.effet, rang: rune.rang) else { return nil }
        return (centre, runes.pas)
    }

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
        defer { revoirCalque() }
        suivreClic(nil)
        guard let catalogue, WindowManager.shared.frontmostIsDofus, let devant = LecteurEcran.shared.persoDevant
        else { return Self.intervalle }
        let pause = clic == nil ? Self.intervalle : Self.intervalleApresClic
        let zone = region ?? ZoneEcran.entiere
        guard let image = await LecteurEcran.shared.imageDevant(region: zone), !Task.isCancelled else { return Self.intervalle }
        // Rien n'a bougé : pas d'OCR.
        let signature = Self.empreinte(image)
        if signature == empreinte {
            // L'image n'a pas bougé : la même lecture, qui confirme la précédente.
            if let derniere = derniereLecture, derniere.perso == devant {
                appliquer(derniere.atelier, perso: devant, catalogue: catalogue)
                suivreClic(derniere.atelier)
            }
            return absent ? Self.intervalleAbsent : pause
        }
        empreinte = signature
        let textes = Self.dansLeContenu(await LecteurEcran.shared.textes(image: image), region: zone)
        guard !Task.isCancelled else { return Self.intervalle }
        guard let atelier = AtelierFM.lire(textes, catalogue: catalogue) else {
            // Perdu dans le cadre : l'atelier a bougé ou s'est fermé, on le recherche partout.
            if region != nil {
                region = nil
                empreinte = nil
                return pause
            }
            if !absent { absent = true }
            return Self.intervalleAbsent
        }
        absent = false
        region = Self.autour(atelier.cadre)
        derniereLecture = (devant, atelier)
        appliquer(atelier, perso: devant, catalogue: catalogue)
        suivreClic(atelier)
        return pause
    }

    /// Une lecture versée à la séance du perso. Un autre perso, ou un autre
    /// objet sur l'atelier : la cible réglée ne vaut plus.
    private func appliquer(_ atelier: AtelierFM, perso devant: String, catalogue: CatalogueFM) {
        if perso != devant {
            perso = devant
            cibles = [:]
        }
        var suivi = suivis[devant] ?? SuiviFM()
        let objet = suivi.objet
        suivi.lu(atelier, catalogue: catalogue)
        if suivi.objet != objet { cibles = [:] }
        if suivi != suivis[devant] { suivis[devant] = suivi }
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
