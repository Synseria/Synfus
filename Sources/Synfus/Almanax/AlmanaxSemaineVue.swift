import SwiftUI

/// La vue « Almanax » de la palette : l'offrande du jour en grand, avec le trajet jusqu'au
/// Sanctuaire, puis les six jours suivants en cartes pour préparer l'achat groupé.
struct AlmanaxSemaineVue: View {
    let semaine: [AlmanaxStore.Jour]
    let selection: Int
    let deplie: Int?
    let copier: (Int) -> Void
    let deplier: (Int) -> Void
    /// Copie le trajet jusqu'au Sanctuaire ; `nil` si la carte ne le situe pas.
    let allerAuSanctuaire: (() -> Void)?

    private var langue: Langue { L10n.courante.langue }

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
            if let aujourdhui = semaine.first {
                carteDuJour(aujourdhui)
                fiche(sous: 0)
            }
            ForEach(Array(stride(from: 1, to: semaine.count, by: 3)), id: \.self) { debut in
                HStack(alignment: .top, spacing: Jetons.Espace.deux) {
                    ForEach(debut..<min(debut + 3, semaine.count), id: \.self) { carte($0) }
                }
                fiche(sous: debut)
            }
        }
    }

    /// Où trouver l'offrande, sous la ligne de la carte dépliée.
    @ViewBuilder
    private func fiche(sous index: Int) -> some View {
        if let deplie, NavigationAlmanax.ligne(de: index).contains(deplie),
           let objet = semaine[deplie].almanax?.offrandes.first?.objet {
            // Sur la largeur de la ligne, dans un creux : le chargement se lit comme le contenu de la carte.
            OuTrouverVue(sujet: .objet(objet), metriques: .confort)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Jetons.Espace.deux)
                .background(RoundedRectangle(cornerRadius: Jetons.Rayon.carte, style: .continuous).fill(Color.jeton(\.creux)))
        }
    }

    private func carteDuJour(_ jour: AlmanaxStore.Jour) -> some View {
        let nom = jour.almanax?.nomOffrande(langue)
        return HStack(alignment: .top, spacing: Jetons.Espace.deux) {
            IconeOffrande(offrande: jour.almanax?.offrandes.first)
                .frame(width: Jetons.Taille.controle, height: Jetons.Taille.controle)
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                HStack(spacing: Jetons.Espace.un) {
                    Text(L("palette.almanax.aujourdhui")).font(Jetons.Typo.raccourci.police)
                        .foregroundStyle(Color.jeton(\.safranTexte))
                    if let offrande = jour.almanax?.offrandes.first, let nom {
                        Text(L("palette.almanax.offrande", offrande.quantite, nom)).font(Jetons.Typo.corpsFort.police)
                    }
                }
                if let almanax = jour.almanax, let bonus = Lieu.traduit(almanax.bonus, langue) {
                    let description = Lieu.traduit(almanax.description, langue)
                    Text(description.map { L("palette.almanax.bonus", bonus, $0) } ?? bonus)
                        .font(Jetons.Typo.petit.police)
                        .foregroundStyle(Color.jeton(\.encreSecondaire))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Jetons.Espace.un)
            if let nom {
                Button { copier(0) } label: {
                    Label(L("palette.almanax.copier"), systemImage: "doc.on.clipboard").labelStyle(.iconOnly)
                }
                .buttonStyle(.bouton(.secondaire, dense: true))
                .aide(L("palette.almanax.copier.nom", nom))
            }
            if let allerAuSanctuaire {
                Button(action: allerAuSanctuaire) {
                    Label(L("palette.almanax.sanctuaire"), systemImage: "arrow.triangle.turn.up.right.diamond")
                }
                .buttonStyle(.bouton(.principal, dense: true))
                .aide(L("palette.almanax.sanctuaire.aide"))
            }
            chevron(0)
        }
        .padding(Jetons.Espace.deux)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fond(Color.jeton(\.safranFond), choisie: selection == 0))
        .contentShape(Rectangle())
        .onTapGesture { copier(0) }
        .id(Self.ancre(0))
    }

    private func carte(_ index: Int) -> some View {
        let jour = semaine[index]
        let choisie = selection == index
        return VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            HStack {
                Text(Almanax.libelle(du: jour.jour, langue))
                    .font(Jetons.Typo.petit.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                Spacer(minLength: 0)
                if jour.almanax != nil { chevron(index) }
            }
            if let almanax = jour.almanax {
                HStack(alignment: .top, spacing: Jetons.Espace.deux) {
                    IconeOffrande(offrande: almanax.offrandes.first)
                        .frame(width: Jetons.Taille.controle, height: Jetons.Taille.controle)
                    if let offrande = almanax.offrandes.first, let nom = almanax.nomOffrande(langue) {
                        Text(L("palette.almanax.offrande", offrande.quantite, nom))
                            .font(Jetons.Typo.corpsFort.police)
                            .lineLimit(2)
                    }
                }
                Text(Lieu.traduit(almanax.bonus, langue) ?? "")
                    .font(Jetons.Typo.petit.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .lineLimit(2, reservesSpace: true)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(Jetons.Espace.deux)
        .frame(maxWidth: .infinity, minHeight: Self.hauteurCarte, alignment: .topLeading)
        .background(fond(Color.jeton(jour.almanax == nil ? \.creux : \.surface), choisie: choisie))
        .contentShape(Rectangle())
        .onTapGesture { if jour.almanax != nil { copier(index) } }
        .id(Self.ancre(index))
    }

    /// Mesure de mise en page : la date, deux lignes d'offrande et deux lignes de bonus. Un jour qui
    /// attend le sien garde cette hauteur, pour que la grille ne bouge pas quand il arrive.
    private static let hauteurCarte: CGFloat = 110

    static func ancre(_ index: Int) -> String { "almanax:\(index)" }

    private func fond(_ couleur: Color, choisie: Bool) -> some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.Rayon.carte, style: .continuous)
        return forme.fill(couleur).overlay(
            forme.strokeBorder(choisie ? Color.jeton(\.primaire) : Color.jeton(\.filet),
                               lineWidth: choisie ? Jetons.Trait.etat : Jetons.Trait.filet))
    }

    /// Déplie ou replie « Localiser » sous la carte.
    private func chevron(_ index: Int) -> some View {
        Button { deplier(index) } label: {
            Image(systemName: deplie == index ? "chevron.down" : "chevron.right")
                .font(Jetons.Typo.raccourci.police)
                .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
        }
        .buttonStyle(.etat(nue: true))
        .aide(L("palette.touche.ouTrouver"))
    }
}

/// L'icône vient de DofusDB, à la demande ; sans visuels du jeu, le symbole.
private struct IconeOffrande: View {
    let offrande: Almanax.Offrande?

    var body: some View {
        let symbole = Image(systemName: "calendar").foregroundStyle(Color.jeton(\.safranTexte))
        if let icone = offrande?.icone {
            ImageDofusDB(url: DofusDB.imageObjet(icone)) { symbole }.aspectRatio(contentMode: .fit)
        } else {
            symbole
        }
    }
}
