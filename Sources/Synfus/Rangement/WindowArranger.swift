import AppKit
import ApplicationServices

/// Range les fenêtres des clients selon une disposition calculée par
/// `LayoutComputer`. Il ne fait que **déplacer et dimensionner** — poser
/// `kAXPosition` et `kAXSize`, rien d'autre : aucun évènement synthétisé,
/// aucun focus pris, la règle absolue du projet vaut ici aussi.
@MainActor
final class WindowArranger: ObservableObject {
    static let shared = WindowArranger()

    /// Un perso que le rangement a laissé de côté, et pourquoi — l'exclusion
    /// est une décision, elle doit se voir dans le Diagnostic.
    struct Ecartee: Identifiable {
        let nom: String
        let raison: String
        var id: String { nom + raison }
    }

    /// Compte rendu du dernier rangement. Comme l'appariement du Dock ou des
    /// aperçus, ce que fait l'arrangeur repose sur des hypothèses (écran cible,
    /// bonne volonté du client) : le rapport est leur vérité terrain.
    struct Rapport {
        let date: Date
        /// Libellé du geste — une disposition, ou une bascule de plein écran.
        let titre: String
        let ecran: String
        let rangees: [String]
        let ecartees: [Ecartee]
    }

    @Published private(set) var dernierRapport: Rapport?

    /// Le « Un grand + vignettes » en cours, que suivent les bascules de Synfus. En mémoire
    /// seulement : après une relance, il faut ranger de nouveau pour qu'il suive.
    private var agencement: AgencementPrincipal?

    private init() {}

    /// Rejoue la dernière disposition choisie — c'est l'action du raccourci.
    func appliquerDerniere(geste: EvenementUsage = .rangement, grandAuRang: Int? = nil) async {
        await appliquer(.enCours(derniere: Preferences.shared.lastArrangement), geste: geste,
                        grandAuRang: grandAuRang)
    }

    /// Asynchrone parce que l'inventaire l'est : on attend un relevé frais —
    /// l'utilisateur vient peut-être de connecter ou fermer un client, et on
    /// range ce qu'il voit, pas ce qu'on croyait. Un client fraîchement gelé
    /// en ressort muet, donc dormant, donc écarté avant tout IPC. Les écritures
    /// AX, elles, restent sur main : ce sont des gestes. `geste` est ce que
    /// les statistiques comptent : un rangement, ou la session qui l'enchaîne.
    /// `grandAuRang` : le rang dans l'effectif du perso qui sera le grand — la
    /// session, qui bascule ensuite sur lui, le pose en grand d'emblée plutôt
    /// que de le faire échanger aussitôt avec celui de devant.
    func appliquer(_ disposition: Disposition, geste: EvenementUsage = .rangement,
                   grandAuRang: Int? = nil) async {
        UsageStore.shared.compter(geste)
        agencement = nil
        let manager = WindowManager.shared
        await manager.refreshed()

        var eligibles: [DofusClient] = []
        var ecartees: [Ecartee] = []
        // L'effectif, pas tous les clients : ranger, c'est ranger l'équipe
        // qu'on joue. Le rapport dit laquelle.
        let titre = titreAvecEquipe(disposition.label)
        for client in manager.effectif {
            if client.dormant {
                // Son élément AX est périmé — la fenêtre vit sur un espace
                // inactif, hors de portée. Le remède est dans le Diagnostic.
                ecartees.append(Ecartee(
                    nom: client.name,
                    raison: L("rangement.raison.autreBureau")
                ))
            } else if !manager.isReachable(client) {
                // En cours de fermeture, ou muet au veilleur de gel : lui poser
                // une question, c'est payer la borne d'une seconde pour rien.
                ecartees.append(Ecartee(nom: client.name, raison: L("rangement.raison.muet")))
            } else if AccessibilityReader.boolAttribute(client.axWindow, "AXFullScreen") == true {
                // On ne sort jamais personne du plein écran d'autorité.
                ecartees.append(Ecartee(nom: client.name, raison: L("rangement.raison.pleinEcran")))
            } else {
                eligibles.append(client)
            }
        }

        guard !eligibles.isEmpty, let hauteurPrincipale = NSScreen.screens.first?.frame.height
        else {
            NSSound.beep()
            dernierRapport = Rapport(date: Date(), titre: titre,
                                     ecran: "—", rangees: [], ecartees: ecartees)
            return
        }

        // Tout est ramené sur un seul écran — c'est le sens du geste « en un
        // coup ». Lequel : celui du perso au premier plan, à défaut celui de la
        // première fenêtre rangée, à défaut l'écran principal.
        let repere = eligibles.first { $0.pid == manager.frontmostPID } ?? eligibles[0]
        let ecran = ecran(de: repere, hauteurPrincipale: hauteurPrincipale) ?? NSScreen.main
        guard let ecran else {
            // Aucun écran : rien n'a bougé, et le Diagnostic doit le dire —
            // sans rapport, il continuait d'afficher celui du rangement
            // précédent, qui avait, lui, parfaitement marché.
            NSSound.beep()
            dernierRapport = Rapport(
                date: Date(), titre: titre, ecran: "—", rangees: [],
                ecartees: ecartees + eligibles.map {
                    Ecartee(nom: $0.name, raison: L("rangement.raison.sansEcran"))
                }
            )
            return
        }

        let zone = LayoutComputer.zoneAX(visibleFrame: ecran.visibleFrame,
                                         hauteurPrincipale: hauteurPrincipale)
        let voulu = grandAuRang.flatMap { manager.effectif.indices.contains($0) ? manager.effectif[$0].slotKey : nil }
        let indexPrincipal = LayoutComputer.indexPrincipal(
            parmi: eligibles.map(\.slotKey), voulu: voulu,
            devant: eligibles.first { $0.pid == manager.frontmostPID }?.slotKey)
        let cadres = LayoutComputer.cadres(disposition, nombre: eligibles.count,
                                           indexPrincipal: indexPrincipal, dans: zone)

        var rangees: [String] = []
        var places: [String: AgencementPrincipal.Place] = [:]
        for (client, cadre) in zip(eligibles, cadres) {
            let fenetre = client.axWindow
            // Ranger, c'est vouloir tout voir : une fenêtre réduite est reposée.
            // C'est une opération de fenêtre, pas un évènement.
            AccessibilityReader.unminimize(fenetre)
            let erreur = poser(fenetre, cadre)
            if erreur == .success {
                rangees.append(client.name)
                if disposition == .principale, let lu = AccessibilityReader.frame(of: fenetre) {
                    places[client.slotKey] = AgencementPrincipal.Place(voulu: cadre, lu: lu)
                }
            } else {
                ecartees.append(Ecartee(nom: client.name,
                                        raison: L("rangement.raison.refus", Int(erreur.rawValue))))
            }
        }
        if disposition == .principale {
            agencement = AgencementPrincipal(places: places, grand: eligibles[indexPrincipal].slotKey)
        }

        dernierRapport = Rapport(date: Date(), titre: titre,
                                 ecran: ecran.localizedName, rangees: rangees,
                                 ecartees: ecartees)
        Preferences.shared.lastArrangement = disposition
    }

    /// Taille → position → taille : tant que la fenêtre chevauche son ancien
    /// écran, certains clients plafonnent la taille demandée — le second
    /// passage, fait une fois la fenêtre en place, corrige.
    private func poser(_ fenetre: AXHandle, _ cadre: CGRect) -> AXError {
        var erreur = AccessibilityReader.set(fenetre, size: cadre.size)
        let deplacement = AccessibilityReader.set(fenetre, position: cadre.origin)
        if erreur == .success { erreur = deplacement }
        if erreur == .success { erreur = AccessibilityReader.set(fenetre, size: cadre.size) }
        return erreur
    }

    // MARK: - Le grand suit la bascule

    /// Dans un « Un grand + vignettes » en cours, le perso que Synfus amène
    /// devant prend la place du grand, l'ancien grand prend sa vignette. Seul
    /// `WindowManager.focus` l'appelle : un clic sur une fenêtre n'y passe pas
    /// et ne réarrange rien — on ne le déduit jamais du premier plan observé.
    func suivreBascule(vers client: DofusClient) {
        guard let agencement, agencement.estVignette(client.slotKey) else { return }
        let manager = WindowManager.shared
        let concernes = [client.slotKey, agencement.grand]
        // Un dormant n'a plus d'élément AX lisible, un injoignable coûterait la
        // borne d'IPC : l'un comme l'autre manque aux lectures, donc abandonne.
        var fenetres: [String: AXHandle] = [:]
        for candidat in manager.clients
        where concernes.contains(candidat.slotKey) && !candidat.dormant && manager.isReachable(candidat) {
            fenetres[candidat.slotKey] = candidat.axWindow
        }
        switch agencement.suite(amene: client.slotKey, lus: fenetres.compactMapValues(AccessibilityReader.frame(of:))) {
        case .rien:
            return
        case .abandonner:
            self.agencement = nil
        case .permuter(let permutation):
            guard let amenee = fenetres[permutation.amene],
                  let ancienGrand = fenetres[permutation.ancienGrand],
                  poser(amenee, permutation.cadreAmene) == .success,
                  poser(ancienGrand, permutation.cadreAncienGrand) == .success
            else {
                self.agencement = nil
                return
            }
            self.agencement = agencement.apres(
                permutation, lus: fenetres.compactMapValues(AccessibilityReader.frame(of:)))
        }
    }

    // MARK: - Plein écran

    /// Envoie chaque client dans son propre espace plein écran — un bureau par
    /// perso, et la bascule (⌘n, la barre) fait le voyage d'un espace à
    /// l'autre. L'attribut est tenté aussi sur les dormants : leur élément est
    /// périmé pour la géométrie, mais le basculement passe par l'objet fenêtre
    /// lui-même — hypothèse, rapportée au Diagnostic comme les autres.
    func toutEnPleinEcran() async { await pleinEcran(true, titre: L("rangement.toutPleinEcran")) }

    /// L'inverse : ramène toutes les fenêtres en mode fenêtré, chacune sur le
    /// bureau d'où elle était partie.
    func toutSortirDuPleinEcran() async { await pleinEcran(false, titre: L("rangement.toutSortirPleinEcran")) }

    private func pleinEcran(_ actif: Bool, titre: String) async {
        agencement = nil
        let manager = WindowManager.shared
        await manager.refreshed()

        var rangees: [String] = []
        var ecartees: [Ecartee] = []
        for client in manager.effectif {
            let fenetre = client.axWindow
            if !client.dormant, !manager.isReachable(client) {
                ecartees.append(Ecartee(nom: client.name, raison: L("rangement.raison.muet")))
                continue
            }
            if AccessibilityReader.boolAttribute(fenetre, "AXFullScreen") == actif {
                rangees.append(client.name)
                continue
            }
            let erreur = AccessibilityReader.set(
                fenetre, "AXFullScreen", actif ? kCFBooleanTrue : kCFBooleanFalse
            )
            if erreur == .success {
                rangees.append(client.name)
            } else {
                ecartees.append(Ecartee(nom: client.name, raison: client.dormant
                    ? L("rangement.raison.autreBureau")
                    : L("rangement.raison.refus", Int(erreur.rawValue))))
            }
        }

        if rangees.isEmpty { NSSound.beep() }
        dernierRapport = Rapport(date: Date(), titre: titreAvecEquipe(titre), ecran: "—",
                                 rangees: rangees, ecartees: ecartees)
    }

    /// Le geste a porté sur une équipe : le Diagnostic doit le dire, sinon les
    /// persos hors équipe passeraient pour oubliés.
    private func titreAvecEquipe(_ titre: String) -> String {
        guard let equipe = WindowManager.shared.equipeActive else { return titre }
        return L("rangement.titreEquipe", titre, equipe + 1)
    }

    // MARK: - Écran

    /// L'écran qui héberge la fenêtre du client — lu sur sa position AX,
    /// ramenée en coordonnées Cocoa. Un point légèrement rentré dans la
    /// fenêtre évite les litiges de bord entre écrans jointifs.
    private func ecran(de client: DofusClient, hauteurPrincipale: CGFloat) -> NSScreen? {
        guard let position = AccessibilityReader.pointAttribute(client.axWindow, kAXPositionAttribute)
        else { return nil }
        let cocoa = CGPoint(x: position.x + 10,
                            y: LayoutComputer.flipY(position.y + 10, hauteurPrincipale: hauteurPrincipale))
        return NSScreen.screens.first { $0.frame.contains(cocoa) }
    }
}
