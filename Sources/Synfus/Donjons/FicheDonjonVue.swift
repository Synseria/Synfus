import SwiftUI

/// La fiche d'un donjon, dépliée sous lui ou sous l'un de ses boss dans la
/// palette : niveau, une rangée de cartes que le clavier parcourt
/// (`CartesFiche`) — entrée, guide, clefs, conseils, monstres, succès —, ce
/// qu'elles déplient, puis les boss à leur plus haut grade. Le détail et les
/// conseils se téléchargent à l'ouverture ; entrée et guide n'attendent pas.
struct FicheDonjonVue: View {
    let id: Int
    @ObservedObject var modele: PaletteModele
    @ObservedObject private var store = DonjonsStore.shared

    private var langue: Langue { L10n.courante.langue }

    /// L'identifiant d'une carte dans la liste : la palette y fait défiler.
    static func ancre(_ action: ActionFiche) -> String { "fiche:\(action)" }

    var body: some View {
        if let donjon = store.donjons?.donjon(id: id) {
            let detail = store.details[id]
            let actions = modele.cartes.actions
            VStack(alignment: .leading, spacing: 8) {
                if let niveau = donjon.niveau {
                    Text(L("donjon.niveau", niveau)).font(.synfus(.petit, gras: true))
                }
                RangeeSouple(espacement: 6) {
                    ForEach(actions, id: \.self) { action in
                        carte(action, detail)
                            .id(Self.ancre(action))
                            .onTapGesture { modele.cliquer(action) }
                    }
                }
                ForEach(actions.filter { modele.ouvertes.contains($0) }, id: \.self) { action in
                    ouverte(action, detail).padding(.leading, 12)
                }
                if let detail {
                    ForEach(detail.monstres.filter(\.boss), id: \.id) { monstre in ligne(monstre) }
                } else {
                    attente(donjon)
                }
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

    private func carte(_ action: ActionFiche, _ detail: DetailDonjon?) -> some View {
        CarteAction(icone: icone(action), titre: titre(action, detail), sousTitre: sousTitre(action),
                    ouverte: action.sePlie ? modele.ouvertes.contains(action) : nil, choisie: modele.carte == action)
            .help(aide(action) ?? "")
    }

    private func icone(_ action: ActionFiche) -> String {
        switch action {
        case .entree: return "arrow.triangle.turn.up.right.diamond"
        case .guide: return "book"
        case .clef: return "key"
        case .conseils: return "lightbulb"
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
        case .conseils:
            let nombre = store.conseils[id]?.count ?? 0
            return L("donjon.conseils", nombre: nombre, nombre)
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
        case .conseils: return L("donjon.conseils.aide")
        case .monstres, .succes: return nil
        }
    }

    @ViewBuilder
    private func ouverte(_ action: ActionFiche, _ detail: DetailDonjon?) -> some View {
        switch action {
        case .clef(let objet): OuTrouverVue(sujet: .objet(objet), metriques: .compact)
        case .conseils: conseils
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

    /// Une phrase par conseil ; l'explication du site en infobulle.
    private var conseils: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array((store.conseils[id] ?? []).enumerated()), id: \.offset) { _, conseil in
                Text("• " + conseil.titre)
                    .font(.synfus(.petit))
                    .fixedSize(horizontal: false, vertical: true)
                    .help(conseil.detail)
            }
            Text(L("donjon.conseils.source"))
                .font(.synfus(.petit))
                .foregroundStyle(.tertiary)
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
/// chevron quand elle déplie. Choisie au clavier, elle prend la teinte pleine
/// de la ligne choisie ; ouverte, seulement un lisere et un titre teintés.
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
                .foregroundStyle(choisie || ouverte == true ? Couleurs.accentTexte : Color.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(titre)
                    .foregroundStyle(ouverte == true && !choisie ? Couleurs.accentTexte : Color.primary)
                    .lineLimit(1)
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
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fond))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(lisere, lineWidth: choisie ? 1.5 : 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(choisie ? [.isButton, .isSelected] : .isButton)
    }

    private var fond: Color {
        if choisie { return Couleurs.accent.opacity(0.22) }
        return ouverte == true ? .clear : Color.primary.opacity(0.06)
    }

    private var lisere: Color {
        if choisie { return Couleurs.accent }
        return ouverte == true ? Couleurs.accent.opacity(0.45) : Color.primary.opacity(0.08)
    }
}

/// Des cartes à la suite, renvoyées à la ligne quand la place manque, toutes
/// à la hauteur de la plus haute.
private struct RangeeSouple: Layout {
    let espacement: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let positions = disposer(largeur: proposal.width ?? .infinity, subviews)
        let largeur = positions.map { $0.origine.x + $0.taille.width }.max() ?? 0
        let hauteur = positions.map { $0.origine.y + $0.taille.height }.max() ?? 0
        return CGSize(width: proposal.width ?? largeur, height: hauteur)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for (sousVue, position) in zip(subviews, disposer(largeur: bounds.width, subviews)) {
            sousVue.place(at: CGPoint(x: bounds.minX + position.origine.x, y: bounds.minY + position.origine.y),
                          proposal: ProposedViewSize(position.taille))
        }
    }

    private func disposer(largeur: CGFloat, _ subviews: Subviews) -> [(origine: CGPoint, taille: CGSize)] {
        let tailles = subviews.map { $0.sizeThatFits(.unspecified) }
        let hauteur = tailles.map(\.height).max() ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        return tailles.map { taille in
            if x > 0, x + taille.width > largeur {
                x = 0
                y += hauteur + espacement
            }
            defer { x += min(taille.width, largeur) + espacement }
            return (CGPoint(x: x, y: y), CGSize(width: min(taille.width, largeur), height: hauteur))
        }
    }
}
