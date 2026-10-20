import SwiftUI

/// Le panneau d'aide contre le Comte Harebourg, au style des panneaux de
/// quêtes et de chasse : où viser en gros, la grille qui le montre, d'où
/// vient la confusion, les coups au corps à corps et le choix à la main.
struct BossVue: View {
    static let largeur: CGFloat = 252

    @ObservedObject private var aide = AideBoss.shared
    @ObservedObject private var lecteur = LecteurEcran.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @State private var rappels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if !previews.authorized {
                    autorisation
                } else if let estimation = aide.estimation {
                    visee(estimation)
                    details(estimation)
                } else {
                    attente
                }
                aLaMain
                rappelsVue
            }
            .padding(12)
        }
        .frame(width: Self.largeur, alignment: .leading)
        .font(.system(size: 12))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        // L'autorisation donnée, la lecture démarre sans attendre un
        // changement d'app.
        .onChange(of: previews.authorized) { BossPanel.shared.revoirVisibilite(force: false) }
    }

    private var entete: some View {
        EnTetePanneau(icone: "scope", teinte: Couleurs.ambre) {
            Text(L("boss.harebourg")).font(.system(size: 12, weight: .semibold))
                .padding(.leading, 6)
            if let perso = lecteur.persoDevant {
                Text(perso).font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
        } boutons: {
            BoutonEnTete(icone: "minus", aide: L("quete.fermer.simple")) { BossPanel.shared.fermer() }
        }
    }

    // MARK: - Où viser

    private func visee(_ estimation: SuiviConfusion.Estimation) -> some View {
        HStack(spacing: 10) {
            SchemaVisee(confusion: estimation.confusion)
                .frame(width: 96, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.titre(estimation.confusion.visee))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(estimation.enTour ? Couleurs.accent : Color.secondary)
                Text(Self.libelle(estimation.confusion))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func details(_ estimation: SuiviConfusion.Estimation) -> some View {
        Label(source(estimation), systemImage: icone(estimation.source))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        if let voisine = estimation.voisine {
            Label(L("boss.frontiere", Self.titre(voisine.visee)), systemImage: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(Couleurs.ambre)
                .fixedSize(horizontal: false, vertical: true)
        }
        if estimation.enTour, estimation.compteLesCoups {
            HStack(spacing: 6) {
                Text(L("boss.coups", nombre: estimation.coups, estimation.coups))
                    .font(.system(size: 11))
                    .help(L("boss.coups.aide"))
                Spacer()
                petitBouton("minus", aide: L("boss.coups.moins")) { aide.coup(-1) }
                    .disabled(estimation.coups == 0)
                petitBouton("plus", aide: L("boss.coups.plus")) { aide.coup(1) }
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
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var autorisation: some View {
        HStack(spacing: 8) {
            Text(L("boss.autoriser.aide"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { previews.requestAuthorization() } label: { Image(systemName: "lock") }
                .buttonStyle(.borderless)
                .help(L("boss.autoriser"))
        }
    }

    // MARK: - À la main

    /// La confusion lue à l'œil au canal combat, quand l'écran ne l'a pas
    /// lue ; un second clic rend la main aux lectures.
    private var aLaMain: some View {
        let choisie = aide.estimation.flatMap { $0.source == .manuelle && $0.coups == 0 ? $0.confusion : nil }
        return HStack(spacing: 4) {
            Text(L("boss.aLaMain")).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            ForEach([Harebourg.Confusion.aucune, .horaire, .demiTour, .contreHoraire], id: \.self) { confusion in
                let active = choisie == confusion
                Button { aide.choisir(active ? nil : confusion) } label: {
                    Image(systemName: Self.symbole(confusion))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 22)
                        .foregroundStyle(active ? Color.white : Color.primary)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(active ? Couleurs.accent : Color.primary.opacity(0.08)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Self.libelle(confusion))
            }
        }
        .disabled(lecteur.persoDevant == nil)
    }

    private func petitBouton(_ icone: String, aide: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icone)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 22, height: 20)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(aide)
    }

    // MARK: - Rappels

    private var rappelsVue: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { rappels.toggle() } label: {
                Label(L("boss.rappels"), systemImage: rappels ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if rappels {
                ForEach([L("boss.rappel.carillon"), L("boss.rappel.impair"), L("boss.rappel.pair"), L("boss.rappel.echec")],
                        id: \.self) {
                    Text("• " + $0)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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
                    contexte.stroke(losange(x, y), with: .color(.primary.opacity(0.18)), lineWidth: 0.5)
                }
            }
            let visee = confusion.caseVisee(cible: Self.cible)
            contexte.fill(losange(0, 0), with: .color(.primary.opacity(0.55)))
            contexte.fill(losange(visee.x, visee.y), with: .color(Couleurs.accent))
            contexte.stroke(losange(Self.cible.x, Self.cible.y), with: .color(.red), lineWidth: 1.5)
            if visee != Self.cible {
                var trait = Path()
                trait.move(to: point(visee.x, visee.y))
                trait.addLine(to: point(Self.cible.x, Self.cible.y))
                contexte.stroke(trait, with: .color(.secondary), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .accessibilityHidden(true)
    }
}
