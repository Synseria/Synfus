import SwiftUI

/// Les conseils de Dofus pour les noobs pour un combat : une phrase par
/// conseil, l'explication du site en infobulle, la source pour finir. Chaque
/// conseil se copie d'un clic, comme les rappels du combat.
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
                    Text("• " + conseil.titre)
                        .font(Jetons.typoMeta.font)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    IconeCopie(icone: nil, copie: copie.affiche(conseil.titre))
                        .font(Jetons.typoMeta.font)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .curseurDeClic(true)
            .help(conseil.detail.isEmpty ? L("boss.rappel.copier") : conseil.detail)
        }
        Text(L("donjon.conseils.source"))
            .font(Jetons.typoMeta.font)
            .foregroundStyle(Color.jeton(\.encre3))
    }
}
