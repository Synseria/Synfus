import SwiftUI

/// Une page dont le gros est une longue liste (zaaps, lieux, quêtes, PNJ). Un
/// `Form` construit toutes ses lignes à l'ouverture, visibles ou non — 600 ms
/// pour 300 lieux et leurs boutons — ; une pile paresseuse ne construit que ce
/// qui paraît. Les sections y ressemblent à celles d'un formulaire groupé :
/// chaque ligne, enfant direct de la pile pour rester paresseuse, porte sa
/// part du cadre (`cadreDeListe`).
struct PageListe<Contenu: View>: View {
    let titre: String
    var valeur: String?
    @ViewBuilder let contenu: Contenu

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EnTetePage(titre: titre, valeur: valeur)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) { contenu }
                    .labeledContentStyle(StyleLigneListe())
                    .buttonStyle(.bouton(.secondaire))
                    .padding(.horizontal, MargeReglages.texte - MargeReglages.ligne)
                    .padding(.top, Jetons.Espace.deux)
                    .padding(.bottom, Jetons.Espace.quatre)
            }
        }
    }
}

/// `Ligne` hors d'un `Form` : libellé à gauche, contrôle à droite, comme dans
/// les autres onglets.
private struct StyleLigneListe: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Jetons.Espace.trois) {
            configuration.label
            Spacer(minLength: Jetons.Espace.deux)
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
            .font(.synfus(.corpsFort))
            .padding(.horizontal, MargeReglages.ligne)
            .padding(.top, Jetons.Espace.quatre)
            .padding(.bottom, Jetons.Espace.un)
    }
}

extension View {
    /// Une ligne d'une section de `PageListe` : le cadre s'arrondit en haut de
    /// la première, en bas de la dernière ; un filet sépare les autres.
    func cadreDeListe(premiere: Bool, derniere: Bool) -> some View {
        let rayon = Jetons.Rayon.carte
        let forme = UnevenRoundedRectangle(
            topLeadingRadius: premiere ? rayon : 0, bottomLeadingRadius: derniere ? rayon : 0,
            bottomTrailingRadius: derniere ? rayon : 0, topTrailingRadius: premiere ? rayon : 0,
            style: .continuous)
        return padding(.horizontal, MargeReglages.ligne)
            .padding(.vertical, Jetons.Espace.deux)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(forme.fill(Couleurs.surface))
            // Le filet de chaque ligne recouvre celui de la précédente : un seul trait entre deux.
            .overlay(forme.strokeBorder(Couleurs.filet, lineWidth: Jetons.Trait.filet)
                .padding(.top, premiere ? 0 : -Jetons.Trait.filet))
    }
}
