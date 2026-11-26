import SwiftUI
import SynseriaDesign

/// Contre le Comte Harebourg : où viser en gros, la grille qui le montre,
/// d'où vient la confusion, les coups au corps à corps, le choix à la main, et
/// ce que la parité du tour fait des téléportations.
struct HarebourgVue: View {
    @ObservedObject private var aide = AideBoss.shared
    @ObservedObject private var lecteur = LecteurEcran.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @State private var regleDepliee = false
    // periphery:ignore - lu par son `$` (le dépliable), que Periphery ne voit pas
    @State private var attenteDepliee = false
    /// La cible du schéma, déplaçable au doigt pour éprouver une autre case que celle d'en face.
    @State private var cibleSchema = (x: 0, y: -2)
    private static let hauteurSchema: CGFloat = 48

    /// Les contrôles gardent leur place d'un tour à l'autre : la réponse au-dessus a
    /// toujours la hauteur de la grille, les lignes passagères viennent dessous.
    var body: some View {
        // Sans lecture possible, rien à réserver : pas de blanc au-dessus des contrôles.
        if previews.authorized || aide.estimation != nil {
            reponse.frame(minHeight: Self.hauteurSchema, alignment: .leading)
        }
        coups
        aLaMain
        if let estimation = aide.estimation { details(estimation) }
        if aide.estimation == nil, previews.authorized { attenteLecture }
        if let tour = aide.tour {
            regleDuTour(impair: ToursCombat.estImpair(tour))
        } else {
            LigneDuTour {}
        }
    }

    /// La réponse du tour en deux mots, le tour à côté, la règle entière dépliée d'un clic.
    private func regleDuTour(impair: Bool) -> some View {
        SectionBoss(titre: impair ? L("boss.harebourg.impair.court") : L("boss.harebourg.pair.court"),
                    icone: impair ? "shield" : "arrow.left.arrow.right", forte: true, depliee: $regleDepliee) {
            CorrectionTour()
        } contenu: {
            TexteDeDetail(texte: impair ? L("boss.harebourg.impair") : L("boss.harebourg.pair"))
        }
    }

    // MARK: - Où viser

    private func visee(_ estimation: SuiviConfusion.Estimation) -> some View {
        HStack(spacing: Jetons.espace2) {
            SchemaVisee(confusion: estimation.confusion, cible: $cibleSchema)
                .frame(width: 96, height: Self.hauteurSchema)
                .help(L("boss.schema.aide"))
            VStack(alignment: .leading, spacing: Jetons.espace1) {
                Text(Self.titre(estimation.confusion.visee))
                    .font(Jetons.typoSection.font)
                    .foregroundStyle(estimation.enTour ? Color.jeton(\.accentTexte) : Color.jeton(\.encre2))
                Text(Self.libelle(estimation.confusion))
                    .font(Jetons.typoMeta.font)
                    .foregroundStyle(Color.jeton(\.encre2))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func details(_ estimation: SuiviConfusion.Estimation) -> some View {
        // D'où vient la réponse change d'un tour à l'autre et dit ce qu'elle vaut : une ligne, pas une
        // infobulle, que macOS ne montre pas sur un panneau d'une app inactive.
        Label(source(estimation), systemImage: icone(estimation.source))
            .font(Jetons.typoMeta.font)
            .foregroundStyle(Color.jeton(\.encre2))
            .fixedSize(horizontal: false, vertical: true)
        if let voisine = estimation.voisine {
            Label(L("boss.frontiere", Self.titre(voisine.visee)), systemImage: "exclamationmark.triangle")
                .font(Jetons.typoMeta.font)
                .foregroundStyle(Color.jeton(\.avertissement))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Toujours là, grisé quand les coups ne se comptent pas (hors du tour, ou
    /// déjà annoncés au canal combat).
    private var coups: some View {
        let estimation = aide.estimation
        let actif = estimation.map { $0.enTour && $0.compteLesCoups } ?? false
        let nombre = estimation?.coups ?? 0
        return HStack(spacing: Jetons.espace1) {
            Text(L("boss.coups", nombre: nombre, nombre))
                .font(Jetons.typoMeta.font)
                .foregroundStyle(actif ? Color.jeton(\.encre) : Color.jeton(\.encre3))
                .help(L("boss.coups.aide"))
            Spacer()
            PetitBouton(icone: "minus", aide: L("boss.coups.moins")) { aide.coup(-1) }
                .disabled(!actif || nombre == 0)
            PetitBouton(icone: "plus", aide: L("boss.coups.plus")) { aide.coup(1) }
                .disabled(!actif)
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

    /// Ce que la grille dit : où viser, ou pourquoi elle ne le dit pas encore.
    @ViewBuilder
    private var reponse: some View {
        if let estimation = aide.estimation {
            visee(estimation)
        } else if previews.authorized {
            let enCombat = lecteur.persoDevant.flatMap { lecteur.combats[$0] }?.enCombat == true
            Group {
                if !enCombat {
                    SectionBoss(titre: L("boss.attente.court"), icone: "scope", depliee: $attenteDepliee) {
                        EmptyView()
                    } contenu: {
                        TexteDeDetail(texte: L("boss.attente.combat"))
                    }
                } else if case .points(let actuels, nil)? = aide.vieLue {
                    Text(L("boss.vie.sansMax", actuels))
                } else {
                    Text(L("boss.rienLu"))
                }
            }
            .font(Jetons.typoMeta.font)
            .foregroundStyle(Color.jeton(\.encre2))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Sous les contrôles : l'accès au calibrage, quand le combat n'a rien rendu.
    @ViewBuilder
    private var attenteLecture: some View {
        if lecteur.persoDevant.flatMap({ lecteur.combats[$0] })?.enCombat == true, aide.vieLue == nil {
            Button(L("lecture.ouvrir")) { SettingsWindowController.shared.show(onglet: .propre(.lecture)) }
                .buttonStyle(BoutonBorde())
        }
    }

    // MARK: - À la main

    /// La confusion lue à l'œil au canal combat, quand l'écran ne l'a pas
    /// lue ; un second clic rend la main aux lectures.
    private var aLaMain: some View {
        let choisie = aide.estimation.flatMap { $0.source == .manuelle && $0.coups == 0 ? $0.confusion : nil }
        return VStack(alignment: .leading, spacing: Jetons.espace1) {
            Text(L("boss.aLaMain")).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.encre2))
            ChoixBoss(choix: [(Harebourg.Confusion.aucune, "0°"), (.horaire, "90° ↻"), (.demiTour, "180°"), (.contreHoraire, "90° ↺")],
                      actuel: choisie) { aide.choisir($0) }
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
}

/// La visée dessinée sur une grille du jeu : le lanceur au centre, la cible
/// au bord rouge — **déplaçable au doigt** pour éprouver une autre case —, et
/// la case à viser en accent pour qu'une fois tourné, le sort retombe sur elle.
struct SchemaVisee: View {
    let confusion: Harebourg.Confusion
    @Binding var cible: (x: Int, y: Int)

    private static let rayon = 2

    var body: some View {
        GeometryReader { geo in
            let taille = geo.size
            Canvas { contexte, _ in
                Self.dessiner(contexte, taille: taille, cible: cible, confusion: confusion)
            }
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { geste in cible = Self.cellule(de: geste.location, taille: taille) }
                .onEnded { geste in cible = Self.cellule(de: geste.location, taille: taille) })
            .curseurDeClic(true)
        }
        .accessibilityHidden(true)
    }

    /// La géométrie de la grille : une case en losange de demi-largeur `a`,
    /// demi-hauteur `a/2`, comme le jeu.
    private static func geometrie(_ taille: CGSize) -> (a: CGFloat, centre: CGPoint) {
        let a = min(taille.width / CGFloat(4 * Self.rayon + 2), taille.height / CGFloat(2 * Self.rayon + 1))
        return (a, CGPoint(x: taille.width / 2, y: taille.height / 2))
    }

    private static func losange(_ x: Int, _ y: Int, a: CGFloat, centre: CGPoint) -> Path {
        Path { $0.addLines(GrilleIso.losange(x, y, a: a, centre: centre)); $0.closeSubpath() }
    }

    /// La case sous un point de la grille, bornée au rayon dessiné.
    private static func cellule(de localisation: CGPoint, taille: CGSize) -> (x: Int, y: Int) {
        let (a, centre) = Self.geometrie(taille)
        let (x, y) = GrilleIso.caseSous(localisation, a: a, centre: centre)
        return (max(-Self.rayon, min(Self.rayon, x)), max(-Self.rayon, min(Self.rayon, y)))
    }

    private static func dessiner(_ contexte: GraphicsContext, taille: CGSize,
                                cible: (x: Int, y: Int), confusion: Harebourg.Confusion) {
        let (a, centre) = Self.geometrie(taille)
        for x in -Self.rayon...Self.rayon {
            for y in -Self.rayon...Self.rayon {
                contexte.stroke(Self.losange(x, y, a: a, centre: centre),
                                with: .color(Color.jeton(\.filet)), lineWidth: Jetons.epaisseurFilet)
            }
        }
        let visee = confusion.caseVisee(cible: cible)
        contexte.fill(Self.losange(0, 0, a: a, centre: centre), with: .color(Color.jeton(\.encre2)))
        contexte.fill(Self.losange(visee.x, visee.y, a: a, centre: centre), with: .color(Color.jeton(\.accent)))
        contexte.stroke(Self.losange(cible.x, cible.y, a: a, centre: centre),
                        with: .color(Color.jeton(\.danger)), lineWidth: Jetons.epaisseurFocus)
        if visee != cible {
            var trait = Path()
            trait.move(to: GrilleIso.projeter(visee.x, visee.y, a: a, centre: centre))
            trait.addLine(to: GrilleIso.projeter(cible.x, cible.y, a: a, centre: centre))
            contexte.stroke(trait, with: .color(Color.jeton(\.encre2)),
                            style: StrokeStyle(lineWidth: Jetons.epaisseurFilet, dash: [Jetons.epaisseurFocus, Jetons.epaisseurFocus]))
        }
    }
}
