import SwiftUI
import SynseriaDesign

/// Les conseils de Dofus pour les noobs pour un combat : une phrase par
/// conseil, l'explication du site en infobulle ; la source est celle du titre
/// de leur section. Chaque conseil se copie d'un clic, comme les rappels du combat.
struct ConseilsVue: View {
    let conseils: [ConseilCombat]
    @StateObject private var copie = SignalCopie()

    var body: some View {
        ForEach(Array(conseils.enumerated()), id: \.offset) { _, conseil in
            Button {
                PressePapiers.copier(conseil.titre)
                copie.signaler(conseil.titre)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Jetons.espace1) {
                    // La puce à part : une ligne repliée s'aligne sous le texte, pas sous elle.
                    Text("•").font(Jetons.typoMeta.font)
                    Text(conseil.titre)
                        .font(Jetons.typoMeta.font)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    IconeCopie(icone: nil, copie: copie.affiche(conseil.titre))
                        .font(Jetons.typoMeta.font)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Jetons.espace1)
                .contentShape(Rectangle())
            }
            // Le survol éclaire la ligne : elle se clique, elle se copie.
            .buttonStyle(.etat(choisi: copie.affiche(conseil.titre), nue: true))
            .curseurDeClic(true)
            .help(conseil.detail.isEmpty ? L("boss.rappel.copier") : conseil.detail)
        }
    }
}
