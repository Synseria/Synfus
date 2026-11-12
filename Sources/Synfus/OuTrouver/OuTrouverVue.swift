import SwiftUI

/// Dépliée sous une ressource ou un objectif du panneau des quêtes : où
/// trouver le monstre (ses repaires, le plus proche d'abord) ou l'objet (sa
/// recette, les monstres qui le lâchent et leurs repaires). Un clic sur un
/// repaire copie son trajet, zaap compris. En petit et en gris, comme le
/// détail des lignes : la fiche reste la quête.
struct OuTrouverVue: View {
    let sujet: OuTrouver.Sujet
    let metriques: MetriquesQuete
    @ObservedObject private var store = OuTrouverStore.shared
    /// La position du perso range les repaires.
    @ObservedObject private var lecteur = LecteurEcran.shared
    @State private var copie: String?
    @State private var tout = false

    /// Au-delà, « N de plus » : un objet commun a des dizaines de lâcheurs,
    /// un monstre commun des dizaines de sous-zones.
    private static let premiers = 4
    /// Les repaires d'un lâcheur : les plus proches seulement.
    private static let repairesParLacheur = 2

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            switch sujet {
            case .monstre(let id):
                if let fiche = store.monstre(id) { monstre(fiche) } else { attente }
            case .objet(let id):
                if let sources = store.objet(id) { objet(sources) } else { attente }
            }
        }
        .font(.synfus(metriques.detail))
        .foregroundStyle(Couleurs.encreSecondaire)
        .onAppear { store.demander(sujet) }
    }

    @ViewBuilder
    private var attente: some View {
        if store.echecs.contains(sujet) {
            HStack(spacing: Jetons.Espace.un) {
                Text(L("ouTrouver.echec"))
                Button(L("ouTrouver.reessayer")) { store.demander(sujet) }.buttonStyle(.bouton(.tertiaire, dense: true))
            }
        } else {
            HStack(spacing: Jetons.Espace.un) {
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

    private func recette(_ recette: SourcesObjet.Recette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(L("ouTrouver.recette", Lieu.traduit(recette.metier, langue) ?? "?", recette.niveau), systemImage: "hammer")
            Text(recette.ingredients.map { L("quete.ressource", Lieu.traduit($0.noms, langue) ?? "?", $0.quantite) }
                .joined(separator: " · "))
                .foregroundStyle(Couleurs.encreTertiaire)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, Jetons.Espace.quatre)
        }
        .padding(.bottom, Jetons.Espace.un)
    }

    /// Le monstre et son taux, puis ses repaires les plus proches.
    @ViewBuilder
    private func lacheur(_ lacheur: SourcesObjet.Lacheur, _ repaires: [RepaireSitue]) -> some View {
        HStack(spacing: Jetons.Espace.un) {
            Image(systemName: "pawprint").frame(width: Jetons.Espace.trois)
            Text(Lieu.traduit(lacheur.monstre.noms, langue) ?? "?").foregroundStyle(Couleurs.encre).lineLimit(1)
            if lacheur.taux > 0 {
                Text((lacheur.taux / 100).formatted(.percent.precision(.fractionLength(0...2))
                    .locale(Locale(identifier: langue.rawValue))))
            }
            if repaires.isEmpty { Text(L("ouTrouver.introuvable")).foregroundStyle(Couleurs.encreTertiaire) }
        }
        .padding(.top, Jetons.Espace.un)
        ForEach(Array(repaires.prefix(Self.repairesParLacheur).enumerated()), id: \.offset) { _, repaire in
            ligne(repaire, cle: "o\(lacheur.monstre.id)").padding(.leading, Jetons.Espace.trois)
        }
    }

    // MARK: - Lignes

    /// Un repaire : son nom, sa case et sa distance ; un clic copie le trajet.
    private func ligne(_ repaire: RepaireSitue, cle: String) -> some View {
        let id = "\(cle):\(repaire.repaire.genre.rawValue):\(repaire.repaire.id)"
        return Button {
            store.copierTrajet(repaire)
            signaler(id)
        } label: {
            HStack(spacing: Jetons.Espace.un) {
                Image(systemName: repaire.repaire.genre == .donjon ? "building.columns" : "mappin").frame(width: Jetons.Espace.trois)
                Text(Lieu.traduit(repaire.repaire.noms, langue) ?? "?").lineLimit(1).layoutPriority(1)
                Spacer(minLength: Jetons.Espace.un)
                if copie == id {
                    Text(L("quete.copie")).font(.synfus(.raccourci)).foregroundStyle(Couleurs.primaireEncre)
                } else {
                    if let cartes = repaire.cartes { Text(L("ouTrouver.cartes", nombre: cartes, cartes)).lineLimit(1) }
                    Text(Coordonnees.texte(repaire.situation.x, repaire.situation.y))
                        .font(.synfus(.codeInterface))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, Jetons.Espace.un)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("ouTrouver.copierTrajet"))
    }

    @ViewBuilder
    private func plus(_ nombre: Int) -> some View {
        if !tout, nombre > Self.premiers {
            let reste = nombre - Self.premiers
            Button(L("ouTrouver.plus", nombre: reste, reste)) { tout = true }
                .buttonStyle(.bouton(.tertiaire, dense: true))
                .font(.synfus(metriques.detail))
        }
    }

    private func signaler(_ id: String) {
        copie = id
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if copie == id { copie = nil }
        }
    }
}
