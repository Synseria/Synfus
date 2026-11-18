// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 9109fc88022f5d8a · contenu e75a740215f4405a
import SwiftUI

// La marque et le verre : le signe Synseria, le gabarit d'À propos, la teinte du verre.

// MARK: - Le signe et l'À propos

/// Le signe Synseria : l'emblème de l'app et le mot « synseria » à côté (« syn » en encre,
/// « seria » en encre secondaire), jamais dans le rond. L'emblème vient de `marque/`, posé dans
/// les ressources de l'app ; Outfit n'est pas embarquée : le mot prend la police arrondie du système.
struct SigneSynseria: View {
    let embleme: Image
    var hauteur: CGFloat = Jetons.espace5
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        HStack(spacing: hauteur * 0.3) {
            embleme.resizable().scaledToFit().frame(width: hauteur, height: hauteur)
            Self.mot(taille: hauteur * 0.56, couleurs: c)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Synseria")
    }

    /// Le mot seul, la seule façon de l'écrire.
    static func mot(taille: CGFloat, couleurs c: Jetons.Couleurs) -> Text {
        let syn = Text("syn").foregroundStyle(c.encre.couleur)
        let seria = Text("seria").foregroundStyle(c.encre2.couleur)
        return Text("\(syn)\(seria)").font(.system(size: taille, weight: .semibold, design: .rounded))
    }
}

/// « À propos » (`.apropos`), une colonne centrée de `largeur-apropos` : l'icône de l'app (celle
/// du Dock ; l'emblème est la marque de l'éditeur), son nom, « by » et le signe, puis sa ligne — la
/// version entière, ou l'état de la mise à jour et son geste.
struct GabaritAPropos<Ligne: View>: View {
    let icone: Image
    let nom: String
    let embleme: Image
    @ViewBuilder var ligne: Ligne
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        VStack(spacing: Jetons.espace5) {
            VStack(spacing: Jetons.espace2) {
                icone.resizable().scaledToFit()
                    .frame(width: Jetons.espace7 * 2, height: Jetons.espace7 * 2)
                    .accessibilityHidden(true)
                Text(nom).font(Jetons.typoTitrePage.font).foregroundStyle(c.encre.couleur)
                HStack(alignment: .center, spacing: Jetons.espace2) {
                    Text("by").font(Jetons.typoMeta.font).foregroundStyle(c.encre2.couleur)
                    SigneSynseria(embleme: embleme)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("by Synseria")
            }
            ligne
        }
        .padding(Jetons.espace6)
        .frame(width: Jetons.largeurApropos)
    }
}

/// La ligne d'un À propos sans mise à jour : la version entière, en méta, sélectionnable.
struct LigneDeVersion: View {
    let texte: String
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        Text(texte)
            .font(Jetons.typoMeta.font)
            .foregroundStyle(c.encre2.couleur)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

// MARK: - Le verre

/// Ce que porte un verre et ce que la page en couvre — la seule mesure. Une fenêtre au focus : du
/// verre franc (`verre-opacite-focus`), le bureau flouté se voit, le texte reste sur ses plaques ;
/// hors focus, le système éteint le reflet et le verre s'éclaircirait : un voile dense
/// (`verre-opacite-hors-focus`) la garde posée. Un flottant, rarement au focus, garde un verre plus
/// léger (`verre-opacite-flottant`). « Réduire la transparence » et « Augmenter le contraste »
/// refusent le verre : la page pleine.
enum UsageDuVerre: Hashable, Sendable {
    case fenetre, flottant

    func opacite(auFocus: Bool, verreRefuse: Bool = false) -> Double {
        if verreRefuse { return 1 }
        switch self {
        case .fenetre: return auFocus ? Jetons.verreOpaciteFocus : Jetons.verreOpaciteHorsFocus
        case .flottant: return Jetons.verreOpaciteFlottant
        }
    }
}

/// La teinte posée sur le verre (le matériau, Liquid Glass ou son repli, reste à l'app) : la page à
/// l'opacité de son usage, qui suit le focus de la fenêtre (courbe standard, durée normale).
struct TeinteDuVerre: View {
    var usage: UsageDuVerre = .fenetre
    @Environment(\.couleursSynseria) private var c
    @Environment(\.accessibilityReduceTransparency) private var transparenceReduite
    @Environment(\.colorSchemeContrast) private var contraste
    @Environment(\.appearsActive) private var auFocus

    var body: some View {
        let refuse = transparenceReduite || contraste == .increased
        Rectangle()
            .fill(c.fondFenetre.couleur.opacity(usage.opacite(auFocus: auFocus, verreRefuse: refuse)))
            .animation(Jetons.courbeStandard.animation(Jetons.dureeNormale), value: auFocus)
            .allowsHitTesting(false)
    }
}
