import SwiftUI

/// La liste des quêtes, à la place de la fiche (`MenuQuetes.liste`) : celles du
/// panneau — un clic montre, la croix retire —, puis celles qui commencent sur
/// la case du perso et celles du suivi du jeu, à ajouter d'un clic.
struct ListeQuetesVue: View {
    let metriques: MetriquesQuete

    @ObservedObject private var panneau = QuetePanel.shared
    @ObservedObject private var store = QuetesStore.shared
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var lecture = LectureSuivi.shared
    // periphery:ignore - observé : la case du perso devant, dont dépend « Ici » (`QuetePanel.liste`)
    @ObservedObject private var lecteur = LecteurEcran.shared
    // periphery:ignore - observé : l'autorisation d'écran, dont dépend le suivi (`QuetePanel.liste`)
    @ObservedObject private var previews = WindowPreviewService.shared

    /// La colonne des marques, à gauche des noms.
    private static let colonneMarque: CGFloat = 14

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metriques.ecartLignes) {
                if store.quetes == nil, store.chargement {
                    note(L("palette.quetes.chargement"))
                } else if store.quetes == nil, store.echec != nil {
                    EtatVide(L("quete.indisponible"), symbole: "exclamationmark.circle", ton: .danger) {
                        Button { QuetePanel.faire(.reessayer) } label: { Label(L("commun.reessayer"), systemImage: "arrow.clockwise") }
                    }
                    .frame(height: Jetons.hauteurRangee * 4 + Jetons.espace4)
                } else {
                    let elements = panneau.liste()
                    if !elements.contains(where: \.estUneQuete) {
                        EtatVide(L("quete.aucune"), symbole: BoutonBarre.quetes.symbole) {
                            Button { QuetePanel.chercher() } label: { Label(L("quete.chercher"), systemImage: "magnifyingglass") }
                        }
                        .frame(height: Jetons.hauteurRangee * 4 + Jetons.espace4)
                    }
                    ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                        ligne(element, toutEpingler: elements.contains(.toutEpingler),
                              lecture: elements.contains { if case .lireSuivi = $0 { true } else { false } })
                    }
                }
            }
            .padding(metriques.marge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func ligne(_ element: MenuQuetes.Element, toutEpingler: Bool, lecture lisible: Bool) -> some View {
        switch element {
        case .titre(let titre):
            Text(titre)
                .font(metriques.detailFort.font)
                .foregroundStyle(Color.jeton(\.encre2))
                .padding(.top, metriques.ecartSections)
        case .epinglee(let id, let nom, let montree):
            HStack(spacing: 0) {
                quete(nom, marque: montree ? "circle.fill" : nil, detail: etape(id), forte: montree) { panneau.montrer(id) }
                BoutonEnTete(icone: "xmark", aide: L("quete.desepingler"), discret: true) { panneau.desepingler(id) }
            }
        case .ici(let id, let titre):
            quete(titre, marque: "exclamationmark.bubble", detail: nil) { panneau.ouvrir(id) }
        case .reconnue(let reconnue, let titre):
            quete(titre, marque: "plus", detail: nil) { lecture.choisir(reconnue) }
        case .lireSuivi(let enCours):
            HStack(spacing: Jetons.espace1) {
                Button { lecture.lire() } label: {
                    Label(enCours ? L("quete.suivi.enCours") : L("quete.suivi.lire"), systemImage: "text.viewfinder")
                }
                .disabled(enCours)
                Spacer(minLength: 0)
                if toutEpingler { Button(L("quete.toutEpingler")) { lecture.toutEpingler() } }
            }
            .buttonStyle(BoutonTertiaire())
        case .message(let texte):
            note(texte)
        case .geste(let geste):
            self.geste(geste)
        // Sur la ligne de « Lire le suivi » quand elle est là.
        case .toutEpingler:
            if !lisible {
                Button(L("quete.toutEpingler")) { lecture.toutEpingler() }.buttonStyle(BoutonTertiaire())
            }
        // Le menu « ⋯ ».
        case .toutDesepingler, .option, .affichage, .fermer, .separateur:
            EmptyView()
        }
    }

    /// Une quête : sa marque, son nom entier, son détail au bout.
    private func quete(_ nom: String, marque: String?, detail: String?, forte: Bool = false,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Jetons.espace1) {
                Image(systemName: marque ?? "circle")
                    .font(metriques.icone.font)
                    .foregroundStyle(forte ? Color.jeton(\.accent) : Color.jeton(\.encre2))
                    .opacity(marque == nil ? 0 : 1)
                    .frame(width: Self.colonneMarque)
                Text(nom)
                    .font((forte ? metriques.texteFort : metriques.texte).font)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Jetons.espace1)
                if let detail {
                    Text(detail)
                        .font(metriques.detail.font.monospacedDigit())
                        .foregroundStyle(Color.jeton(\.encre2))
                        .fixedSize()
                }
            }
            .padding(.horizontal, metriques.ligneHorizontale)
            .padding(.vertical, metriques.ligneVerticale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.etat(nue: true))
    }

    /// « ét. 3/19 » : où le panneau en est d'une quête à plusieurs étapes.
    private func etape(_ id: Int) -> String? {
        guard let etapes = store.fiche(id)?.etapes.count, etapes > 1 else { return nil }
        return L("quete.liste.etape", min(prefs.quetesEtape[String(id)] ?? 0, etapes - 1) + 1, etapes)
    }

    private func note(_ texte: String) -> some View {
        Text(texte)
            .font(metriques.detail.font)
            .foregroundStyle(Color.jeton(\.encre2))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, metriques.ligneHorizontale)
    }

    private func geste(_ geste: MenuQuetes.Geste) -> some View {
        Button(geste.titre) { QuetePanel.faire(geste) }
            .buttonStyle(BoutonBorde())
            .padding(.horizontal, metriques.ligneHorizontale)
    }
}

private extension MenuQuetes.Element {
    /// Une quête de la liste (du panneau, d'ici ou du suivi) : sans aucune, la liste est un état vide.
    var estUneQuete: Bool {
        switch self {
        case .epinglee, .ici, .reconnue: true
        default: false
        }
    }
}
