import SwiftUI

/// Les monstres d'un donjon en tableau, une ligne chacun : nom, niveau, vie, puis les cinq résistances
/// sous le signe de leur élément, celle à frapper sur le fond de sélection, celles à éviter effacées.
/// PA et PM, qui ne départagent rien, sont l'infobulle de la ligne ; les faiblesses se lisent en colonne.
struct TableauMonstresVue: View {
    let monstres: [DetailDonjon.Monstre]

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        Grid(alignment: .center, horizontalSpacing: Jetons.espace1, verticalSpacing: Jetons.espace1) {
            GridRow {
                Color.clear.frame(width: 0, height: 0)
                Text(L("combat.niveau")).foregroundStyle(Color.jeton(\.encre3))
                Color.clear.frame(width: 0, height: 0)
                ForEach(FicheCombat.Element.allCases, id: \.self) { element in
                    Image(systemName: element.symbole)
                        .resizable().scaledToFit()
                        .frame(width: Jetons.tailleIcone, height: Jetons.tailleIcone)
                        .foregroundStyle(element.teinte)
                        .help(FicheCombatVue.nom(element))
                }
            }
            ForEach(monstres, id: \.id) { ligne($0) }
        }
        .font(Jetons.typoMeta.font)
    }

    private func ligne(_ monstre: DetailDonjon.Monstre) -> some View {
        let fiche = monstre.fiche
        let points = L("combat.fiche.points", fiche.pa, fiche.pm)
        return GridRow {
            Text(Lieu.traduit(monstre.noms, langue) ?? "?")
                .foregroundStyle(Color.jeton(\.encre))
                .fixedSize()
                .gridColumnAlignment(.leading)
            Text("\(fiche.niveau)").monospacedDigit().foregroundStyle(Color.jeton(\.encre2))
            Text(L("combat.vie", fiche.vie.formatted())).monospacedDigit().foregroundStyle(Color.jeton(\.encre2))
                .gridColumnAlignment(.trailing)
            ForEach(FicheCombat.Element.allCases, id: \.self) { element in
                let role = fiche.role(element)
                let resistance = fiche.resistances[element] ?? 0
                Text(L("combat.fiche.pourcentage", resistance))
                    .monospacedDigit()
                    .foregroundStyle(role.encre)
                    .padding(.vertical, Jetons.espace1)
                    .padding(.horizontal, Jetons.espace2)
                    .background {
                        if role == .frapper { RoundedRectangle(cornerRadius: Jetons.rayon0).fill(Color.jeton(\.selection)) }
                    }
                    .opacity(role.opacite)
                    .help(L("combat.fiche.resistance", FicheCombatVue.nom(element), resistance))
            }
        }
        .help(points)
    }
}
