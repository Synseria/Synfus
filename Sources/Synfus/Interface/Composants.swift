import SwiftUI

/// Les briques de dessin communes, écrites sur les jetons : voix d'état, cartes, surface qui flotte,
/// touche de raccourci, rangs de boutons. Une vue n'écrit ni couleur, ni rayon, ni durée.

// MARK: - Langage d'état

/// Les deux voix du design system et leurs états : le **plein** dit où je suis (un par zone), le
/// **teinté** dit ce que j'ai choisi. Sélectionné, survolé et pressé restent trois choses distinctes.
enum EtatVisuel: Equatable {
    case repos, survol, presse, choisi, courant, desactive

    /// Du survol d'une zone et de la pression d'un bouton à l'état d'un contrôle au repos.
    init(survole: Bool, presse: Bool = false) {
        self = presse ? .presse : survole ? .survol : .repos
    }

    @MainActor var fond: Color {
        switch self {
        case .repos: .clear
        case .survol: Couleurs.survol
        case .presse: Couleurs.pression
        case .choisi: Couleurs.primaireFond
        case .courant: Couleurs.primaire
        case .desactive: Couleurs.creux
        }
    }

    @MainActor var contour: Color? { self == .choisi ? Couleurs.primaire : nil }

    /// L'encre du contenu : un contenu à voix s'écrit en encres, jamais en blanc conditionnel.
    @MainActor var encre: Color {
        switch self {
        case .courant: Couleurs.encreSurPrimaire
        case .choisi: Couleurs.primaireEncre
        case .desactive: Couleurs.encreTertiaire
        case .repos, .survol, .presse: Couleurs.encre
        }
    }

    /// L'encre d'un contenu secondaire (libellé de second rang) dans le même état.
    @MainActor var encreSecondaire: Color {
        switch self {
        case .courant, .choisi, .desactive: encre
        case .repos, .survol, .presse: Couleurs.encreSecondaire
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
        return background(forme.fill(Couleurs.surface))
            .overlay(forme.strokeBorder(Couleurs.filet, lineWidth: Jetons.Trait.filet))
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
            content.background(forme.fill(Couleurs.surface))
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
            .font(.synfus(.raccourci))
            .foregroundStyle(Couleurs.encre)
            .padding(.horizontal, Jetons.Espace.un)
            .frame(minWidth: Jetons.Taille.touche, minHeight: Jetons.Taille.touche)
            .background(forme.fill(Couleurs.creux))
            .overlay(forme.strokeBorder(Couleurs.filet, lineWidth: Jetons.Trait.filet))
            .fixedSize()
    }
}

// MARK: - Boutons

/// Les trois rangs d'un bouton, à `controle` de haut, `Rayon.controle`, `corpsFort` : **principal** plein
/// (un par zone), **secondaire** bordé, **tertiaire** en `primaireEncre`. Désactivé, le principal redevient
/// un secondaire grisé.
enum RangBouton { case principal, secondaire, tertiaire, destructif }

struct StyleBouton: ButtonStyle {
    let rang: RangBouton
    /// `controleDense` au lieu de `controle` : les panneaux posés sur le jeu, où chaque point compte.
    var dense = false
    @Environment(\.isEnabled) private var actif

    func makeBody(configuration: Configuration) -> some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous)
        let presse = configuration.isPressed
        let plein = rang == .principal && actif
        let encre: Color = switch (rang, actif) {
        case (_, false): Couleurs.encreTertiaire
        case (.principal, _): Couleurs.encreSurPrimaire
        case (.tertiaire, _): Couleurs.primaireEncre
        case (.destructif, _): Couleurs.danger
        case (.secondaire, _): Couleurs.encre
        }
        let fond: Color = switch (rang, actif) {
        case (_, false): Couleurs.creux
        case (.principal, _): presse ? Couleurs.primaireEncre : Couleurs.primaire
        case (.tertiaire, _): presse ? Couleurs.pression : .clear
        case (.secondaire, _), (.destructif, _): presse ? Couleurs.pression : Couleurs.surface
        }
        let borde = !plein && rang != .tertiaire
        configuration.label
            .font(.synfus(.corpsFort))
            .foregroundStyle(encre)
            .padding(.horizontal, Jetons.Espace.trois)
            .frame(minHeight: dense ? Jetons.Taille.controleDense : Jetons.Taille.controle)
            .background(forme.fill(fond))
            .overlay {
                if borde {
                    forme.strokeBorder(actif && rang == .destructif ? Couleurs.danger : Couleurs.contourControle,
                                       lineWidth: Jetons.Trait.filet)
                }
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
        @State private var survole = false

        var body: some View {
            let etat: EtatVisuel = !actif ? .desactive : style.courant ? .courant : style.choisi ? .choisi
                : configuration.isPressed ? .presse : survole ? .survol : .repos
            configuration.label
                .foregroundStyle(etat.encre)
                .background {
                    if etat == .repos, !style.nue {
                        RoundedRectangle(cornerRadius: style.rayon, style: .continuous).fill(Couleurs.creux)
                    }
                }
                .fondEtat(etat, rayon: style.rayon)
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
