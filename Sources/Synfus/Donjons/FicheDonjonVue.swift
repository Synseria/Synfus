import SwiftUI

/// La fiche d'un donjon, dépliée sous lui ou sous l'un de ses boss dans la
/// palette : niveau, une rangée de cartes que le clavier parcourt
/// (`CartesFiche`) — position, aide au combat, guide, conseils, monstres, succès, clef —, ce
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
            VStack(alignment: .leading, spacing: Jetons.espace2) {
                if let niveau = donjon.niveau {
                    Text(L("donjon.niveau", niveau)).font(Jetons.typoMicro.font)
                }
                // Sur une ligne : faute de place (beaucoup de clefs), elle défile.
                ViewThatFits(in: .horizontal) {
                    rangee(actions, detail)
                    // Une marge autour : sans elle, le cadre de la dernière carte choisie était rogné.
                    ScrollView(.horizontal, showsIndicators: false) {
                        rangee(actions, detail).padding(.horizontal, Jetons.epaisseurFocus)
                    }
                }
                ForEach(actions.filter { modele.ouvertes.contains($0) }, id: \.self) { action in
                    ouverte(action, detail).padding(.leading, Jetons.espace3)
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

    private func rangee(_ actions: [ActionFiche], _ detail: DetailDonjon?) -> some View {
        HStack(spacing: Jetons.espace1) {
            ForEach(actions, id: \.self) { action in
                carte(action, detail)
                    .fixedSize()
                    .id(Self.ancre(action))
                    .onTapGesture { modele.cliquer(action) }
                    .curseurDeClic(true)
            }
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

    private func carte(_ action: ActionFiche, _ detail: DetailDonjon?) -> some View {
        CarteAction(icone: icone(action), titre: titre(action, detail),
                    ouverte: action.sePlie ? modele.ouvertes.contains(action) : nil, choisie: modele.carte == action)
            .help(aide(action, detail) ?? "")
    }

    private func icone(_ action: ActionFiche) -> String {
        switch action {
        case .entree: return "arrow.triangle.turn.up.right.diamond"
        case .aide: return BoutonBarre.boss.symbole
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
        case .aide(let boss):
            // Plusieurs boss : chacun la sienne, à son nom.
            let donjons = store.donjons
            guard (donjons?.donjon(id: id)?.boss.count ?? 1) > 1 else { return L("donjon.aide") }
            return L("donjon.aide.boss", BossVue.nom(boss, donjons: donjons, garde: nil))
        case .guide: return L("donjon.guide")
        case .clef: return L("donjon.clef")
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

    /// Le détail qui allongerait la carte : le zaap retenu est déjà sur la
    /// ligne et dans le pied, le nom de la clef dans son « où trouver ».
    private func aide(_ action: ActionFiche, _ detail: DetailDonjon?) -> String? {
        switch action {
        case .entree(let lieu): return L("donjon.entree.aide", Coordonnees.texte(lieu.x, lieu.y))
        case .guide: return L("boss.guide")
        case .clef(let objet):
            let clef = detail?.clefs.first { $0.objet == objet }
            return L("donjon.clef.aide", clef?.quantite ?? 1, clef.flatMap { Lieu.traduit($0.noms, langue) } ?? "?")
        case .conseils: return L("donjon.conseils.aide")
        case .aide: return L("donjon.aide.aide")
        case .monstres, .succes: return nil
        }
    }

    @ViewBuilder
    private func ouverte(_ action: ActionFiche, _ detail: DetailDonjon?) -> some View {
        switch action {
        case .clef(let objet):
            OuTrouverVue(sujet: .objet(objet), metriques: .compact,
                         nom: detail?.clefs.first { $0.objet == objet }.flatMap { Lieu.traduit($0.noms, langue) })
        case .conseils:
            VStack(alignment: .leading, spacing: Jetons.espace1) { ConseilsVue(conseils: store.conseils[id] ?? []) }
        case .monstres:
            ForEach(detail?.monstres.filter { !$0.boss } ?? [], id: \.id) { monstre in ligne(monstre) }
        case .succes:
            ForEach(Array((detail?.succes ?? []).enumerated()), id: \.offset) { _, succes in
                Text("• " + (Lieu.traduit(succes.noms, langue) ?? "?"))
                    .font(Jetons.typoMeta.font)
                    .help(Lieu.traduit(succes.description, langue) ?? "")
            }
        case .entree, .guide, .aide: EmptyView()
        }
    }

    private func ligne(_ monstre: DetailDonjon.Monstre) -> some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            HStack(spacing: Jetons.espace1) {
                if monstre.boss { Image(systemName: "crown").foregroundStyle(Color.jeton(\.accentTexte)) }
                Text(Lieu.traduit(monstre.noms, langue) ?? "?").font((monstre.boss ? Jetons.typoMicro : Jetons.typoMeta).font)
            }
            FicheCombatVue(fiche: monstre.fiche)
        }
    }
}

/// Une carte d'action de fiche : symbole, titre, chevron quand elle déplie. Choisie au clavier, elle prend la teinte pleine
/// de la ligne choisie ; ouverte, seulement un lisere et un titre teintés.
private struct CarteAction: View {
    let icone: String
    let titre: String
    /// `nil` : elle agit plutôt que de déplier.
    let ouverte: Bool?
    let choisie: Bool

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            Image(systemName: icone)
                .foregroundStyle(choisie || ouverte == true ? Color.jeton(\.accentTexte) : Color.jeton(\.encre2))
            Text(titre)
                .foregroundStyle(ouverte == true && !choisie ? Color.jeton(\.accentTexte) : Color.jeton(\.encre))
                .lineLimit(1)
            if let ouverte {
                // Une largeur fixe : ouvrir une carte ne l'élargit pas, la rangée ne bascule pas
                // dans sa version qui défile et ne se décale pas.
                Image(systemName: ouverte ? "chevron.down" : "chevron.right")
                    .font(Jetons.typoMicro.font)
                    .foregroundStyle(Color.jeton(\.encre2))
                    .frame(width: Jetons.espace3)
            }
        }
        .font(Jetons.typoMeta.font)
        .padding(.horizontal, Jetons.espace2)
        .padding(.vertical, Jetons.espace1)
        .fondEtat(choisie ? .choisi : .repos)
        .overlay(RoundedRectangle(cornerRadius: Jetons.rayon1, style: .continuous)
            .strokeBorder(choisie ? Color.jeton(\.accent) : ouverte == true ? Color.jeton(\.accentTexte) : Color.jeton(\.filet),
                          lineWidth: choisie ? Jetons.epaisseurFocus : Jetons.epaisseurFilet))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(choisie ? [.isButton, .isSelected] : .isButton)
    }

}
