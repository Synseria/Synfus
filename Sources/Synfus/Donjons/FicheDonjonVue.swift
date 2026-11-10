import SwiftUI

/// La fiche d'un donjon, dépliée sous lui ou sous l'un de ses boss dans la
/// palette : niveau, trajet jusqu'à l'entrée, guide, clef (où la trouver),
/// boss et monstres à leur plus haut grade, succès. Le détail se télécharge à
/// l'ouverture ; trajet et guide n'attendent pas.
struct FicheDonjonVue: View {
    let id: Int
    let copierTrajet: (Lieu) -> Void
    @ObservedObject private var store = DonjonsStore.shared
    @State private var clefDepliee: Int?
    @State private var monstres = false
    @State private var succes = false

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        if let donjon = store.donjons?.donjon(id: id) {
            VStack(alignment: .leading, spacing: 6) {
                entete(donjon)
                if let detail = store.details[id] {
                    contenu(detail)
                } else if store.echecs.contains(id) {
                    HStack(spacing: 6) {
                        Text(L("ouTrouver.echec"))
                        Button(L("ouTrouver.reessayer")) { store.demander(donjon) }.buttonStyle(.borderless)
                    }
                    .font(.synfus(.petit))
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text(L("ouTrouver.chargement"))
                    }
                    .font(.synfus(.petit))
                    .foregroundStyle(.secondary)
                }
            }
            .onAppear { store.demander(donjon) }
        }
    }

    /// Le repère de l'entrée sur la carte : par sa carte, sinon par son nom.
    private func entree(_ donjon: Donjon) -> Lieu? {
        let reperes = CarteStore.shared.reperes
        return donjon.entree.flatMap(reperes.donjon(carte:)) ?? donjon.nomFrancais.flatMap(reperes.donjon(nom:))
    }

    private func entete(_ donjon: Donjon) -> some View {
        HStack(spacing: 8) {
            if let niveau = donjon.niveau {
                Text(L("donjon.niveau", niveau)).font(.synfus(.petit, gras: true))
            }
            Spacer(minLength: 4)
            if let lieu = entree(donjon) {
                Button { copierTrajet(lieu) } label: {
                    Label(L("donjon.entree"), systemImage: "arrow.triangle.turn.up.right.diamond")
                }
                .controlSize(.small)
                .aide(L("donjon.entree.aide", Coordonnees.texte(lieu.x, lieu.y)))
            }
            if let nom = donjon.nomFrancais {
                Button { Task { await DofusPourLesNoobs.ouvrir(nom) } } label: {
                    Label(L("donjon.guide"), systemImage: "book")
                }
                .controlSize(.small)
                .aide(L("boss.guide"))
            }
        }
    }

    @ViewBuilder
    private func contenu(_ detail: DetailDonjon) -> some View {
        ForEach(detail.clefs, id: \.objet) { clef in
            Button { clefDepliee = clefDepliee == clef.objet ? nil : clef.objet } label: {
                HStack(spacing: 4) {
                    Image(systemName: "key").foregroundStyle(Couleurs.ambre)
                    Text(L("donjon.clef", clef.quantite, Lieu.traduit(clef.noms, langue) ?? "?"))
                    Image(systemName: clefDepliee == clef.objet ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .font(.synfus(.petit))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .aide(L("palette.touche.ouTrouver"))
            if clefDepliee == clef.objet {
                OuTrouverVue(sujet: .objet(clef.objet), metriques: .compact).padding(.leading, 18)
            }
        }
        ForEach(detail.monstres.filter(\.boss), id: \.id) { monstre in ligne(monstre) }
        let autres = detail.monstres.filter { !$0.boss }
        if !autres.isEmpty {
            depliable(L("donjon.monstres", nombre: autres.count, autres.count), ouvert: $monstres)
            if monstres { ForEach(autres, id: \.id) { monstre in ligne(monstre) } }
        }
        if !detail.succes.isEmpty {
            depliable(L("donjon.succes", nombre: detail.succes.count, detail.succes.count), ouvert: $succes)
            if succes {
                ForEach(Array(detail.succes.enumerated()), id: \.offset) { _, succes in
                    Text("• " + (Lieu.traduit(succes.noms, langue) ?? "?"))
                        .font(.synfus(.petit))
                        .help(Lieu.traduit(succes.description, langue) ?? "")
                }
            }
        }
    }

    private func ligne(_ monstre: DetailDonjon.Monstre) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if monstre.boss { Image(systemName: "crown").foregroundStyle(Couleurs.ambre) }
                Text(Lieu.traduit(monstre.noms, langue) ?? "?").font(.synfus(.petit, gras: monstre.boss))
            }
            FicheCombatVue(fiche: monstre.fiche)
        }
    }

    private func depliable(_ titre: String, ouvert: Binding<Bool>) -> some View {
        Button { ouvert.wrappedValue.toggle() } label: {
            Label(titre, systemImage: ouvert.wrappedValue ? "chevron.down" : "chevron.right")
                .font(.synfus(.petit, gras: true))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
