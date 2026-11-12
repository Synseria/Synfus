import SwiftUI

/// L'almanax du jour en tête de la palette : l'offrande et ses deux temps —
/// le nom copié pour l'hôtel de vente, puis le trajet jusqu'au Sanctuaire pour
/// la rendre ; le chevron déplie où la trouver — et le bonus du jour.
struct AlmanaxVue: View {
    let almanax: Almanax
    let copier: (String) -> Void
    /// Copie le trajet jusqu'au Sanctuaire ; `nil` si la carte ne le situe pas.
    let allerAuSanctuaire: (() -> Void)?
    @State private var deplie: Int?

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(almanax.offrandes, id: \.objet) { offrande in
                ligne(offrande)
                if deplie == offrande.objet {
                    OuTrouverVue(sujet: .objet(offrande.objet), metriques: .confort)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 38)
                }
            }
            if let bonus = Lieu.traduit(almanax.bonus, langue) {
                let description = Lieu.traduit(almanax.description, langue)
                Text(description.map { L("palette.almanax.bonus", bonus, $0) } ?? bonus)
                    .font(.synfus(.petit))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 38)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Couleurs.safranFond))
    }

    /// L'icône vient de DofusDB, à la demande ; sans visuels du jeu, le symbole.
    @ViewBuilder
    private func icone(_ offrande: Almanax.Offrande) -> some View {
        let symbole = Image(systemName: "calendar").foregroundStyle(Couleurs.safranTexte)
        if let icone = offrande.icone {
            ImageDofusDB(url: DofusDB.imageObjet(icone)) { symbole }.aspectRatio(contentMode: .fit)
        } else {
            symbole
        }
    }

    private func ligne(_ offrande: Almanax.Offrande) -> some View {
        let nom = Lieu.traduit(offrande.noms, langue) ?? "?"
        return HStack(spacing: 10) {
            icone(offrande).frame(width: 28, height: 28)
            HStack(spacing: 6) {
                Text(L("palette.almanax")).font(.synfus(.petit, gras: true)).foregroundStyle(Couleurs.safranTexte)
                Text(L("palette.almanax.offrande", offrande.quantite, nom)).font(.synfus(.corpsFort))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button { copier(nom) } label: {
                Label(L("palette.almanax.nom"), systemImage: "doc.on.clipboard")
            }
            .controlSize(.small)
            .aide(L("palette.almanax.nom.aide"))
            if let allerAuSanctuaire {
                Button(action: allerAuSanctuaire) {
                    Label(L("palette.almanax.sanctuaire"), systemImage: "arrow.triangle.turn.up.right.diamond")
                }
                .controlSize(.small)
                .aide(L("palette.almanax.sanctuaire.aide"))
            }
            Button { deplie = deplie == offrande.objet ? nil : offrande.objet } label: {
                Image(systemName: deplie == offrande.objet ? "chevron.down" : "chevron.right")
                    .font(.synfus(.petit, gras: true))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .aide(L("palette.touche.ouTrouver"))
        }
    }
}
