// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 9109fc88022f5d8a · contenu d81197449411d28a
import SwiftUI

// La trousse (`K` de reference/gabarit.html) en SwiftUI, ses fondations : les couleurs posées dans
// l'environnement, les états imposés aux captures, le curseur de clic et l'anneau de focus communs.
// Les contrôles ne lisent que `Jetons` et ces couleurs ; libellés et actions viennent de l'appelant.

extension EnvironmentValues {
    /// Les couleurs du thème courant. Chaque racine de l'app les pose (`themeSynseria`,
    /// `couleursSynseria`) : une racine oubliée se dessine au thème et à la nuance par défaut de
    /// l'app (en Jour si elle suit le système), quelle que soit l'apparence.
    @Entry var couleursSynseria: Jetons.Couleurs = Jetons.couleursParDefaut
    /// Le survol, la pression et le focus imposés à un contrôle (une capture n'a ni souris ni
    /// clavier) ; nil : la souris et le clavier.
    @Entry var etatImpose: EtatImpose?
    /// Le texte imposé aux champs à suggestions : leur liste ouverte, filtrée par lui (une capture
    /// n'a pas de clavier) ; nil : la frappe.
    @Entry var saisieImposee: String?
    /// Une racine pose l'hôte des listes (`hoteDesSuggestions`) : un champ à suggestions y ouvre la sienne.
    @Entry var hoteDesSuggestions = false
}

extension Jetons {
    static let couleursParDefaut = Nuancier.couleurs(themeParDefaut, nuanceParDefaut ?? .jour)
}

/// Le survol, la pression et le focus imposés à un contrôle de la trousse.
struct EtatImpose: Hashable, Sendable {
    var survole = false
    var presse = false
    var focus = false
}

extension View {
    /// La main au survol de ce qui se clique (`cursor:pointer` de la trousse) ; grisé, rien
    /// (`pointer-events:none`). iOS n'a pas de pointeur à changer.
    @ViewBuilder func curseurDeClic(_ actif: Bool) -> some View {
        #if os(macOS)
        pointerStyle(actif ? .link : nil)
        #else
        self
        #endif
    }

    /// L'anneau du focus clavier de la trousse (`anneau-focus`) : un trait d'accent d'`epaisseur-focus`,
    /// à `decalage-focus` hors de la forme, comme `outline` ; celui du système est retiré, sinon deux
    /// anneaux se superposent.
    func anneauDeFocus<Forme: InsettableShape>(_ forme: Forme, visible: Bool) -> some View {
        modifier(AnneauDeFocus(forme: forme, visible: visible))
    }
}

private struct AnneauDeFocus<Forme: InsettableShape>: ViewModifier {
    let forme: Forme
    let visible: Bool
    @Environment(\.couleursSynseria) private var c

    func body(content: Content) -> some View {
        content
            .overlay {
                if visible {
                    forme.inset(by: -(Jetons.decalageFocus + Jetons.epaisseurFocus))
                        .strokeBorder(c.accent.couleur, lineWidth: Jetons.epaisseurFocus)
                }
            }
            .focusEffectDisabled()
    }
}

extension View {
    /// Pose les couleurs d'un thème ; sans nuance, elle suit l'apparence (Jour ou Pénombre).
    func themeSynseria(_ theme: Jetons.Theme, nuance: Jetons.Nuance?) -> some View {
        modifier(ThemeSynseria(theme: theme, nuance: nuance))
    }

    /// Pose des couleurs déjà calculées (une app qui les garde en cache).
    func couleursSynseria(_ couleurs: Jetons.Couleurs) -> some View {
        environment(\.couleursSynseria, couleurs)
    }
}

private struct ThemeSynseria: ViewModifier {
    let theme: Jetons.Theme
    let nuance: Jetons.Nuance?
    @Environment(\.colorScheme) private var apparence

    func body(content: Content) -> some View {
        content.environment(\.couleursSynseria,
                            Jetons.Nuancier.couleurs(theme, nuance ?? .duSysteme(sombre: apparence == .dark)))
    }
}

extension Jetons.Couleurs {
    /// La piste d'un interrupteur éteint (`.tg`) : l'encre mêlée à la plaque, plus au survol.
    func piste(survolee: Bool) -> Jetons.RVB {
        Jetons.Octets.melange(Jetons.Octets(plaque.hex), Jetons.Octets(encre.hex),
                              survolee ? Jetons.pisteSurvol : Jetons.pisteRepos).rvb
    }
}
