import SwiftUI
import SynseriaDesign

/// Dépliée sous une ressource ou un objectif du panneau des quêtes : où
/// trouver le monstre (ses repaires, le plus proche d'abord) ou l'objet (sa
/// recette, les monstres qui le lâchent et leurs repaires). Un clic sur un
/// repaire copie son trajet, zaap compris. En petit et en gris, comme le
/// détail des lignes : la fiche reste la quête.
struct OuTrouverVue: View {
    let sujet: OuTrouver.Sujet
    let metriques: MetriquesQuete
    /// Le nom de l'objet, quand l'appelant le sait : le titre de sa recette épinglée.
    var nom: String?
    /// Écrire ce nom en tête de la recette, copiable : là où rien d'autre ne le dit (la clef d'un donjon).
    var nommer = false
    @ObservedObject private var store = OuTrouverStore.shared
    /// La position du perso range les repaires.
    @ObservedObject private var lecteur = LecteurEcran.shared
    @StateObject private var copie = SignalCopie()
    @State private var tout = false

    /// Au-delà, « N de plus » : un objet commun a des dizaines de lâcheurs,
    /// un monstre commun des dizaines de sous-zones.
    private static let premiers = 4
    /// Les repaires d'un lâcheur : les plus proches seulement.
    private static let repairesParLacheur = 2

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            switch sujet {
            case .monstre(let id):
                if let fiche = store.monstre(id) { monstre(fiche) } else { attente }
            case .objet(let id):
                if let sources = store.objet(id) { objet(sources) } else { attente }
            }
        }
        .font(metriques.detail.font)
        .foregroundStyle(Color.jeton(\.encre2))
        .onAppear { store.demander(sujet) }
    }

    @ViewBuilder
    private var attente: some View {
        if store.echecs.contains(sujet) {
            HStack(spacing: Jetons.espace1) {
                Text(L("ouTrouver.echec"))
                Button(L("ouTrouver.reessayer")) { store.demander(sujet) }.buttonStyle(BoutonTertiaire())
            }
        } else {
            HStack(spacing: Jetons.espace1) {
                ProgressView().controlSize(.mini)
                Text(L("ouTrouver.chargement"))
            }
        }
    }

    // MARK: - Monstre

    @ViewBuilder
    private func monstre(_ fiche: FicheMonstre) -> some View {
        let repaires = store.repaires(fiche, depuis: lecteur.positionDuPersoDevant)
        if repaires.isEmpty { Text(L("ouTrouver.introuvable")) }
        ForEach(Array(repaires.prefix(tout ? .max : Self.premiers).enumerated()), id: \.offset) { _, repaire in
            ligne(repaire, cle: "m\(fiche.id)")
        }
        plus(repaires.count)
    }

    // MARK: - Objet

    @ViewBuilder
    private func objet(_ sources: SourcesObjet) -> some View {
        if let recette = sources.recette { self.recette(recette) }
        let position = lecteur.positionDuPersoDevant
        let lacheurs = OuTrouver.lacheurs(sources) { store.repaires($0, depuis: position) }
        ForEach(Array(lacheurs.prefix(tout ? .max : Self.premiers).enumerated()), id: \.offset) { _, element in
            lacheur(element.lacheur, element.repaires)
        }
        plus(lacheurs.count)
        if sources.recette == nil, lacheurs.isEmpty { Text(L("ouTrouver.rien")) }
    }

    /// La recette, et le bouton qui l'épingle à côté du jeu (`RecettePanel`) : ses ingrédients s'y
    /// copient d'un clic, le temps des courses.
    private func recette(_ recette: SourcesObjet.Recette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Jetons.espace1) {
                if nommer, let nom {
                    nomCopiable(nom)
                    Spacer(minLength: Jetons.espace1)
                }
                Label(L("ouTrouver.recette", Lieu.traduit(recette.metier, langue) ?? "?", recette.niveau), systemImage: "hammer")
                    .lineLimit(1)
                    .fixedSize()
                Button {
                    RecettePanel.shared.epingler(RecetteEpinglee(recette, objet: nom, langue: langue))
                } label: {
                    Label(L("recette.epingler"), systemImage: "pin")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(BoutonTertiaire())
                .focusable(false)
                // Le geste se dit au survol : le mot à côté de l'épingle n'apprenait rien.
                .aide(L("recette.epingler"))
            }
            ingredients(recette.ingredients)
                .padding(.leading, Jetons.espace4)
        }
        .padding(.bottom, Jetons.espace1)
    }

    /// Les ingrédients sur deux colonnes, la quantité d'abord ; un clic copie le nom, comme dans le panneau épinglé.
    private func ingredients(_ liste: [SourcesObjet.Ingredient]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Jetons.espace2, alignment: .topLeading), count: 2),
                  alignment: .leading, spacing: 0) {
            ForEach(Array(liste.enumerated()), id: \.offset) { rang, ingredient in
                let nom = Lieu.traduit(ingredient.noms, langue) ?? "?"
                let id = "i\(rang)"
                Button {
                    PressePapiers.copier(nom)
                    copie.signaler(id)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: Jetons.espace1) {
                        Text(L("recette.ingredient", ingredient.quantite, nom))
                            .foregroundStyle(Color.jeton(\.encre))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        IconeCopie(icone: nil, copie: copie.affiche(id)).accessibilityHidden(true)
                    }
                    .padding(.horizontal, Jetons.espace1)
                    .padding(.vertical, Jetons.espace1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.etat(nue: true))
                .aide(L("quete.copierNom"))
            }
        }
    }

    /// Le nom de l'objet, qu'on copie d'un clic pour le chercher à l'hôtel de vente.
    private func nomCopiable(_ nom: String) -> some View {
        Button {
            PressePapiers.copier(nom)
            copie.signaler("nom")
        } label: {
            HStack(spacing: Jetons.espace1) {
                IconeCopie(icone: "key", copie: copie.affiche("nom"))
                    .frame(width: Jetons.espace3)
                Text(nom)
                    .foregroundStyle(Color.jeton(\.encre))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Jetons.espace1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.etat(nue: true))
        .aide(L("quete.copierNom"))
    }

    /// Le monstre et son taux, puis ses repaires les plus proches.
    @ViewBuilder
    private func lacheur(_ lacheur: SourcesObjet.Lacheur, _ repaires: [RepaireSitue]) -> some View {
        HStack(spacing: Jetons.espace1) {
            Image(systemName: "pawprint").frame(width: Jetons.espace3)
            Text(Lieu.traduit(lacheur.monstre.noms, langue) ?? "?").foregroundStyle(Color.jeton(\.encre)).lineLimit(1)
            if lacheur.taux > 0 {
                Text((lacheur.taux / 100).formatted(.percent.precision(.fractionLength(0...2))
                    .locale(Locale(identifier: langue.rawValue))))
            }
            if repaires.isEmpty { Text(L("ouTrouver.introuvable")).foregroundStyle(Color.jeton(\.encre3)) }
        }
        .padding(.top, Jetons.espace1)
        ForEach(Array(repaires.prefix(Self.repairesParLacheur).enumerated()), id: \.offset) { _, repaire in
            ligne(repaire, cle: "o\(lacheur.monstre.id)").padding(.leading, Jetons.espace3)
        }
    }

    // MARK: - Lignes

    /// Un repaire : son nom, sa case et sa distance ; un clic copie le trajet.
    private func ligne(_ repaire: RepaireSitue, cle: String) -> some View {
        let id = "\(cle):\(repaire.repaire.genre.rawValue):\(repaire.repaire.id)"
        return Button {
            store.copierTrajet(repaire)
            copie.signaler(id)
        } label: {
            HStack(spacing: Jetons.espace1) {
                IconeCopie(icone: repaire.repaire.genre == .donjon ? "building.columns" : "mappin", copie: copie.affiche(id))
                    .frame(width: Jetons.espace3)
                Text(Lieu.traduit(repaire.repaire.noms, langue) ?? "?").lineLimit(1).layoutPriority(1)
                Spacer(minLength: Jetons.espace1)
                if let cartes = repaire.cartes { Text(L("ouTrouver.cartes", nombre: cartes, cartes)).lineLimit(1) }
                Text(Coordonnees.texte(repaire.situation.x, repaire.situation.y))
                    .font(Jetons.typoCode.font)
                    .lineLimit(1)
            }
            .padding(.vertical, Jetons.espace1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .curseurDeClic(true)
        .help(L("ouTrouver.copierTrajet"))
    }

    @ViewBuilder
    private func plus(_ nombre: Int) -> some View {
        if !tout, nombre > Self.premiers {
            let reste = nombre - Self.premiers
            Button(L("ouTrouver.plus", nombre: reste, reste)) { tout = true }
                .buttonStyle(BoutonTertiaire())
                .font(metriques.detail.font)
        }
    }
}
