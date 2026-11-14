import AppKit
import Combine
import SwiftUI

/// Les mises à jour depuis les releases GitHub : vérifiées au lancement puis
/// chaque jour (`Preferences.verifierMisesAJour`), proposées dans le menu et
/// l'onglet Général, installées sur demande — Synfus se remplace et se relance.
@MainActor
final class MiseAJour: ObservableObject {
    static let shared = MiseAJour()

    enum Etat: Equatable {
        case inconnu, verification, aJour
        case disponible(VersionPubliee)
        case installation(VersionPubliee)
        case echec(InstallateurMiseAJour.Echec, VersionPubliee)
    }

    @Published private(set) var etat = Etat.inconnu
    /// Lancé dans une autre version que la fois d'avant — par ce mécanisme ou
    /// à la main : les autorisations de l'ancienne ne valent plus.
    private(set) var apresMiseAJour = false

    /// La version proposée, quel que soit l'état où elle en est.
    var proposee: VersionPubliee? {
        switch etat {
        case .disponible(let version), .installation(let version), .echec(_, let version): version
        default: nil
        }
    }

    /// Les nouveautés de la version qui vient d'être installée, tant qu'on ne les a pas ouvertes ; `nil` le
    /// reste du temps.
    var nouveautesInstallee: (numero: String, page: URL)? {
        guard apresMiseAJour, !nouveautesOuvertes, let numero = AppIntegrity.version else { return nil }
        return (numero, VersionPubliee.page(de: numero))
    }

    func ouvrirNouveautes(_ page: URL) {
        nouveautesOuvertes = true
        NSWorkspace.shared.open(page)
    }

    private var nouveautesOuvertes = false
    private let installateur = InstallateurMiseAJour()
    private var minuterie: Timer?
    private var subscriptions: Set<AnyCancellable> = []
    private static let intervalle: TimeInterval = 24 * 3600

    private init() {}

    func start() {
        let prefs = Preferences.shared
        apresMiseAJour = Self.apresMiseAJour(derniere: prefs.derniereVersionLancee, courante: AppIntegrity.version,
                                             premierLancement: prefs.premierLancement)
        if let courante = AppIntegrity.version { prefs.derniereVersionLancee = courante }
        if Self.versionSimulee(CommandLine.arguments) != nil { verifier() }
        prefs.$verifierMisesAJour
            .removeDuplicates()
            .sink { [weak self] actif in MainActor.assumeIsolated { actif ? self?.armer() : self?.desarmer() } }
            .store(in: &subscriptions)
    }

    private func armer() {
        guard minuterie == nil else { return }
        verifier()
        minuterie = Timer.scheduledTimer(withTimeInterval: Self.intervalle, repeats: true) { _ in
            MainActor.assumeIsolated { MiseAJour.shared.verifier() }
        }
        minuterie?.tolerance = 3600
    }

    private func desarmer() {
        minuterie?.invalidate()
        minuterie = nil
        if case .installation = etat { return }
        etat = .inconnu
    }

    /// Un binaire nu (`swift build`) n'a pas de version : rien à comparer.
    func verifier() {
        switch etat {
        case .verification, .installation: return
        default: break
        }
        guard let installee = Self.versionSimulee(CommandLine.arguments) ?? AppIntegrity.version else { return }
        etat = .verification
        Task {
            let derniere = await installateur.derniere()
            guard case .verification = etat else { return }
            if derniere != nil { Preferences.shared.derniereVerificationMaj = Date() }
            if let derniere, derniere.plusRecente(que: installee) {
                etat = .disponible(derniere)
            } else {
                // GitHub muet : rien à proposer, on réessaiera au prochain tour.
                etat = derniere == nil ? .inconnu : .aJour
            }
        }
    }

    /// Vrai si la version qui tourne n'est pas celle du lancement précédent.
    /// Une sauvegarde d'avant ce réglage (`derniere` absente) vient forcément
    /// d'une version plus ancienne ; au premier lancement, rien n'a changé.
    nonisolated static func apresMiseAJour(derniere: String?, courante: String?, premierLancement: Bool) -> Bool {
        guard let courante, !premierLancement else { return false }
        return derniere != courante
    }

    /// `--simuler-version X.Y.Z` : la version comparée aux releases à la place
    /// de celle du bundle, pour essayer une mise à jour sur un build à jour.
    /// Vérifie même si la recherche est éteinte.
    nonisolated static func versionSimulee(_ arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--simuler-version"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// Le menu et l'onglet Général : confirmer, puis installer.
    func proposer() {
        guard let version = proposee else { return }
        if case .installation = etat { return }
        let demande = DemandeConfirmation(titre: L("maj.alerte.titre", version.numero), detail: L("maj.alerte.detail"),
                                          verbe: L("maj.alerte.installer"), rang: .principal,
                                          lien: LienConfirmation(titre: L("maj.nouveautes"), url: version.page))
        Task { if await Confirmation.demander(demande) { installer(version) } }
    }

    private func installer(_ version: VersionPubliee) {
        let cible = Bundle.main.bundleURL
        let parent = cible.deletingLastPathComponent().path
        guard cible.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: parent),
              FileManager.default.isWritableFile(atPath: cible.path)
        else { return etat = .echec(.ecriture, version) }
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("Synfus-maj-\(UUID().uuidString)")
        guard (try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)) != nil,
              let identifiant = Bundle.main.bundleIdentifier
        else { return etat = .echec(.ecriture, version) }

        etat = .installation(version)
        UsageStore.shared.compter(.miseAJour)
        Task {
            do throws(InstallateurMiseAJour.Echec) {
                let neuve = try await installateur.preparer(version, identifiant: identifiant, dans: dossier)
                remplacer(par: neuve, cible: cible, identifiant: identifiant, dossier: dossier)
            } catch {
                try? FileManager.default.removeItem(at: dossier)
                etat = .echec(error, version)
            }
        }
    }

    /// Une app ne se remplace pas en marche : un script détaché attend que
    /// Synfus soit fermé, met la nouvelle app à la place (l'ancienne revient
    /// si la copie échoue) et la relance. Les releases sont signées ad hoc :
    /// macOS lie les autorisations à l'empreinte du binaire, et l'entrée de
    /// l'ancienne resterait cochée sans effet — on les efface pour qu'elles
    /// soient redemandées proprement.
    private func remplacer(par neuve: URL, cible: URL, identifiant: String, dossier: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", Self.scriptRemplacement, "synfus-maj",
                             String(ProcessInfo.processInfo.processIdentifier), neuve.path, cible.path,
                             identifiant, dossier.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else {
            try? FileManager.default.removeItem(at: dossier)
            if let version = proposee { etat = .echec(.ecriture, version) }
            return
        }
        NSApp.terminate(nil)
    }

    /// `$1` PID de Synfus, `$2` nouvelle app, `$3` app installée, `$4`
    /// identifiant, `$5` dossier de travail. Une minute sans fermeture : on
    /// abandonne sans rien toucher.
    private static let scriptRemplacement = """
        for _ in $(seq 300); do kill -0 "$1" 2>/dev/null || break; sleep 0.2; done
        if kill -0 "$1" 2>/dev/null; then rm -rf "$5"; exit 1; fi
        ancienne="$5/ancienne.app"
        if mv "$3" "$ancienne"; then
            if ditto "$2" "$3"; then
                tccutil reset Accessibility "$4"
                tccutil reset ScreenCapture "$4"
            else
                rm -rf "$3"; mv "$ancienne" "$3"
            fi
        fi
        open "$3"
        rm -rf "$5"
        """
}
