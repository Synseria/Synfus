import SwiftUI

/// La fiche d'un donjon, dépliée sous lui ou sous l'un de ses boss dans la
/// palette : des onglets (`OngletsFiche`) — boss, conseils, monstres, succès,
/// chaque clef — dont un seul se montre, que ←/→ changent. Le détail et les
/// conseils se téléchargent à l'ouverture ; l'onglet des boss dit l'attente.
struct FicheDonjonVue: View {
    let id: Int
    @ObservedObject var modele: PaletteModele
    @ObservedObject private var store = DonjonsStore.shared

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        if let donjon = store.donjons?.donjon(id: id) {
            let detail = store.details[id]
            let onglets = modele.fiche.onglets
            VStack(alignment: .leading, spacing: Jetons.espace2) {
                if !onglets.isEmpty {
                    SegmenteIcones(titre: L("donjon.onglets"),
                                   options: onglets.map { option($0, detail) },
                                   selection: modele.ongletCourant) { modele.choisir(onglet: $0) }
                        // Un peu d'air sous la ligne : collé, le sélecteur se lisait comme sa suite.
                        .padding(.top, Jetons.espace1)
                }
                contenu(modele.ongletCourant, donjon, detail)
            }
            .onAppear { store.demander(donjon) }
        }
    }

    private func option(_ onglet: OngletFiche, _ detail: DetailDonjon?) -> SegmenteIcones<OngletFiche>.Option {
        switch onglet {
        case .boss: return .init(valeur: onglet, titre: L("donjon.boss"), symbole: "crown")
        case .conseils: return .init(valeur: onglet, titre: L("donjon.conseils"), symbole: "lightbulb", aide: L("donjon.conseils.aide"))
        case .monstres:
            let nombre = detail?.monstres.filter { !$0.boss }.count ?? 0
            return .init(valeur: onglet, titre: L("donjon.monstres", nombre: nombre, nombre), symbole: "pawprint")
        case .succes:
            let nombre = detail?.succes.count ?? 0
            return .init(valeur: onglet, titre: L("donjon.succes", nombre: nombre, nombre), symbole: "trophy")
        case .clef(let objet):
            // Plusieurs clefs : numérotées, leur nom en infobulle — un nom de clef ne tient pas dans un cran.
            let rang = (detail?.clefs.firstIndex { $0.objet == objet } ?? 0) + 1
            let clef = detail?.clefs.first { $0.objet == objet }
            return .init(valeur: onglet, titre: (detail?.clefs.count ?? 0) > 1 ? L("donjon.clef.numero", rang) : L("donjon.clef"), symbole: "key",
                         aide: L("donjon.clef.aide", clef?.quantite ?? 1, clef.flatMap { Lieu.traduit($0.noms, langue) } ?? "?"))
        }
    }

    @ViewBuilder
    private func contenu(_ onglet: OngletFiche?, _ donjon: Donjon, _ detail: DetailDonjon?) -> some View {
        switch onglet {
        case .boss:
            if let detail {
                ForEach(detail.monstres.filter(\.boss), id: \.id) { monstre in ligne(monstre) }
            } else {
                attente(donjon)
            }
        case .conseils:
            ConseilsVue(conseils: store.conseils[id] ?? [])
        case .monstres:
            TableauMonstresVue(monstres: detail?.monstres.filter { !$0.boss } ?? [])
        case .succes:
            SuccesVue(succes: detail?.succes ?? [])
        case .clef(let objet):
            OuTrouverVue(sujet: .objet(objet), metriques: .compact,
                         nom: detail?.clefs.first { $0.objet == objet }.flatMap { Lieu.traduit($0.noms, langue) },
                         nommer: true)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func attente(_ donjon: Donjon) -> some View {
        Group {
            if store.echecs.contains(id) {
                HStack(spacing: Jetons.espace1) {
                    Text(L("ouTrouver.echec"))
                    Button(L("ouTrouver.reessayer")) { store.demander(donjon) }.buttonStyle(BoutonTertiaire())
                }
            } else {
                HStack(spacing: Jetons.espace1) {
                    ProgressView().controlSize(.mini)
                    Text(L("ouTrouver.chargement"))
                }
            }
        }
        .font(Jetons.typoMeta.font)
        .foregroundStyle(Color.jeton(\.encre2))
    }

    private func ligne(_ monstre: DetailDonjon.Monstre) -> some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            HStack(spacing: Jetons.espace1) {
                Image(systemName: "crown").foregroundStyle(Color.jeton(\.accentTexte))
                Text(Lieu.traduit(monstre.noms, langue) ?? "?").font(Jetons.typoMicro.font)
            }
            FicheCombatVue(fiche: monstre.fiche)
        }
    }
}

/// Les actions de la fiche d'un donjon, en boutons-icônes sur sa ligne dépliée : la position (ce que ↵
/// fait), l'aide au combat — un menu quand le donjon a plusieurs boss —, le guide.
struct ActionsFicheDonjon: View {
    @ObservedObject var modele: PaletteModele
    /// Le nom des boss arrive avec la liste des donjons.
    @ObservedObject private var store = DonjonsStore.shared

    var body: some View {
        let actions = modele.fiche.actions
        let aides = actions.compactMap { action -> CibleBoss? in if case .aide(let boss) = action { boss } else { nil } }
        HStack(spacing: 0) {
            ForEach(actions.filter { if case .entree = $0 { true } else { false } }, id: \.self, content: bouton)
            if aides.count > 1 {
                MenuIcone(titre: L("donjon.aide"), symbole: BoutonBarre.boss.symbole) {
                    ForEach(aides, id: \.self) { boss in
                        Button(BossVue.nom(boss, donjons: store.donjons, garde: nil)) { modele.cliquer(.aide(boss)) }
                    }
                }
                .focusable(false)
            } else {
                ForEach(aides, id: \.self) { bouton(.aide($0)) }
            }
            ForEach(actions.filter { if case .guide = $0 { true } else { false } }, id: \.self, content: bouton)
        }
    }

    private func bouton(_ action: ActionFiche) -> some View {
        let (titre, symbole): (String, String) = switch action {
        case .entree: (L("donjon.entree"), "arrow.triangle.turn.up.right.diamond")
        case .aide: (L("donjon.aide"), BoutonBarre.boss.symbole)
        case .guide: (L("donjon.guide"), "book")
        }
        return Button { modele.cliquer(action) } label: { Label(titre, systemImage: symbole) }
            .buttonStyle(BoutonIcone())
            .focusable(false)
            .aide(titre)
    }
}
