import SwiftUI

/// L'almanax du jour en tête de la palette : l'offrande — un clic copie le
/// nom de l'objet, pour l'hôtel de vente ; le chevron déplie où le trouver —
/// et le bonus du jour.
struct AlmanaxVue: View {
    let almanax: Almanax
    let copier: (String) -> Void
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
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Couleurs.ambre.opacity(0.12)))
    }

    /// L'icône vient de DofusDB, à la demande ; sans visuels du jeu, le symbole.
    @ViewBuilder
    private func icone(_ offrande: Almanax.Offrande) -> some View {
        let symbole = Image(systemName: "calendar").foregroundStyle(Couleurs.ambre)
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
            Button { copier(nom) } label: {
                HStack(spacing: 6) {
                    Text(L("palette.almanax")).font(.synfus(.petit, gras: true)).foregroundStyle(Couleurs.ambre)
                    Text(L("palette.almanax.offrande", offrande.quantite, nom)).font(.synfus(.corps, gras: true))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("quete.copierNom"))
            Spacer(minLength: 4)
            Button { deplie = deplie == offrande.objet ? nil : offrande.objet } label: {
                Image(systemName: deplie == offrande.objet ? "chevron.down" : "chevron.right")
                    .font(.synfus(.petit, gras: true))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L("palette.touche.ouTrouver"))
        }
    }
}
