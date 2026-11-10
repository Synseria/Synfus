import SwiftUI

/// La fiche d'un donjon, dépliée sous lui ou sous l'un de ses boss dans la
/// palette : niveau, puis deux rangées de cartes que le clavier parcourt
/// (`CartesFiche`) — entrée, guide, clefs ; monstres, succès — et entre elles
/// les boss à leur plus haut grade. Le détail se télécharge à l'ouverture ;
/// entrée et guide n'attendent pas.
struct FicheDonjonVue: View {
    let id: Int
    @ObservedObject var modele: PaletteModele
    @ObservedObject private var store = DonjonsStore.shared

    private var langue: Langue { L10n.courante.langue }

    /// L'identifiant d'une carte dans la liste : la palette y fait défiler.
    static func ancre(_ position: CartesFiche.Position) -> String {
        "fiche:\(position.rangee):\(position.colonne)"
    }

    var body: some View {
        if let donjon = store.donjons?.donjon(id: id) {
            let cartes = modele.cartes
            let detail = store.details[id]
            VStack(alignment: .leading, spacing: 8) {
                if let niveau = donjon.niveau {
                    Text(L("donjon.niveau", niveau)).font(.synfus(.petit, gras: true))
                }
                rangee(0, cartes, detail)
                if let detail {
                    ForEach(detail.monstres.filter(\.boss), id: \.id) { monstre in ligne(monstre) }
                } else {
                    attente(donjon)
                }
                rangee(1, cartes, detail)
            }
            .onAppear { store.demander(donjon) }
        }
    }

    @ViewBuilder
    private func attente(_ donjon: Donjon) -> some View {
        Group {
            if store.echecs.contains(id) {
                HStack(spacing: 6) {
                    Text(L("ouTrouver.echec"))
                    Button(L("ouTrouver.reessayer")) { store.demander(donjon) }.buttonStyle(.borderless)
                }
            } else {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text(L("ouTrouver.chargement"))
                }
            }
        }
        .font(.synfus(.petit))
        .foregroundStyle(.secondary)
    }

    /// Une rangée de cartes, puis ce que ses cartes ouvertes déplient.
    @ViewBuilder
    private func rangee(_ index: Int, _ cartes: CartesFiche, _ detail: DetailDonjon?) -> some View {
        if cartes.rangees.indices.contains(index), !cartes.rangees[index].isEmpty {
            let actions = cartes.rangees[index]
            HStack(spacing: 6) {
                ForEach(Array(actions.enumerated()), id: \.element) { colonne, action in
                    let position = CartesFiche.Position(rangee: index, colonne: colonne)
                    carte(action, detail, choisie: modele.carte == position)
                        .id(Self.ancre(position))
                        .onTapGesture { modele.cliquer(position) }
                }
            }
            ForEach(actions.filter { modele.ouvertes.contains($0) }, id: \.self) { action in
                ouverte(action, detail).padding(.leading, 12)
            }
        }
    }

    private func carte(_ action: ActionFiche, _ detail: DetailDonjon?, choisie: Bool) -> some View {
        CarteAction(icone: icone(action), titre: titre(action, detail), sousTitre: sousTitre(action),
                    ouverte: action.sePlie ? modele.ouvertes.contains(action) : nil, choisie: choisie)
            .help(aide(action) ?? "")
    }

    private func icone(_ action: ActionFiche) -> String {
        switch action {
        case .entree: return "arrow.triangle.turn.up.right.diamond"
        case .guide: return "book"
        case .clef: return "key"
        case .monstres: return "pawprint"
        case .succes: return "trophy"
        }
    }

    private func titre(_ action: ActionFiche, _ detail: DetailDonjon?) -> String {
        switch action {
        case .entree: return L("donjon.entree")
        case .guide: return L("donjon.guide")
        case .clef(let objet):
            let clef = detail?.clefs.first { $0.objet == objet }
            return L("donjon.clef", clef?.quantite ?? 1, clef.flatMap { Lieu.traduit($0.noms, langue) } ?? "?")
        case .monstres:
            let nombre = detail?.monstres.filter { !$0.boss }.count ?? 0
            return L("donjon.monstres", nombre: nombre, nombre)
        case .succes:
            let nombre = detail?.succes.count ?? 0
            return L("donjon.succes", nombre: nombre, nombre)
        }
    }

    /// Sous l'entrée, le trajet copié dit en clair : on sait avant ↵ par quel zaap on passe.
    private func sousTitre(_ action: ActionFiche) -> String? {
        guard case .entree(let lieu) = action else { return nil }
        return modele.versLieu(lieu).itineraire ?? Coordonnees.texte(lieu.x, lieu.y)
    }

    private func aide(_ action: ActionFiche) -> String? {
        switch action {
        case .entree(let lieu): return L("donjon.entree.aide", Coordonnees.texte(lieu.x, lieu.y))
        case .guide: return L("boss.guide")
        case .clef: return L("donjon.clef.aide")
        case .monstres, .succes: return nil
        }
    }

    @ViewBuilder
    private func ouverte(_ action: ActionFiche, _ detail: DetailDonjon?) -> some View {
        switch action {
        case .clef(let objet): OuTrouverVue(sujet: .objet(objet), metriques: .compact)
        case .monstres:
            ForEach(detail?.monstres.filter { !$0.boss } ?? [], id: \.id) { monstre in ligne(monstre) }
        case .succes:
            ForEach(Array((detail?.succes ?? []).enumerated()), id: \.offset) { _, succes in
                Text("• " + (Lieu.traduit(succes.noms, langue) ?? "?"))
                    .font(.synfus(.petit))
                    .help(Lieu.traduit(succes.description, langue) ?? "")
            }
        case .entree, .guide: EmptyView()
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
}

/// Une carte d'action de fiche : symbole, titre, une ligne de plus au besoin,
/// chevron quand elle déplie. Choisie au clavier, elle prend la teinte de la
/// ligne choisie.
private struct CarteAction: View {
    let icone: String
    let titre: String
    let sousTitre: String?
    /// `nil` : elle agit plutôt que de déplier.
    let ouverte: Bool?
    let choisie: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icone)
                .foregroundStyle(choisie ? Couleurs.accentTexte : Color.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(titre).lineLimit(1)
                if let sousTitre {
                    Text(sousTitre).foregroundStyle(Couleurs.accentTexte).lineLimit(1)
                }
            }
            if let ouverte {
                Image(systemName: ouverte ? "chevron.down" : "chevron.right")
                    .font(.synfus(.marque, gras: true))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.synfus(.petit))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(choisie ? Couleurs.accent.opacity(0.22) : Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(choisie ? Couleurs.accent : Color.primary.opacity(0.08)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(choisie ? [.isButton, .isSelected] : .isButton)
    }
}
