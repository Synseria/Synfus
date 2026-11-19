// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json c5f3400ce23232ce · contenu 11ce5392a68b609b
import SwiftUI

// Ce que la trousse affiche sans qu'on le règle : touche, badge, alerte, infobulle, activité.

// MARK: - La touche

/// Une touche de clavier (`.key`) : la fenêtre, un filet, `rayon-0`, en micro de `police-code`, de
/// `diametre-rond` au moins ; sur un bouton plein, un voile de son texte, le filet transparent (il
/// compte dans la largeur).
struct ToucheDeClavier: View {
    let touche: String
    /// Posée sur un bouton plein (principal, destructif) : elle prend la couleur de son texte.
    var surUnPlein = false
    /// Une combinaison que le système refuse : en couleur d'attention, barrée.
    var refusee = false
    @Environment(\.couleursSynseria) private var c

    private static let typo = Jetons.Typo(graisse: Jetons.typoMicro.graisse, taille: Jetons.typoMicro.taille,
                                          interligne: Jetons.typoMicro.interligne, police: .code)

    var body: some View {
        if surUnPlein {
            Text(touche)
                .font(Self.typo.font)
                .padding(.horizontal, Jetons.espace1 + Jetons.epaisseurFilet)
                .frame(minWidth: Jetons.diametreRond, minHeight: Jetons.diametreRond)
                .background(.foreground.opacity(Jetons.voileTouche), in: .rect(cornerRadius: Jetons.rayon0, style: .circular))
        } else {
            Text(touche)
                .font(Self.typo.font)
                .strikethrough(refusee, color: c.avertissement.couleur)
                .foregroundStyle((refusee ? c.avertissement : c.encre2).couleur)
                .padding(.horizontal, Jetons.espace1 + Jetons.epaisseurFilet)
                .frame(minWidth: Jetons.diametreRond, minHeight: Jetons.diametreRond)
                .background(c.fondFenetre.couleur, in: .rect(cornerRadius: Jetons.rayon0, style: .circular))
                .overlay { RoundedRectangle(cornerRadius: Jetons.rayon0, style: .circular).strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
        }
    }
}

struct RoueDActivite: View {
    @Environment(\.couleursSynseria) private var c
    /// Le trait de `.spin` et son voile.
    private static let trait: CGFloat = 2
    private static let voile = 0.14

    var body: some View {
        TimelineView(.animation) { contexte in
            let tour = contexte.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Jetons.dureeTour) / Jetons.dureeTour
            ZStack {
                Circle().strokeBorder(c.encre.voile(Self.voile).couleur, lineWidth: Self.trait)
                Circle().inset(by: Self.trait / 2).trim(from: 0, to: 0.25)
                    .stroke(c.accent.couleur, lineWidth: Self.trait)
                    .rotationEffect(.degrees(tour * 360 - 90))
            }
            .frame(width: Jetons.diametreRond, height: Jetons.diametreRond)
        }
    }
}

// MARK: - Badge, alerte, infobulle

/// La couleur qui teinte un badge ou une alerte (`.ton-*`).
enum Ton: Hashable, Sendable {
    case neutre, accent, danger, succes, avertissement, info

    func rvb(_ c: Jetons.Couleurs) -> Jetons.RVB {
        switch self {
        case .neutre: c.encre2
        case .accent: c.accent
        case .danger: c.danger
        case .succes: c.succes
        case .avertissement: c.avertissement
        case .info: c.info
        }
    }
}

/// Un badge (`.bdg`) : une pilule de `hauteur-case` en micro, teintée de son ton ; un point devant,
/// une croix pour le retirer, au besoin.
struct Badge: View {
    let texte: String
    var ton: Ton = .neutre
    var point = false
    /// Le badge se retire (une étiquette posée) ; son libellé d'accessibilité.
    var retirer: (titre: String, action: () -> Void)?
    @Environment(\.couleursSynseria) private var c

    /// `.bdg` : le fond à 14 %, le filet à 28 %, le texte à 70 % du ton dans l'encre.
    private static let (partFond, partFilet, partTexte) = (0.14, 0.28, 0.7)

    var body: some View {
        let ton = ton.rvb(c)
        HStack(spacing: Jetons.espace1) {
            if point { Circle().fill(ton.couleur).frame(width: Jetons.espace2, height: Jetons.espace2) }
            Text(texte).lineLimit(1).fixedSize()
            if let retirer {
                Button(action: retirer.action) {
                    Image(systemName: "xmark").font(.system(size: Jetons.diametreMini * 0.6, weight: .bold))
                        .frame(width: Jetons.diametreMini, height: Jetons.diametreMini)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .curseurDeClic(true)
                .accessibilityLabel(retirer.titre)
            }
        }
        .font(Jetons.typoMicro.font)
        .foregroundStyle(Jetons.Octets.melange(Jetons.Octets(c.encre.hex), Jetons.Octets(ton.hex), Self.partTexte).rvb.couleur)
        .padding(.horizontal, Jetons.espace2 + Jetons.epaisseurFilet)
        .frame(height: Jetons.hauteurCase)
        .background(ton.voile(Self.partFond).couleur, in: .capsule)
        .overlay { Capsule().strokeBorder(ton.voile(Self.partFilet).couleur, lineWidth: Jetons.epaisseurFilet) }
    }
}

/// Une alerte (`.al`) : le symbole du ton, un titre, une ligne de détail au besoin, un geste
/// tertiaire au bout. Le détail dit le fait, jamais un mode d'emploi.
struct Alerte: View {
    let ton: Ton
    let symbole: String
    let titre: String
    var detail: String?
    var geste: (titre: String, action: () -> Void)?
    @Environment(\.couleursSynseria) private var c

    /// `.al` : le fond à 12 % du ton dans la plaque, le filet à 35 %.
    private static let (partFond, partFilet) = (0.12, 0.35)

    var body: some View {
        let ton = ton.rvb(c)
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
        HStack(alignment: .top, spacing: Jetons.espace3) {
            Image(systemName: symbole)
                .font(.system(size: Jetons.tailleIcone))
                .foregroundStyle(ton.couleur)
                .frame(width: Jetons.tailleIcone, height: Jetons.typoTitreCarte.interligne)
            VStack(alignment: .leading, spacing: 0) {
                Text(titre).font(Jetons.typoTitreCarte.font).foregroundStyle(c.encre.couleur)
                if let detail { Text(detail).font(Jetons.typoMeta.font).foregroundStyle(c.encre2.couleur) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let geste { Button(geste.titre, action: geste.action).buttonStyle(BoutonTertiaire()) }
        }
        .padding(Jetons.espace3)
        .background(Jetons.Octets.melange(Jetons.Octets(c.plaque.hex), Jetons.Octets(ton.hex), Self.partFond).rvb.couleur, in: forme)
        .overlay { forme.strokeBorder(ton.voile(Self.partFilet).couleur, lineWidth: Jetons.epaisseurFilet) }
    }
}

/// Une infobulle dessinée (`.tip`) : l'encre en fond, la fenêtre en texte, ses touches au bout, sa
/// pointe dessous. L'aide d'un contrôle passe par `.help` ; celle-ci sert là où il faut la montrer
/// (une capture, un premier pas).
struct Infobulle: View {
    let texte: String
    var touches: [String] = []
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        HStack(spacing: Jetons.espace2) {
            Text(texte)
            if !touches.isEmpty {
                HStack(spacing: Jetons.espace1) {
                    ForEach(Array(touches.enumerated()), id: \.offset) { _, touche in
                        Text(touche)
                            .font(Jetons.Typo(graisse: Jetons.typoMicro.graisse, taille: Jetons.typoMicro.taille,
                                              interligne: Jetons.typoMicro.interligne, police: .code).font)
                            .padding(.horizontal, Jetons.espace1)
                            .frame(minWidth: Jetons.diametreRond, minHeight: Jetons.diametreRond)
                            .overlay {
                                RoundedRectangle(cornerRadius: Jetons.rayon0, style: .circular)
                                    .strokeBorder(c.fondFenetre.voile(0.4).couleur, lineWidth: Jetons.epaisseurFilet)
                            }
                    }
                }
            }
        }
        .font(Jetons.typoMeta.font)
        .foregroundStyle(c.fondFenetre.couleur)
        .padding(.vertical, Jetons.espace1)
        .padding(.horizontal, Jetons.espace2)
        .background(c.encre.couleur, in: .rect(cornerRadius: Jetons.rayon1, style: .circular))
        .overlay(alignment: .bottom) {
            Rectangle().fill(c.encre.couleur)
                .frame(width: Jetons.espace2, height: Jetons.espace2)
                .rotationEffect(.degrees(45))
                .offset(y: Jetons.espace1)
        }
    }
}
