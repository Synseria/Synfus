import SwiftUI

/// Une page dont le gros est une longue liste (zaaps, lieux, quêtes, PNJ). Un
/// `Form` construit toutes ses lignes à l'ouverture, visibles ou non — 600 ms
/// pour 300 lieux et leurs boutons — ; une pile paresseuse ne construit que ce
/// qui paraît. Les sections y ressemblent à celles d'un formulaire groupé :
/// chaque ligne, enfant direct de la pile pour rester paresseuse, porte sa
/// part du cadre (`cadreDeListe`).
struct PageListe<Contenu: View>: View {
    let titre: String
    let sousTitre: String
    @ViewBuilder let contenu: Contenu

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EnTetePage(titre: titre, sousTitre: sousTitre)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) { contenu }
                    .labeledContentStyle(StyleLigneListe())
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
        }
    }
}

/// `Ligne` hors d'un `Form` : libellé à gauche, contrôle à droite, comme dans
/// les autres onglets.
private struct StyleLigneListe: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 8)
            configuration.content
        }
    }
}

/// Le titre d'une section de `PageListe`, au-dessus de son cadre.
struct EnTeteListe: View {
    let titre: String
    var aide: String?

    var body: some View {
        SectionTitle(titre, help: aide)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}

extension View {
    /// Une ligne d'une section de `PageListe` : le cadre s'arrondit en haut de
    /// la première, en bas de la dernière ; un filet sépare les autres.
    func cadreDeListe(premiere: Bool, derniere: Bool) -> some View {
        let rayon: CGFloat = 8
        return padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UnevenRoundedRectangle(
                topLeadingRadius: premiere ? rayon : 0, bottomLeadingRadius: derniere ? rayon : 0,
                bottomTrailingRadius: derniere ? rayon : 0, topTrailingRadius: premiere ? rayon : 0,
                style: .continuous)
                .fill(Color.primary.opacity(0.045)))
            .overlay(alignment: .top) {
                if !premiere { Divider().padding(.horizontal, 10) }
            }
    }
}
