// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 9109fc88022f5d8a · contenu 6126883cdbd3bc7d
import SwiftUI

// Ce qui range une page : état vide, carte, dépliable, formulaire de réglages en sections.

// MARK: - État vide

/// Un état vide (`.vide`) : son symbole dans un rond du fond du choix, son titre et, s'il y a un
/// geste, son bouton bordé — jamais une phrase qui explique. À la place de
/// `ContentUnavailableView`, qui met son titre en gras et ajoute une description.
struct EtatVide<Actions: View>: View {
    let titre: String
    let symbole: String
    var ton: Ton?
    let actions: Actions
    @Environment(\.couleursSynseria) private var c

    init(_ titre: String, symbole: String, ton: Ton? = nil, @ViewBuilder actions: () -> Actions) {
        (self.titre, self.symbole, self.ton, self.actions) = (titre, symbole, ton, actions())
    }

    var body: some View {
        VStack(spacing: Jetons.espace3) {
            Image(systemName: symbole)
                .font(.system(size: Jetons.espace5))
                .foregroundStyle((ton?.rvb(c) ?? c.accentTexte).couleur)
                .frame(width: Jetons.hauteurRangee * 1.5, height: Jetons.hauteurRangee * 1.5)
                .background((ton.map { $0.rvb(c).voile(Jetons.Parametres.tauxSelection / 100) } ?? c.selection).couleur, in: .circle)
            Text(titre)
                .font(Jetons.typoTitreCarte.font)
                .foregroundStyle(c.encre.couleur)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            actions
                .buttonStyle(BoutonBorde())
                .padding(.top, Jetons.espace1)
        }
        .padding(Jetons.espace5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EtatVide where Actions == EmptyView {
    init(_ titre: String, symbole: String, ton: Ton? = nil) {
        self.init(titre, symbole: symbole, ton: ton) { EmptyView() }
    }
}

// MARK: - Le dépliable

/// L'en-tête d'un dépliable (`.rpl`) : le chevron et son libellé ne font qu'un bouton — un clic sur
/// le libellé ouvre aussi, pas seulement sur la flèche. Le seul dessin d'un dépliable : celui des
/// `DisclosureGroup` (`.rubriqueRepliable`) et des rangées repliées faites main.
struct EnTeteRepliable<Libelle: View>: View {
    let deplie: Bool
    let basculer: () -> Void
    @ViewBuilder var libelle: Libelle
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        Button(action: basculer) {
            HStack(spacing: Jetons.espace2) {
                Image(systemName: deplie ? "chevron.down" : "chevron.right")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.semibold)
                    .foregroundStyle(c.encre3.couleur)
                    .frame(width: Jetons.diametreMini, height: Jetons.diametreMini)
                libelle
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .curseurDeClic(true)
        .accessibilityAddTraits(deplie ? .isSelected : [])
    }
}

/// Le style des `DisclosureGroup` : l'en-tête commun, le contenu aligné sur le libellé. Posé à la
/// racine de chaque hôte : le style du système n'ouvre qu'au clic sur la flèche.
struct RubriqueRepliable: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EnTeteRepliable(deplie: configuration.isExpanded, basculer: { configuration.isExpanded.toggle() }) {
                configuration.label
            }
            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, Jetons.diametreMini + Jetons.espace2)
            }
        }
    }
}

extension DisclosureGroupStyle where Self == RubriqueRepliable {
    static var rubriqueRepliable: RubriqueRepliable { RubriqueRepliable() }
}

// MARK: - Le formulaire de réglages

/// Un volet de réglages (`.sc`) : des sections à cartes, serrées — le `Form` groupé de macOS a des
/// rangées de 40 pt et des sections que rien ne règle. `enBas` : appelé quand le défilement
/// approche du bas, pour une liste par pages.
struct FormulaireCompact<Contenu: View>: View {
    var enBas: (() -> Void)?
    var contenu: Contenu

    init(enBas: (() -> Void)? = nil, @ViewBuilder contenu: () -> Contenu) {
        self.enBas = enBas
        self.contenu = contenu()
    }

    /// L'air autour des cartes, le padding de la plaque des réglages (`.sw .main`).
    static var marge: CGFloat { Jetons.espace5 }

    /// La marge avant le bas qui demande la suite : la page arrive avant qu'on y bute.
    private static var avance: CGFloat { 400 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Jetons.espace3) { contenu }
                .padding(Self.marge)
        }
        .contentMargins(.vertical, 0, for: .scrollContent)
        .onScrollGeometryChange(for: Bool.self) { geometrie in
            geometrie.contentOffset.y + geometrie.containerSize.height >= geometrie.contentSize.height - Self.avance
        } action: { _, presDuBas in
            if presDuBas { enBas?() }
        }
    }
}

/// Une section : son titre (l'explication en infobulle, jamais dessous), puis une carte dont chaque
/// vue est une rangée, séparée de la suivante par un filet.
struct SectionCompacte<Contenu: View>: View {
    var titre: String?
    var aide: String?
    @ViewBuilder var contenu: Contenu
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            if let titre {
                Text(titre)
                    .font(Jetons.typoTitreCarte.font)
                    .foregroundStyle(c.encre2.couleur)
                    .padding(.leading, Jetons.espace1)
                    .help(aide ?? "")
            }
            rangees
                .background(c.carte.couleur, in: forme)
                .overlay { forme.strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
                .clipShape(forme)
        }
    }

    /// Chaque vue, une rangée : `hauteur-rangee` − `espace-2` au moins, `espace-3` de côté.
    private var rangees: some View {
        VStack(spacing: 0) {
            Group(subviews: contenu) { vues in
                ForEach(Array(vues.enumerated()), id: \.element.id) { index, vue in
                    if index > 0 { Rectangle().fill(c.filet.couleur).frame(height: Jetons.epaisseurFilet) }
                    vue
                        .frame(maxWidth: .infinity, minHeight: Jetons.hauteurRangee - Jetons.espace2, alignment: .leading)
                        .padding(.horizontal, Jetons.espace3)
                        .padding(.vertical, Jetons.espace1)
                }
            }
        }
    }
}

/// Une rangée « libellé … contrôle » : le libellé à gauche (son aide en infobulle), le contrôle à
/// droite, à sa taille.
struct RangeeReglage<Controle: View>: View {
    let titre: String
    var aide: String?
    /// Faux quand le contrôle porte un libellé à lui (« ☐ Régler ») : sinon, le titre de la
    /// rangée le dit déjà, et celui du contrôle se tait.
    var libellesCaches = true
    @ViewBuilder var controle: Controle
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        HStack {
            Text(titre).font(Jetons.typoCorps.font).foregroundStyle(c.encre.couleur).help(aide ?? "")
            Spacer(minLength: Jetons.espace3)
            Group {
                if libellesCaches { controle.labelsHidden() } else { controle }
            }
            .fixedSize()
        }
    }
}

/// Le bouton « supprimer » d'une rangée de réglages : la corbeille en encre secondaire, `danger` au
/// survol. Sur macOS, `.onDelete` dans un `Form` n'offre ni geste ni bouton.
struct BoutonSupprimer: View {
    let aide: String
    let action: () -> Void
    @State private var survole = false
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .font(.system(size: Jetons.tailleIcone))
                .foregroundStyle((survole ? c.danger : c.encre2).couleur)
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .curseurDeClic(true)
        .help(aide)
        .accessibilityLabel(aide)
    }
}

// MARK: - La carte

/// Une carte (`.carte`) : la plaque, son filet, `rayon-2`, `espace-4` d'air. Bordure, jamais d'ombre.
/// Choisie, le contour du choix (l'encre secondaire, au trait d'état).
struct Carte: ViewModifier {
    var marge: CGFloat = Jetons.espace4
    var choisie = false
    @Environment(\.couleursSynseria) private var c

    func body(content: Content) -> some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
        content
            .padding(marge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(c.carte.couleur, in: forme)
            .overlay {
                forme.strokeBorder((choisie ? c.encre2 : c.filet).couleur,
                                   lineWidth: choisie ? Jetons.epaisseurFocus : Jetons.epaisseurFilet)
            }
    }
}

extension View {
    func carte(marge: CGFloat = Jetons.espace4, choisie: Bool = false) -> some View {
        modifier(Carte(marge: marge, choisie: choisie))
    }
}
