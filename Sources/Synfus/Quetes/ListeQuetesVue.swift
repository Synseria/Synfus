import SwiftUI
import SynseriaDesign

/// La liste des quêtes, à la place de la fiche (`MenuQuetes.liste`) : celles du
/// panneau — un clic montre, la croix retire —, puis celles qui commencent sur
/// la case du perso et celles du suivi du jeu, à ajouter d'un clic — leur
/// guide s'ouvre du livre au bout de la ligne.
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
    /// La section « Ici », en dernier, est repliée d'office.
    @State private var iciDeplie = false
    /// La quête dont le guide se cherche : son livre attend.
    @State private var guideEnCours: Int?

    /// La colonne des marques, à gauche des noms.
    private static let colonneMarque: CGFloat = 14

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metriques.ecartLignes) {
                if store.quetes == nil, store.chargement {
                    note(L("palette.quetes.chargement"))
                } else if store.quetes == nil, store.echec != nil {
                    note(L("quete.indisponible"))
                    geste(.reessayer)
                } else {
                    let elements = panneau.liste()
                    // « Ici » est la dernière section : repliée, seul son en-tête se montre.
                    let rangIci = elements.firstIndex { if case .iciEnTete = $0 { return true } else { return false } }
                    ForEach(Array(elements.enumerated()), id: \.offset) { rang, element in
                        if case .iciEnTete(let coordonnees, let nombre) = element {
                            boutonIci(coordonnees: coordonnees, nombre: nombre)
                        } else if let rangIci, rang > rangIci, !iciDeplie {
                            EmptyView()
                        } else {
                            ligne(element)
                        }
                    }
                }
            }
            .padding(metriques.marge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func ligne(_ element: MenuQuetes.Element) -> some View {
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
        case .chercher:
            quete(L("quete.chercher"), marque: "magnifyingglass", detail: nil) { QuetePanel.chercher() }
        case .ici(let id, let titre):
            HStack(spacing: 0) {
                quete(titre, marque: "exclamationmark.bubble", detail: nil) { panneau.ouvrir(id) }
                guide(id)
            }
        case .reconnue(let reconnue, let titre):
            HStack(spacing: 0) {
                quete(titre, marque: "plus", detail: nil) { lecture.choisir(reconnue) }
                guide(reconnue.id)
            }
        case .lireSuivi(let enCours):
            Button { lecture.lire() } label: {
                Label(enCours ? L("quete.suivi.enCours") : L("quete.suivi.lire"), systemImage: "text.viewfinder")
            }
            .disabled(enCours)
            .buttonStyle(BoutonTertiaire())
        case .message(let texte):
            note(texte)
        case .geste(let geste):
            self.geste(geste)
        // Le menu « ⋯ ».
        case .toutDesepingler, .option, .affichage, .fermer, .separateur, .iciEnTete:
            EmptyView()
        }
    }

    /// L'en-tête de la section « Ici », repliée d'office : un chevron, le titre,
    /// et le nombre de quêtes à épingler à droite de la ligne.
    private func boutonIci(coordonnees: String, nombre: Int) -> some View {
        Button { iciDeplie.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: Jetons.espace1) {
                Image(systemName: iciDeplie ? "chevron.down" : "chevron.right")
                    .font(metriques.icone.font)
                    .foregroundStyle(Color.jeton(\.encre2))
                    .frame(width: Jetons.espace4)
                Text(L("quete.menu.ici", coordonnees))
                    .font(metriques.detailFort.font)
                    .foregroundStyle(Color.jeton(\.encre2))
                Spacer(minLength: Jetons.espace1)
                if nombre > 0 {
                    Text("\(nombre)")
                        .font(metriques.detailFort.font)
                        .foregroundStyle(Color.jeton(\.texteSurAccent))
                        .padding(.horizontal, Jetons.espace1)
                        .background(Capsule().fill(Color.jeton(\.accent)))
                }
            }
            .padding(.horizontal, metriques.ligneHorizontale)
            .padding(.vertical, metriques.ligneVerticale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.etat(nue: true))
        .help(L("quete.ici.aide", nombre: nombre, nombre))
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

    /// Le livre au bout d'une quête à ajouter : son guide (`DofusPourLesNoobs`), sans l'épingler.
    private func guide(_ id: Int) -> some View {
        BoutonEnTete(icone: "book", aide: L("quete.guide"), discret: true) {
            guard let nom = store.fiche(id)?.nomFrancais, !nom.isEmpty else { return NSSound.beep() }
            guideEnCours = id
            Task {
                await DofusPourLesNoobs.ouvrir(nom)
                if guideEnCours == id { guideEnCours = nil }
            }
        }
        .disabled(guideEnCours == id)
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
