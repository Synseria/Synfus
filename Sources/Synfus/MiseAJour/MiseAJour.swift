import AppKit
import MiseAJour

/// Les mises à jour depuis les releases GitHub (le déroulé de SynseriaKit) : vérifiées au lancement
/// puis chaque jour, sur le canal choisi, proposées dans le menu et l'onglet Général, installées sur
/// demande — Synfus se remplace et se relance.
@MainActor
final class MiseAJour {
    static let shared = MiseAJour()

    let suivi = SuiviDeMiseAJour(
        fournisseur: ReleasesDeSynfus(), deroule: .auGeste,
        dossier: FileManager.default.temporaryDirectory.appendingPathComponent("Synfus-maj"),
        actuelle: { VersionInstallee.simulee(CommandLine.arguments) ?? AppIntegrity.version },
        canal: { Preferences.shared.canalDeMiseAJour })

    var etat: SuiviDeMiseAJour.Etat { suivi.etat }
    var proposee: ReleasePubliee? { suivi.proposee }

    /// Lancé dans une autre version que la fois d'avant — par ce mécanisme ou
    /// à la main : les autorisations de l'ancienne ne valent plus.
    private(set) var apresMiseAJour = false

    /// Les nouveautés de la version qui vient d'être installée, tant qu'on ne les a pas ouvertes ; `nil` le
    /// reste du temps.
    var nouveautesInstallee: (numero: String, page: URL)? {
        guard apresMiseAJour, !nouveautesOuvertes, let numero = AppIntegrity.version else { return nil }
        return (numero, ReleasesDeSynfus.page(de: numero))
    }

    func ouvrirNouveautes(_ page: URL) {
        nouveautesOuvertes = true
        NSWorkspace.shared.open(page)
    }

    private var nouveautesOuvertes = false

    private init() {
        suivi.quandProposee = { NotificationMiseAJour.shared.annoncerSiNouvelle($0) }
    }

    func start() {
        NotificationMiseAJour.shared.demarrer()
        let prefs = Preferences.shared
        apresMiseAJour = VersionInstallee.apresMiseAJour(derniere: prefs.derniereVersionLancee, courante: AppIntegrity.version,
                                                         premierLancement: prefs.premierLancement)
        if let courante = AppIntegrity.version { prefs.derniereVersionLancee = courante }
        suivi.suivre(apres: .zero)
    }

    /// Un binaire nu (`swift build`) n'a pas de version : rien à comparer.
    func verifier() {
        Task { await suivi.rechercher() }
    }

    /// Le canal a changé : une préversion proposée ne vaut plus pour Stable, la recherche reprend.
    func canalChange() {
        Task { await suivi.canalChange() }
    }

    /// Le menu : confirmer, puis installer.
    func proposer() {
        guard let version = proposee else { return }
        switch etat {
        case .telechargement, .prete: return
        default: break
        }
        guard Self.confirmer(version) else { return }
        installer()
    }

    /// Réglages ▸ Général et À propos : le bouton dit déjà « Installer X et relancer », sans alerte.
    func installer() {
        UsageStore.shared.compter(.miseAJour)
        suivi.installer()
    }

    /// « Installer Synfus X ? » : un geste qui engage sans détruire (le verbe est le défaut, ⏎), et
    /// « Nouveautés », qui ouvre la page de la version et laisse l'alerte en place. Au premier plan :
    /// Synfus est une app de barre de menus, l'alerte s'ouvrirait derrière le jeu.
    private static func confirmer(_ version: ReleasePubliee) -> Bool {
        let alerte = NSAlert()
        alerte.messageText = L("maj.alerte.titre", version.numero.texte)
        alerte.informativeText = L("maj.alerte.detail")
        alerte.addButton(withTitle: L("maj.alerte.installer"))
        alerte.addButton(withTitle: L("commun.annuler")).keyEquivalent = "\u{1b}"
        let nouveautes = alerte.addButton(withTitle: L("maj.nouveautes"))
        nouveautes.target = Nouveautes.shared
        nouveautes.action = #selector(Nouveautes.ouvrir)
        Nouveautes.shared.page = page(de: version)
        NSApp.activate()
        return alerte.runModal() == .alertFirstButtonReturn
    }

    /// La page de la release : celle que GitHub donne, sinon celle de son tag.
    static func page(de version: ReleasePubliee) -> URL {
        version.page ?? ReleasesDeSynfus.page(de: version.numero.texte)
    }
}

/// Le bouton « Nouveautés » de l'alerte d'installation : une cible qui ouvre la page sans fermer l'alerte
/// (un bouton d'`NSAlert` sans action propre la ferme).
@MainActor
private final class Nouveautes: NSObject {
    static let shared = Nouveautes()
    var page: URL?

    @objc func ouvrir() {
        if let page { NSWorkspace.shared.open(page) }
    }
}
