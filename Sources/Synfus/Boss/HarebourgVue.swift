import SwiftUI

/// Contre le Comte Harebourg : où viser en gros, la grille qui le montre,
/// d'où vient la confusion, les coups au corps à corps, le choix à la main, et
/// ce que la parité du tour fait des téléportations.
struct HarebourgVue: View {
    @ObservedObject private var aide = AideBoss.shared
    @ObservedObject private var lecteur = LecteurEcran.shared
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        if let estimation = aide.estimation {
            visee(estimation)
            details(estimation)
        } else if previews.authorized {
            attente
        }
        aLaMain
        if let tour = aide.tour {
            Label(ToursCombat.estImpair(tour) ? L("boss.harebourg.impair") : L("boss.harebourg.pair"),
                  systemImage: ToursCombat.estImpair(tour) ? "shield" : "arrow.left.arrow.right")
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Où viser

    private func visee(_ estimation: SuiviConfusion.Estimation) -> some View {
        HStack(spacing: Jetons.Espace.deux) {
            SchemaVisee(confusion: estimation.confusion)
                .frame(width: 96, height: 48)
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                Text(Self.titre(estimation.confusion.visee))
                    .font(Jetons.Typo.titre.police)
                    .foregroundStyle(estimation.enTour ? Color.jeton(\.primaireEncre) : Color.jeton(\.encreSecondaire))
                Text(Self.libelle(estimation.confusion))
                    .font(Jetons.Typo.petit.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func details(_ estimation: SuiviConfusion.Estimation) -> some View {
        Label(source(estimation), systemImage: icone(estimation.source))
            .font(Jetons.Typo.petit.police)
            .foregroundStyle(Color.jeton(\.encreSecondaire))
            .fixedSize(horizontal: false, vertical: true)
        if let voisine = estimation.voisine {
            Label(L("boss.frontiere", Self.titre(voisine.visee)), systemImage: "exclamationmark.triangle")
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(Color.jeton(\.safranTexte))
                .fixedSize(horizontal: false, vertical: true)
        }
        if estimation.enTour, estimation.compteLesCoups {
            HStack(spacing: Jetons.Espace.un) {
                Text(L("boss.coups", nombre: estimation.coups, estimation.coups))
                    .font(Jetons.Typo.petit.police)
                    .help(L("boss.coups.aide"))
                Spacer()
                PetitBouton(icone: "minus", aide: L("boss.coups.moins")) { aide.coup(-1) }
                    .disabled(estimation.coups == 0)
                PetitBouton(icone: "plus", aide: L("boss.coups.plus")) { aide.coup(1) }
            }
        }
    }

    private func source(_ estimation: SuiviConfusion.Estimation) -> String {
        switch estimation.source {
        case .tchat: return L("boss.source.tchat")
        case .manuelle: return L("boss.source.manuelle")
        case .vie(let pourcentage):
            let arrondi = Int(pourcentage.rounded())
            return estimation.enTour ? L("boss.source.vie", arrondi) : L("boss.source.prevision", arrondi)
        }
    }

    private func icone(_ source: SuiviConfusion.Source) -> String {
        switch source {
        case .tchat: return "text.bubble"
        case .vie: return "heart"
        case .manuelle: return "hand.point.up.left"
        }
    }

    // MARK: - Sans estimation

    @ViewBuilder
    private var attente: some View {
        let enCombat = lecteur.persoDevant.flatMap { lecteur.combats[$0] }?.enCombat == true
        Group {
            if !enCombat {
                Text(L("boss.attente.combat"))
            } else if case .points(let actuels, nil)? = aide.vieLue {
                Text(L("boss.vie.sansMax", actuels))
            } else {
                Text(L("boss.rienLu"))
            }
        }
        .font(Jetons.Typo.petit.police)
        .foregroundStyle(Color.jeton(\.encreSecondaire))
        .fixedSize(horizontal: false, vertical: true)
        if enCombat, aide.vieLue == nil {
            Button(L("lecture.ouvrir")) { SettingsWindowController.shared.show(section: .lecture) }
                .buttonStyle(.bouton(.secondaire, dense: true))
        }
    }

    // MARK: - À la main

    /// La confusion lue à l'œil au canal combat, quand l'écran ne l'a pas
    /// lue ; un second clic rend la main aux lectures.
    private var aLaMain: some View {
        let choisie = aide.estimation.flatMap { $0.source == .manuelle && $0.coups == 0 ? $0.confusion : nil }
        return HStack(spacing: Jetons.Espace.un) {
            Text(L("boss.aLaMain")).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
            Spacer()
            ForEach([Harebourg.Confusion.aucune, .horaire, .demiTour, .contreHoraire], id: \.self) { confusion in
                let active = choisie == confusion
                Button { aide.choisir(active ? nil : confusion) } label: {
                    Image(systemName: Self.symbole(confusion))
                        .font(Jetons.Typo.raccourci.police)
                        .frame(width: Jetons.Taille.rangee, height: Jetons.Taille.cibleMin)
                }
                .buttonStyle(.etat(choisi: active))
                .aide(Self.libelle(confusion))
            }
        }
        .disabled(lecteur.persoDevant == nil)
    }

    // MARK: - Libellés

    static func titre(_ visee: Harebourg.Visee) -> String {
        switch visee {
        case .cible: return L("boss.visee.cible")
        case .gauche: return L("boss.visee.gauche")
        case .opposee: return L("boss.visee.opposee")
        case .droite: return L("boss.visee.droite")
        }
    }

    static func libelle(_ confusion: Harebourg.Confusion) -> String {
        switch confusion {
        case .horaire: return L("boss.confusion.horaire")
        case .demiTour: return L("boss.confusion.demiTour")
        case .contreHoraire: return L("boss.confusion.contreHoraire")
        default: return L("boss.confusion.aucune")
        }
    }

    private static func symbole(_ confusion: Harebourg.Confusion) -> String {
        switch confusion {
        case .horaire: return "arrow.clockwise"
        case .demiTour: return "arrow.up.arrow.down"
        case .contreHoraire: return "arrow.counterclockwise"
        default: return "scope"
        }
    }
}

/// La visée dessinée sur une grille du jeu : le lanceur au centre, la cible
/// devant lui à deux cases, et la case à viser pour qu'une fois tourné, le
/// sort retombe sur elle.
struct SchemaVisee: View {
    let confusion: Harebourg.Confusion

    private static let cible = (x: 0, y: -2)
    private static let rayon = 2

    var body: some View {
        Canvas { contexte, taille in
            // Une case en losange : demi-largeur a, demi-hauteur a/2, comme le jeu.
            let a = min(taille.width / CGFloat(4 * Self.rayon + 2), taille.height / CGFloat(2 * Self.rayon + 1))
            let centre = CGPoint(x: taille.width / 2, y: taille.height / 2)
            func point(_ x: Int, _ y: Int) -> CGPoint {
                CGPoint(x: centre.x + CGFloat(x - y) * a, y: centre.y + CGFloat(x + y) * a / 2)
            }
            func losange(_ x: Int, _ y: Int) -> Path {
                let p = point(x, y)
                var chemin = Path()
                chemin.move(to: CGPoint(x: p.x, y: p.y - a / 2))
                chemin.addLine(to: CGPoint(x: p.x + a, y: p.y))
                chemin.addLine(to: CGPoint(x: p.x, y: p.y + a / 2))
                chemin.addLine(to: CGPoint(x: p.x - a, y: p.y))
                chemin.closeSubpath()
                return chemin
            }
            for x in -Self.rayon...Self.rayon {
                for y in -Self.rayon...Self.rayon {
                    contexte.stroke(losange(x, y), with: .color(Color.jeton(\.filet)), lineWidth: Jetons.Trait.filet)
                }
            }
            let visee = confusion.caseVisee(cible: Self.cible)
            contexte.fill(losange(0, 0), with: .color(Color.jeton(\.encreSecondaire)))
            contexte.fill(losange(visee.x, visee.y), with: .color(Color.jeton(\.primaire)))
            contexte.stroke(losange(Self.cible.x, Self.cible.y), with: .color(Color.jeton(\.danger)), lineWidth: Jetons.Trait.etat)
            if visee != Self.cible {
                var trait = Path()
                trait.move(to: point(visee.x, visee.y))
                trait.addLine(to: point(Self.cible.x, Self.cible.y))
                contexte.stroke(trait, with: .color(Color.jeton(\.encreSecondaire)), style: StrokeStyle(lineWidth: Jetons.Trait.filet, dash: [Jetons.Trait.focus, Jetons.Trait.focus]))
            }
        }
        .accessibilityHidden(true)
    }
}
