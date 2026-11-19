// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 040a56e0df16d7e2 · contenu b833bdec5a52be4b
// Le déroulé d'une mise à jour, commun aux apps : chercher la release du canal, la préparer, la poser
// sur un geste. L'app fournit sa source, ses vérifications et ses mots.

import Foundation
import Observation
import Versions

/// La mise à jour de l'app. Jamais de retour en arrière : une préversion installée reste en place,
/// même sur Stable, jusqu'à une version plus haute. Rien ne relance l'app sans un geste.
@MainActor
@Observable
public final class SuiviDeMiseAJour {
    public enum Etat: Equatable, Sendable {
        case repos
        case recherche
        case aJour
        /// Plus récente, à préparer sur un geste (`Deroule.auGeste`).
        case disponible(ReleasePubliee)
        /// Plus récente, mais pour un macOS que ce Mac n'a pas : dite, jamais proposée.
        case incompatible(ReleasePubliee)
        case telechargement(ReleasePubliee)
        case prete(ReleasePubliee)
        /// La release en cause, quand l'échec est venu après l'avoir trouvée.
        case echec(EchecDeMiseAJour, ReleasePubliee?)
    }

    /// Quand la release trouvée se télécharge.
    public enum Deroule: Sendable {
        /// Dès qu'elle est trouvée, en silence : le geste ne fait que poser et relancer.
        case enSilence
        /// Sur le geste, qui la télécharge, la pose et relance d'un trait.
        case auGeste
    }

    public private(set) var etat: Etat = .repos

    /// Appelé quand une release se propose : trouvée (`auGeste`) ou prête (`enSilence`).
    @ObservationIgnored public var quandProposee: (@MainActor (ReleasePubliee) async -> Void)?
    /// Appelé quand la source a répondu d'une release, à jour ou non.
    @ObservationIgnored public var apresReponse: (@MainActor () -> Void)?

    @ObservationIgnored private var appPrete: URL?
    @ObservationIgnored private var suivi: Task<Void, Never>?
    @ObservationIgnored private let fournisseur: any FournisseurDeMiseAJour
    @ObservationIgnored private let deroule: Deroule
    @ObservationIgnored private let actuelle: @MainActor () -> String?
    @ObservationIgnored private let canal: @MainActor () -> CanalDeMiseAJour
    @ObservationIgnored private let systeme: OperatingSystemVersion
    @ObservationIgnored private let preparation: @Sendable (ReleasePubliee) async throws -> URL
    @ObservationIgnored private let poser: @MainActor (URL) throws -> Void

    /// - Parameters:
    ///   - installee: l'app que la mise à jour remplace.
    ///   - dossier: où préparer la nouvelle version ; vidé à chaque préparation.
    ///   - actuelle: la version qui tourne (ou simulée) ; nil, illisible : rien ne se cherche.
    ///   - preparer: nil (hors tests) : télécharger, vérifier et extraire par le fournisseur.
    ///   - poser: nil (hors tests) : remplacer l'app installée, `apresPose`, puis relancer.
    public init(fournisseur: any FournisseurDeMiseAJour, deroule: Deroule, installee: URL = Bundle.main.bundleURL,
                dossier: URL, actuelle: @escaping @MainActor () -> String?, canal: @escaping @MainActor () -> CanalDeMiseAJour,
                systeme: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion,
                preparer: (@Sendable (ReleasePubliee) async throws -> URL)? = nil,
                poser: (@MainActor (URL) throws -> Void)? = nil) {
        self.fournisseur = fournisseur
        self.deroule = deroule
        self.actuelle = actuelle
        self.canal = canal
        self.systeme = systeme
        let atelier = PreparationDeMiseAJour(fournisseur: fournisseur, installee: installee, dossier: dossier, systeme: systeme)
        self.preparation = preparer ?? { try await atelier.preparer($0) }
        self.poser = poser ?? { nouvelle in
            try PoseDeMiseAJour.remplacer(installee, par: nouvelle)
            fournisseur.apresPose(de: installee)
            Relance.relancer()
        }
    }

    /// La release en jeu, quel que soit l'état où elle en est.
    public var proposee: ReleasePubliee? {
        switch etat {
        case .disponible(let release), .telechargement(let release), .prete(let release), .echec(_, let release?): release
        default: nil
        }
    }

    public var versionPrete: String? {
        if case .prete(let release) = etat { release.numero.texte } else { nil }
    }

    public var occupee: Bool {
        switch etat {
        case .recherche, .telechargement: true
        default: false
        }
    }

    /// Cherche après `attente`, puis toutes les `intervalle`, jusqu'à `arreter()`.
    public func suivre(apres attente: Duration, puisToutesLes intervalle: Duration = .seconds(24 * 3600)) {
        guard suivi == nil else { return }
        suivi = Task { [weak self] in
            try? await Task.sleep(for: attente)
            while !Task.isCancelled {
                await self?.rechercher()
                try? await Task.sleep(for: intervalle)
            }
        }
    }

    /// Plus de recherche d'elle-même ; ce qui était trouvé s'oublie, sauf un téléchargement en cours.
    public func arreter() {
        suivi?.cancel()
        suivi = nil
        guard !occupee else { return }
        appPrete = nil
        etat = .repos
    }

    public func rechercher() async {
        guard !occupee, versionPrete == nil, let actuelle = actuelle().flatMap(NumeroDeVersion.init) else { return }
        etat = .recherche
        let canalCherche = canal()
        do {
            let trouvee = try await fournisseur.derniere(canal: canalCherche)
            guard canalCherche == canal() else { return await relancer() }
            if trouvee != nil { apresReponse?() }
            etat = Self.etat(trouvee: trouvee, actuelle: actuelle, systeme: systeme)
            guard case .disponible(let release) = etat else { return }
            switch deroule {
            case .enSilence: await preparer(release)
            case .auGeste: await quandProposee?(release)
            }
        } catch {
            guard canalCherche == canal() else { return await relancer() }
            etat = .echec(Self.echec(error), nil)
        }
    }

    /// Ce que dit la release trouvée face à la version qui tourne.
    public nonisolated static func etat(trouvee: ReleasePubliee?, actuelle: NumeroDeVersion,
                                        systeme: OperatingSystemVersion) -> Etat {
        guard let trouvee, trouvee.numero > actuelle else { return .aJour }
        return trouvee.ouvrable(sur: systeme) ? .disponible(trouvee) : .incompatible(trouvee)
    }

    /// Le canal a changé : ce qui était trouvé ou prêt valait pour l'autre. Une recherche en vol
    /// voit le changement à son retour et recommence d'elle-même.
    public func canalChange() async {
        guard !occupee else { return }
        await relancer()
    }

    /// Le geste : pose la version prête et relance ; une version trouvée mais pas prête se prépare
    /// d'abord. Un échec laisse l'app en place, telle quelle.
    public func installer() {
        switch etat {
        case .prete(let release):
            guard let appPrete else { return }
            do {
                try poser(appPrete)
            } catch {
                etat = .echec(Self.echec(error), release)
            }
        case .disponible(let release), .echec(_, let release?):
            Task {
                await preparer(release)
                if case .prete = etat { installer() }
            }
        default:
            return
        }
    }

    private func preparer(_ release: ReleasePubliee) async {
        etat = .telechargement(release)
        let canalCherche = canal()
        do {
            let app = try await preparation(release)
            guard canalCherche == canal() else { return await relancer() }
            appPrete = app
            etat = .prete(release)
            if deroule == .enSilence { await quandProposee?(release) }
        } catch {
            guard canalCherche == canal() else { return await relancer() }
            let echec = Self.echec(error)
            etat = echec == .systeme ? .incompatible(release) : .echec(echec, release)
        }
    }

    private func relancer() async {
        appPrete = nil
        etat = .repos
        await rechercher()
    }

    private nonisolated static func echec(_ erreur: any Error) -> EchecDeMiseAJour {
        erreur as? EchecDeMiseAJour ?? .autre(erreur.localizedDescription)
    }
}
