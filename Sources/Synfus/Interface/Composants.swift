import SwiftUI

// Les briques de dessin communes, écrites sur les jetons : voix d'état, cartes, surface qui flotte,
// touche de raccourci, rangs de boutons. Une vue n'écrit ni couleur, ni rayon, ni durée.

// MARK: - Langage d'état

/// Les deux voix du design system et leurs états : le **plein** dit où je suis (un par zone), le
/// **teinté** dit ce que j'ai choisi. Sélectionné, survolé et pressé restent trois choses distinctes.
/// Une fenêtre n'a qu'un choix à voix, celui que les flèches déplacent : le choix d'un groupe qui n'a
/// pas le clavier, ou d'un niveau parent, est `inactif` — gris, sans bord, tout en `encre`.
enum EtatVisuel: Equatable {
    case repos, survol, presse, choisi, courant, inactif, desactive

    /// Le choix d'un groupe selon qu'il a le clavier : `voix` (teinté ou plein), sinon `inactif`.
    static func choix(_ voix: EtatVisuel = .choisi, auClavier: Bool) -> EtatVisuel { auClavier ? voix : .inactif }

    /// Du survol d'une zone et de la pression d'un bouton à l'état d'un contrôle au repos.
    init(survole: Bool, presse: Bool = false) {
        self = presse ? .presse : survole ? .survol : .repos
    }

    @MainActor var fond: Color {
        switch self {
        case .repos: .clear
        case .survol: Color.jeton(\.survol)
        case .presse: Color.jeton(\.pression)
        case .choisi: Color.jeton(\.primaireFond)
        case .courant: Color.jeton(\.primaire)
        case .inactif: Color.jeton(\.selectionInactive)
        case .desactive: Color.jeton(\.creux)
        }
    }

    @MainActor var contour: Color? { self == .choisi ? Color.jeton(\.primaire) : nil }

    /// L'encre du contenu : un contenu à voix s'écrit en encres, jamais en blanc conditionnel.
    @MainActor var encre: Color {
        switch self {
        case .courant: Color.jeton(\.encreSurPrimaire)
        case .choisi: Color.jeton(\.primaireEncre)
        case .desactive: Color.jeton(\.encreTertiaire)
        case .repos, .survol, .presse, .inactif: Color.jeton(\.encre)
        }
    }

    /// L'encre d'un contenu secondaire (libellé de second rang) dans le même état.
    @MainActor var encreSecondaire: Color {
        switch self {
        case .courant, .choisi, .inactif, .desactive: encre
        case .repos, .survol, .presse: Color.jeton(\.encreSecondaire)
        }
    }
}

extension View {
    /// Le fond d'un élément selon son état, au rayon de son cran ; seules la couleur et l'opacité s'animent.
    func fondEtat(_ etat: EtatVisuel, rayon: CGFloat = Jetons.Rayon.controle) -> some View {
        let forme = RoundedRectangle(cornerRadius: rayon, style: .continuous)
        return background(forme.fill(etat.fond))
            .overlay { if let contour = etat.contour { forme.strokeBorder(contour, lineWidth: Jetons.Trait.etat) } }
            .contentShape(forme)
            .animation(Jetons.Duree.animation(Jetons.Duree.survol), value: etat)
    }

    /// Dans une fenêtre : une carte en `surface` bordée d'un `filet`, sans ombre. Jamais dans une autre carte.
    func carte(rayon: CGFloat = Jetons.Rayon.carte) -> some View {
        let forme = RoundedRectangle(cornerRadius: rayon, style: .continuous)
        return background(forme.fill(Color.jeton(\.surface)))
            .overlay(forme.strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.Trait.filet))
    }

    /// Ce qui flotte sur le jeu : barre, palette, panneaux. Rayon `panneau` ; l'ombre `flottant` est
    /// celle de la fenêtre (`hasShadow`), qu'une ombre SwiftUI, coupée au cadre du panneau, ne rendrait pas.
    /// `verre` : le Liquid Glass (macOS 26) de la barre, qui ne porte que des pastilles ; les panneaux
    /// qui lisent du texte gardent le matériau épais.
    func surfaceFlottante(verre: Bool = false) -> some View {
        modifier(SurfaceFlottante(verre: verre))
    }
}

private struct SurfaceFlottante: ViewModifier {
    let verre: Bool

    func body(content: Content) -> some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.Rayon.panneau, style: .continuous)
        if Ressources.captureDocumentation {
            // `cacheDisplay` ne dessine ni le verre ni les matériaux, qui échantillonnent l'écran.
            content.background(forme.fill(Color.jeton(\.surface)))
        } else if verre, #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: Jetons.Rayon.panneau))
        } else {
            content.background(.regularMaterial, in: forme)
        }
    }
}

// MARK: - Touche de raccourci

/// La touche du clavier, dessinée une seule fois : fond `creux`, `filet`, `Rayon.pastille`, police `raccourci`.
struct ToucheRaccourci: View {
    let texte: String
    init(_ texte: String) { self.texte = texte }

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.Rayon.pastille, style: .continuous)
        Text(texte)
            .font(Jetons.Typo.raccourci.police)
            .foregroundStyle(Color.jeton(\.encre))
            .padding(.horizontal, Jetons.Espace.un)
            .frame(minWidth: Jetons.Taille.touche, minHeight: Jetons.Taille.touche)
            .background(forme.fill(Color.jeton(\.creux)))
            .overlay(forme.strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.Trait.filet))
            .fixedSize()
    }
}

// MARK: - Boutons

/// Les quatre rangs d'un bouton, à `controle` de haut, `Rayon.controle`, `corpsFort` : **principal** plein
/// (un par zone), **secondaire** bordé, **tertiaire** en `primaireEncre` sans bord, **destructif** plein
/// `dangerPlein`. Désactivé, un bouton plein redevient un secondaire grisé.
enum RangBouton { case principal, secondaire, tertiaire, destructif }

struct StyleBouton: ButtonStyle {
    let rang: RangBouton
    /// `cibleMin` au lieu de `controle` : les panneaux posés sur le jeu, où chaque point compte.
    var dense = false
    @Environment(\.isEnabled) private var actif

    func makeBody(configuration: Configuration) -> some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous)
        let presse = configuration.isPressed
        let plein = (rang == .principal || rang == .destructif) && actif
        let encre: Color = switch (rang, actif) {
        case (_, false): Color.jeton(\.encreTertiaire)
        case (.principal, _): Color.jeton(\.encreSurPrimaire)
        case (.destructif, _): Color.jeton(\.encreSurDanger)
        case (.tertiaire, _): Color.jeton(\.primaireEncre)
        case (.secondaire, _): Color.jeton(\.encre)
        }
        let fond: Color = switch (rang, actif) {
        case (.tertiaire, false): .clear
        case (_, false): Color.jeton(\.creux)
        case (.principal, _): presse ? Color.jeton(\.primaireEncre) : Color.jeton(\.primaire)
        case (.destructif, _): presse ? Color.jeton(\.danger) : Color.jeton(\.dangerPlein)
        case (.tertiaire, _): presse ? Color.jeton(\.pression) : .clear
        case (.secondaire, _): presse ? Color.jeton(\.pression) : Color.jeton(\.surface)
        }
        let borde = !plein && rang != .tertiaire
        configuration.label
            .font(Jetons.Typo.corpsFort.police)
            .foregroundStyle(encre)
            .padding(.horizontal, Jetons.Espace.trois)
            .frame(minHeight: dense ? Jetons.Taille.cibleMin : Jetons.Taille.controle)
            .background(forme.fill(fond))
            .overlay {
                if borde { forme.strokeBorder(Color.jeton(\.contourControle), lineWidth: Jetons.Trait.filet) }
            }
            .contentShape(forme)
            .animation(Jetons.Duree.animation(Jetons.Duree.pression), value: presse)
    }
}

extension ButtonStyle where Self == StyleBouton {
    static func bouton(_ rang: RangBouton, dense: Bool = false) -> StyleBouton { StyleBouton(rang: rang, dense: dense) }
}

/// Une tuile ou une puce cliquable : fond `creux` au repos, `survol`, `pression`, puis teinté si elle est
/// choisie, pleine si elle dit où l'on est. Désactivée, `encreTertiaire` sur `creux`.
struct StyleEtat: ButtonStyle {
    var choisi = false
    var courant = false
    var rayon = Jetons.Rayon.controle
    /// Une puce nue, sans tuile `creux` au repos.
    var nue = false

    func makeBody(configuration: Configuration) -> some View {
        Contenu(configuration: configuration, style: self)
    }

    private struct Contenu: View {
        let configuration: Configuration
        let style: StyleEtat
        @Environment(\.isEnabled) private var actif
        @Environment(\.groupeAuClavier) private var auClavier
        @State private var survole = false

        var body: some View {
            let etat: EtatVisuel = !actif ? .desactive : style.courant ? .courant : style.choisi ? .choix(auClavier: auClavier)
                : configuration.isPressed ? .presse : survole ? .survol : .repos
            configuration.label
                .foregroundStyle(etat.encre)
                .background {
                    if etat == .repos, !style.nue {
                        RoundedRectangle(cornerRadius: style.rayon, style: .continuous).fill(Color.jeton(\.creux))
                    }
                }
                // Une puce nue désactivée n'a pas de tuile : l'encre tertiaire suffit.
                .fondEtat(style.nue && etat == .desactive ? .repos : etat, rayon: style.rayon)
                .onHover { survole = $0 }
        }
    }
}

extension ButtonStyle where Self == StyleEtat {
    static func etat(choisi: Bool = false, courant: Bool = false, rayon: CGFloat = Jetons.Rayon.controle,
                     nue: Bool = false) -> StyleEtat {
        StyleEtat(choisi: choisi, courant: courant, rayon: rayon, nue: nue)
    }
}

extension View {
    /// Le texte d'un bouton sans texte : l'infobulle, et son nom pour VoiceOver,
    /// que `.help` ne donne pas.
    func aide(_ texte: String) -> some View { help(texte).accessibilityLabel(texte) }
}

// MARK: - Autorisation manquante

/// L'enregistrement de l'écran, qu'un panneau qui lit le jeu n'a pas : la même ligne partout, et le
/// même geste pour y remédier ; l'explication est son infobulle.
struct LigneAutorisation: View {
    var body: some View {
        HStack(spacing: Jetons.Espace.un) {
            Image(systemName: "lock").foregroundStyle(Color.jeton(\.encreSecondaire))
            Text(L("autorisation.lecture"))
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
                // Dans un panneau étroit, le libellé passe sur deux lignes avant que le geste ne se coupe.
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(L("autorisation.autoriser")) { WindowPreviewService.shared.requestAuthorization() }
                .buttonStyle(.bouton(.secondaire, dense: true))
                .fixedSize()
        }
        .help(L("autorisation.aide"))
    }
}

// MARK: - Retour de copie

/// « C'est dans le presse-papiers » : un seul signe, `IconeCopie`, pendant une seule durée, quelle que
/// soit la surface. Une surface porte un `SignalCopie` et dit quelle ligne vient d'être copiée ; une
/// nouvelle copie remplace la précédente sans que l'ancien délai ne l'efface.
@MainActor
final class SignalCopie: ObservableObject {
    /// `Jetons` est engendré et n'a pas de durée de ce genre : celle-ci est la seule de l'app.
    static let duree: Duration = .seconds(1.2)

    @Published private(set) var ligne: String?
    private let delai: Duration
    private var effacement: Task<Void, Never>?

    init(delai: Duration = SignalCopie.duree) { self.delai = delai }

    func signaler(_ ligne: String) {
        effacement?.cancel()
        self.ligne = ligne
        effacement = Task {
            try? await Task.sleep(for: delai)
            guard !Task.isCancelled else { return }
            self.ligne = nil
        }
    }

    func affiche(_ ligne: String) -> Bool { self.ligne == ligne }
}

/// L'icône d'une ligne copiable, qui devient une coche le temps du signal. Les deux se superposent :
/// la place est celle de l'icône, le texte ne bouge pas. Sans `icone`, la coche seule, dans une place
/// réservée.
struct IconeCopie: View {
    let icone: String?
    let copie: Bool

    var body: some View {
        ZStack {
            if let icone { Image(systemName: icone).opacity(copie ? 0 : 1) }
            Image(systemName: "checkmark")
                .foregroundStyle(Color.jeton(\.primaireEncre))
                .opacity(copie ? 1 : 0)
        }
    }
}

// MARK: - Segments

/// Le choix d'une valeur parmi quelques-unes, côte à côte : piste `creux` bordée d'un `filet`, le cran
/// choisi teinté (`primaireFond`, contour `primaire`, `primaireEncre`). Au clavier :
/// `groupeSelection`. Le seul segment de l'app.
struct Segments<Valeur: Hashable>: View {
    let titre: String
    let choix: [(valeur: Valeur, libelle: String)]
    @Binding var selection: Valeur

    init(_ titre: String, selection: Binding<Valeur>, choix: [(valeur: Valeur, libelle: String)]) {
        self.titre = titre
        self.choix = choix
        _selection = selection
    }

    var body: some View {
        let piste = RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous)
        HStack(spacing: Jetons.Trait.focusEcart) {
            ForEach(choix.indices, id: \.self) { rang in
                let valeur = choix[rang].valeur
                Button(choix[rang].libelle) { selection = valeur }
                    .buttonStyle(CranDeSegment(choisi: valeur == selection))
                    .elementDeGroupe()
                    .accessibilityAddTraits(valeur == selection ? .isSelected : [])
            }
        }
        .padding(Jetons.Trait.focusEcart)
        .background(piste.fill(Color.jeton(\.creux)))
        .overlay(piste.strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.Trait.filet))
        .fixedSize()
        .groupeSelection(titre, selection: $selection, parmi: choix.map(\.valeur))
    }
}

private struct CranDeSegment: ButtonStyle {
    let choisi: Bool

    func makeBody(configuration: Configuration) -> some View {
        Contenu(configuration: configuration, choisi: choisi)
    }

    private struct Contenu: View {
        let configuration: Configuration
        let choisi: Bool
        @Environment(\.groupeAuClavier) private var auClavier
        @State private var survole = false

        var body: some View {
            let etat: EtatVisuel = choisi ? .choix(auClavier: auClavier) : configuration.isPressed ? .presse : survole ? .survol : .repos
            configuration.label
                .font(Jetons.Typo.corps.police)
                .foregroundStyle(etat.encre)
                .padding(.horizontal, Jetons.Espace.trois)
                .frame(minHeight: Jetons.Taille.controle - 2 * Jetons.Trait.focusEcart)
                .fondEtat(etat, rayon: Jetons.Rayon.controle - Jetons.Trait.focusEcart)
                .onHover { survole = $0 }
        }
    }
}
