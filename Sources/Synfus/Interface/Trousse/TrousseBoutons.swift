// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 9109fc88022f5d8a · contenu 6d565750bb9153ec
import SwiftUI

// Les boutons de la trousse (`.b`) et le menu à icône à leur gabarit.

// MARK: - Les boutons

/// Les boutons de la trousse (`.b`), un seul dessin : une pilule de `hauteur-controle` (l'icône et le
/// rond, un cercle), le survol, la pression qui rétrécit le bouton, le
/// grisé à `opacite-desactive`. L'aspect d'un état est une fonction pure (`aspect`).
enum RangDeBouton: Hashable, Sendable {
    case principal, borde, tertiaire, destructif
    /// Plein `accent`, rond, une icône seule (`.b.rond`).
    case rond
    /// Allumé (un mode en cours, un affichage choisi) : le fond du choix, l'accent en texte.
    case icone(allume: Bool)

    enum Fond: Hashable, Sendable {
        case accent, accentSurvol, accentPresse, page, survol, selection, danger, dangerSurvol, dangerPresse
        /// Le survol et la pression d'un bouton-icône : un voile de l'encre (`.b.ico`).
        case voileDeSurvol, voileDePression
    }

    enum Encre: Hashable, Sendable { case encre, encre2, accentTexte, texteSurAccent, texteSurDanger }

    struct Aspect: Hashable, Sendable {
        /// Du dessous au dessus : le survol d'un bordé se pose sur la fenêtre.
        var fonds: [Fond]
        var encre: Encre
        var contour = false
        var souligne = false
        var presse = false
    }

    func aspect(survole: Bool, presse: Bool) -> Aspect {
        switch self {
        case .principal, .rond:
            Aspect(fonds: [presse ? .accentPresse : survole ? .accentSurvol : .accent], encre: .texteSurAccent, presse: presse)
        case .destructif:
            Aspect(fonds: [presse ? .dangerPresse : survole ? .dangerSurvol : .danger], encre: .texteSurDanger, presse: presse)
        case .borde:
            Aspect(fonds: [.page] + (presse ? [.selection] : survole ? [.survol] : []), encre: .encre, contour: true, presse: presse)
        case .tertiaire:
            Aspect(fonds: presse ? [.selection] : survole ? [.survol] : [], encre: .accentTexte, souligne: survole, presse: presse)
        case .icone(let allume):
            // Allumé, la pression ne fait que rétrécir : `.b.ico.on` passe après `:active` dans la cascade.
            if allume { Aspect(fonds: [.selection], encre: .accentTexte, presse: presse) }
            else { Aspect(fonds: presse ? [.voileDePression] : survole ? [.voileDeSurvol] : [], encre: survole || presse ? .encre : .encre2, presse: presse) }
        }
    }
}

extension Jetons.Couleurs {
    func rvb(_ fond: RangDeBouton.Fond) -> Jetons.RVB {
        switch fond {
        case .accent: accent
        case .accentSurvol: accentSurvol
        case .accentPresse: accentPresse
        case .page: fondFenetre
        case .survol: survol
        case .selection: selection
        case .danger: danger
        case .dangerSurvol: dangerSurvol
        case .dangerPresse: dangerPresse
        case .voileDeSurvol: encre.voile(Jetons.voileSurvol)
        case .voileDePression: encre.voile(Jetons.voilePression)
        }
    }

    func rvb(_ encre: RangDeBouton.Encre) -> Jetons.RVB {
        switch encre {
        case .encre: self.encre
        case .encre2: encre2
        case .accentTexte: accentTexte
        case .texteSurAccent: texteSurAccent
        case .texteSurDanger: texteSurDanger
        }
    }
}

/// Le bouton principal d'une zone : plein `accent`. Un seul par zone.
struct BoutonPrincipal: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { CorpsDeBouton(configuration: configuration, rang: .principal) }
}

/// Le bouton secondaire : la fenêtre et son filet. Un geste destructif n'est jamais bordé.
struct BoutonBorde: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { CorpsDeBouton(configuration: configuration, rang: .borde) }
}

/// Le bouton tertiaire (« Annuler ») : un lien, l'accent en texte, sans bord.
struct BoutonTertiaire: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { CorpsDeBouton(configuration: configuration, rang: .tertiaire) }
}

/// Le bouton destructif : plein `danger`. Jamais l'action par défaut : ⏎ ne détruit rien.
struct BoutonDestructif: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { CorpsDeBouton(configuration: configuration, rang: .destructif) }
}

/// Le bouton rond : plein `accent`, une icône seule, de `hauteur-controle` de diamètre.
struct BoutonRond: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { CorpsDeBouton(configuration: configuration, rang: .rond) }
}

/// Un bouton-icône plat, rond, de `hauteur-controle` de diamètre, l'icône à `taille-icone` en encre secondaire.
struct BoutonIcone: ButtonStyle {
    var allume = false

    func makeBody(configuration: Configuration) -> some View {
        CorpsDeBouton(configuration: configuration, rang: .icone(allume: allume))
    }
}

extension View {
    func boutonIcone(allume: Bool = false) -> some View {
        buttonStyle(BoutonIcone(allume: allume))
    }
}

private struct CorpsDeBouton: View {
    let configuration: ButtonStyleConfiguration
    let rang: RangDeBouton
    @Environment(\.isEnabled) private var actif
    @Environment(\.isFocused) private var focalise
    @Environment(\.etatImpose) private var impose
    @Environment(\.couleursSynseria) private var c
    @State private var survole = false

    var body: some View {
        let aspect = rang.aspect(survole: actif && (impose?.survole ?? survole), presse: actif && (impose?.presse ?? configuration.isPressed))
        // La pilule (le cercle d'une icône) : la moitié de sa hauteur. Coins circulaires partout, comme
        // `border-radius` : en coins continus, `rayon-pilule` (999) dessine un rectangle rogné et une
        // demi-hauteur, un galet.
        let forme = RoundedRectangle(cornerRadius: Jetons.hauteurControle / 2, style: .circular)
        return libelle
            .foregroundStyle(c.rvb(aspect.encre).couleur)
            .underline(aspect.souligne)
            .background {
                ZStack { ForEach(aspect.fonds, id: \.self) { forme.fill(c.rvb($0).couleur) } }
            }
            .overlay { if aspect.contour { forme.strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) } }
            .anneauDeFocus(forme, visible: actif && (impose?.focus ?? focalise))
            .contentShape(forme)
            .scaleEffect(aspect.presse ? Jetons.echellePressee : 1)
            // Le grisé d'un tout, comme `opacity` en CSS : sans groupe, chaque couche pâlit sur l'autre.
            .compositingGroup()
            .opacity(actif ? 1 : Jetons.opaciteDesactive)
            .onHover { survole = $0 }
            .curseurDeClic(actif)
            .animation(Jetons.courbeStandard.animation(Jetons.dureeRapide), value: aspect)
    }

    @ViewBuilder private var libelle: some View {
        switch rang {
        case .icone, .rond:
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: Jetons.tailleIcone))
                .imageScale(.medium)
                .frame(width: Jetons.hauteurControle, height: Jetons.hauteurControle)
        default:
            // Un libellé de bouton ne se coupe jamais : la rangée cède sa place, pas le bouton. Le
            // filet compte dans la largeur, posé ou non (`.b` : bordure transparente).
            configuration.label
                .font(Jetons.typoCorps.font)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, (rang == .tertiaire ? Jetons.espace2 : Jetons.espace3) + Jetons.epaisseurFilet)
                .frame(height: Jetons.hauteurControle)
        }
    }
}

#if os(macOS)
// MARK: - Le menu à icône

extension View {
    /// Un menu au gabarit des boutons-icônes : pas de chevron, la même taille, le même survol ;
    /// `allume` quand il filtre (une étiquette, un niveau choisis).
    func menuIcone(allume: Bool = false) -> some View {
        menuStyle(.button)
            .menuIndicator(.hidden)
            .boutonIcone(allume: allume)
            .labelStyle(.iconOnly)
            .fixedSize()
    }
}

/// Un menu à icône, du même gabarit que `BoutonIcone` ; son titre en infobulle.
struct MenuIcone<Contenu: View>: View {
    let titre: String
    let symbole: String
    var allume = false
    @ViewBuilder var contenu: Contenu

    var body: some View {
        Menu { contenu } label: { Label(titre, systemImage: symbole) }
            .menuIcone(allume: allume)
            .help(titre)
    }
}
#endif
