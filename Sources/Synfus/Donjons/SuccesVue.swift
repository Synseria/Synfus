import SwiftUI
import SynseriaDesign

/// Les succès d'un donjon : leur nom en encre pleine, ce qu'ils demandent en gris à côté, alignés d'un
/// succès à l'autre ; un clic copie la description pour la dire à l'équipe.
struct SuccesVue: View {
    let succes: [DetailDonjon.Succes]
    @StateObject private var copie = SignalCopie()
    /// La largeur du plus long nom : la colonne des descriptions commence au même endroit partout.
    @State private var largeurNom: CGFloat = 0

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(succes.enumerated()), id: \.offset) { rang, succes in
                ligne(rang, nom: Lieu.traduit(succes.noms, langue) ?? "?",
                      description: Lieu.traduit(succes.description, langue) ?? "")
            }
        }
        .onPreferenceChange(LargeurNom.self) { largeurNom = $0 }
    }

    private func ligne(_ rang: Int, nom: String, description: String) -> some View {
        Button {
            guard !description.isEmpty else { return }
            PressePapiers.copier(description)
            copie.signaler("\(rang)")
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Jetons.espace2) {
                Text(nom)
                    .foregroundStyle(Color.jeton(\.encre))
                    .fixedSize(horizontal: false, vertical: true)
                    // Le nom d'abord à sa largeur de texte : la mesure de la colonne.
                    .background(GeometryReader { Color.clear.preference(key: LargeurNom.self, value: $0.size.width) })
                    .frame(width: largeurNom > 0 ? largeurNom : nil, alignment: .leading)
                Text(description)
                    .foregroundStyle(Color.jeton(\.encre2))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                IconeCopie(icone: nil, copie: copie.affiche("\(rang)")).accessibilityHidden(true)
            }
            .font(Jetons.typoMeta.font)
            .padding(.horizontal, Jetons.espace1)
            .padding(.vertical, Jetons.espace1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.etat(choisi: copie.affiche("\(rang)"), nue: true))
        .help(description.isEmpty ? "" : L("boss.rappel.copier"))
    }
}

/// Le plus large des noms.
private struct LargeurNom: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
