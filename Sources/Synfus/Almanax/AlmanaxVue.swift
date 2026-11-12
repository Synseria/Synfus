import SwiftUI

/// L'almanax du jour en tête de la palette : l'offrande, le nom à copier pour
/// l'hôtel de vente, le trajet jusqu'au Sanctuaire pour la rendre ; le chevron
/// déplie où la trouver — et le bonus du jour.
struct AlmanaxVue: View {
    let almanax: Almanax
    let copier: (String) -> Void
    /// Copie le trajet jusqu'au Sanctuaire ; `nil` si la carte ne le situe pas.
    let allerAuSanctuaire: (() -> Void)?
    @State private var deplie: Int?

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            ForEach(almanax.offrandes, id: \.objet) { offrande in
                ligne(offrande)
                if deplie == offrande.objet {
                    OuTrouverVue(sujet: .objet(offrande.objet), metriques: .confort)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, Jetons.Espace.dix)
                }
            }
            if let bonus = Lieu.traduit(almanax.bonus, langue) {
                let description = Lieu.traduit(almanax.description, langue)
                Text(description.map { L("palette.almanax.bonus", bonus, $0) } ?? bonus)
                    .font(Jetons.Typo.petit.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Jetons.Espace.dix)
            }
        }
        .padding(Jetons.Espace.deux)
        .background(RoundedRectangle(cornerRadius: Jetons.Rayon.controle, style: .continuous).fill(Color.jeton(\.safranFond)))
    }

    /// L'icône vient de DofusDB, à la demande ; sans visuels du jeu, le symbole.
    @ViewBuilder
    private func icone(_ offrande: Almanax.Offrande) -> some View {
        let symbole = Image(systemName: "calendar").foregroundStyle(Color.jeton(\.safranTexte))
        if let icone = offrande.icone {
            ImageDofusDB(url: DofusDB.imageObjet(icone)) { symbole }.aspectRatio(contentMode: .fit)
        } else {
            symbole
        }
    }

    private func ligne(_ offrande: Almanax.Offrande) -> some View {
        let nom = Lieu.traduit(offrande.noms, langue) ?? "?"
        return HStack(spacing: Jetons.Espace.deux) {
            icone(offrande).frame(width: Jetons.Taille.controle, height: Jetons.Taille.controle)
            HStack(spacing: Jetons.Espace.un) {
                Text(L("palette.almanax")).font(Jetons.Typo.raccourci.police).foregroundStyle(Color.jeton(\.safranTexte))
                Text(L("palette.almanax.offrande", offrande.quantite, nom)).font(Jetons.Typo.corpsFort.police)
                    .lineLimit(1)
            }
            Spacer(minLength: Jetons.Espace.un)
            Button { copier(nom) } label: {
                Label(L("palette.almanax.copier"), systemImage: "doc.on.clipboard").labelStyle(.iconOnly)
            }
            .buttonStyle(.bouton(.secondaire, dense: true))
            .aide(L("palette.almanax.copier"))
            if let allerAuSanctuaire {
                Button(action: allerAuSanctuaire) {
                    Label(L("palette.almanax.sanctuaire"), systemImage: "arrow.triangle.turn.up.right.diamond")
                }
                .buttonStyle(.bouton(.principal, dense: true))
                .aide(L("palette.almanax.sanctuaire.aide"))
            }
            Button { deplie = deplie == offrande.objet ? nil : offrande.objet } label: {
                Image(systemName: deplie == offrande.objet ? "chevron.down" : "chevron.right")
                    .font(Jetons.Typo.raccourci.police)
                    .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
            }
            .buttonStyle(.etat(nue: true))
            .aide(L("palette.touche.ouTrouver"))
        }
    }
}
