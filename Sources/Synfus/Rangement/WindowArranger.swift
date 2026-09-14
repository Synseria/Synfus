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

    private init() {}

    /// Rejoue la dernière disposition choisie — c'est l'action du raccourci.
    func appliquerDerniere() {
        appliquer(Preferences.shared.lastArrangement ?? .mosaique)
    }

    func appliquer(_ disposition: Disposition) {
        let manager = WindowManager.shared
        // L'inventaire d'abord : l'utilisateur vient peut-être de connecter ou
        // fermer un client, et on range ce qu'il voit, pas ce qu'on croyait.
        manager.refresh()

        var eligibles: [DofusClient] = []
        var ecartees: [Ecartee] = []
        for client in manager.clients {
            if client.dormant {
                // Son élément AX est périmé — la fenêtre vit sur un espace
                // inactif, hors de portée. Le remède est dans le Diagnostic.
                ecartees.append(Ecartee(
                    nom: client.name,
                    raison: "sur un autre bureau — bascule dessus puis relance le rangement"
                ))
            } else if !manager.isReachable(client) {
                // En cours de fermeture, ou muet au veilleur de gel : lui poser
                // une question, c'est payer la borne d'une seconde pour rien.
                ecartees.append(Ecartee(nom: client.name, raison: "ne répond plus"))
            } else if AccessibilityReader.boolAttribute(client.axWindow, "AXFullScreen") == true {
                // On ne sort jamais personne du plein écran d'autorité.
                ecartees.append(Ecartee(nom: client.name, raison: "en plein écran"))
            } else {
                eligibles.append(client)
            }
        }

        guard !eligibles.isEmpty, let hauteurPrincipale = NSScreen.screens.first?.frame.height
        else {
            NSSound.beep()
            dernierRapport = Rapport(date: Date(), titre: disposition.label,
                                     ecran: "—", rangees: [], ecartees: ecartees)
            return
        }

        // Tout est ramené sur un seul écran — c'est le sens du geste « en un
        // coup ». Lequel : celui du perso au premier plan, à défaut celui de la
        // première fenêtre rangée, à défaut l'écran principal.
        let repere = eligibles.first { $0.pid == manager.frontmostPID } ?? eligibles[0]
        let ecran = ecran(de: repere, hauteurPrincipale: hauteurPrincipale) ?? NSScreen.main
        guard let ecran else {
            NSSound.beep()
            return
        }

        let zone = LayoutComputer.zoneAX(visibleFrame: ecran.visibleFrame,
                                         hauteurPrincipale: hauteurPrincipale)
        let indexPrincipal = eligibles.firstIndex { $0.pid == manager.frontmostPID } ?? 0
        let cadres = LayoutComputer.cadres(disposition, nombre: eligibles.count,
                                           indexPrincipal: indexPrincipal, dans: zone)

        var rangees: [String] = []
        for (client, cadre) in zip(eligibles, cadres) {
            let fenetre = client.axWindow
            // Ranger, c'est vouloir tout voir : une fenêtre réduite est reposée.
            // C'est une opération de fenêtre, pas un évènement.
            if AccessibilityReader.boolAttribute(fenetre, kAXMinimizedAttribute) == true {
                AccessibilityReader.set(fenetre, kAXMinimizedAttribute, kCFBooleanFalse)
            }
            // Taille → position → taille : tant que la fenêtre chevauche son
            // ancien écran, certains clients plafonnent la taille demandée — le
            // second passage, fait une fois la fenêtre en place, corrige.
            var erreur = AccessibilityReader.set(fenetre, size: cadre.size)
            let deplacement = AccessibilityReader.set(fenetre, position: cadre.origin)
            if erreur == .success { erreur = deplacement }
            if erreur == .success { erreur = AccessibilityReader.set(fenetre, size: cadre.size) }

            if erreur == .success {
                rangees.append(client.name)
            } else {
                ecartees.append(Ecartee(nom: client.name,
                                        raison: "le client a refusé (AXError \(erreur.rawValue))"))
            }
        }

        dernierRapport = Rapport(date: Date(), titre: disposition.label,
                                 ecran: ecran.localizedName, rangees: rangees,
                                 ecartees: ecartees)
        Preferences.shared.lastArrangement = disposition
    }

    // MARK: - Plein écran

    /// Envoie chaque client dans son propre espace plein écran — un bureau par
    /// perso, et la bascule (⌘n, la barre) fait le voyage d'un espace à
    /// l'autre. L'attribut est tenté aussi sur les dormants : leur élément est
    /// périmé pour la géométrie, mais le basculement passe par l'objet fenêtre
    /// lui-même — hypothèse, rapportée au Diagnostic comme les autres.
    func toutEnPleinEcran() { pleinEcran(true, titre: "Tout en plein écran") }

    /// L'inverse : ramène toutes les fenêtres en mode fenêtré, chacune sur le
    /// bureau d'où elle était partie.
    func toutSortirDuPleinEcran() { pleinEcran(false, titre: "Tout sortir du plein écran") }

    private func pleinEcran(_ actif: Bool, titre: String) {
        let manager = WindowManager.shared
        manager.refresh()

        var rangees: [String] = []
        var ecartees: [Ecartee] = []
        for client in manager.clients {
            let fenetre = client.axWindow
            if !client.dormant, !manager.isReachable(client) {
                ecartees.append(Ecartee(nom: client.name, raison: "ne répond plus"))
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
                    ? "sur un autre bureau — bascule dessus puis relance"
                    : "le client a refusé (AXError \(erreur.rawValue))"))
            }
        }

        if rangees.isEmpty { NSSound.beep() }
        dernierRapport = Rapport(date: Date(), titre: titre, ecran: "—",
                                 rangees: rangees, ecartees: ecartees)
    }

    // MARK: - Écran

    /// L'écran qui héberge la fenêtre du client — lu sur sa position AX,
    /// ramenée en coordonnées Cocoa. Un point légèrement rentré dans la
    /// fenêtre évite les litiges de bord entre écrans jointifs.
    private func ecran(de client: DofusClient, hauteurPrincipale: CGFloat) -> NSScreen? {
        guard let position = AccessibilityReader.pointAttribute(client.axWindow, kAXPositionAttribute)
        else { return nil }
        let cocoa = CGPoint(x: position.x + 10, y: hauteurPrincipale - (position.y + 10))
        return NSScreen.screens.first { $0.frame.contains(cocoa) }
    }
}
