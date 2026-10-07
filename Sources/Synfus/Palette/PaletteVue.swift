import SwiftUI

/// La palette : un champ, puis les cartes de zaaps (rien de tapé) ou la liste
/// des résultats, et la ligne des touches. Le clavier est géré par le panneau
/// (`PanneauPalette`) ; la vue ne fait que montrer la sélection.
struct PaletteVue: View {
    @ObservedObject var modele = PaletteModele.shared
    @FocusState private var champ: Champ?

    private enum Champ { case recherche, etiquette }

    var body: some View {
        VStack(spacing: 0) {
            recherche
            filtres
            Divider()
            resultats
            Divider()
            pied
        }
        .frame(width: PalettePanel.largeur)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        .onAppear { champ = .recherche }
        .onChange(of: modele.ouverture) { _, _ in champ = .recherche }
        .onChange(of: modele.edition) { _, edition in champ = edition == nil ? .recherche : .etiquette }
    }

    // MARK: - Champ

    private var recherche: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            TextField(L("palette.invite"), text: $modele.requete)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .focused($champ, equals: .recherche)
            Text(mode)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Couleurs.accent))
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    /// Les familles que Tab fait défiler, et le tri (⌘T).
    private var filtres: some View {
        HStack(spacing: 4) {
            ForEach(FiltrePalette.allCases, id: \.self) { filtre in
                let choisi = modele.filtre == filtre
                Text(filtre.titre)
                    .font(.system(size: 11, weight: choisi ? .semibold : .regular))
                    .foregroundStyle(choisi ? Color.white : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(choisi ? Couleurs.accent : Color.primary.opacity(0.06)))
            }
            Spacer()
            Text(L("palette.tri", modele.tri.titre))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .onTapGesture { modele.triSuivant() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var mode: String {
        let texte = modele.requete.trimmingCharacters(in: .whitespaces)
        if texte.isEmpty { return L("palette.mode.zaaps") }
        if texte.hasPrefix("%") { return L("palette.mode.variables") }
        if texte.hasPrefix("/zaap") { return "/zaap" }
        if texte.hasPrefix("/travel") { return "/travel" }
        if texte.hasPrefix("/invite") { return "/invite" }
        if texte.hasPrefix("/") { return L("palette.mode.commandes") }
        return L("palette.mode.tout")
    }

    // MARK: - Résultats

    @ViewBuilder
    private var resultats: some View {
        if modele.entrees.isEmpty {
            Text(L("palette.aucun"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
        } else {
            ScrollViewReader { defilement in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if modele.enGrille, !modele.recents.isEmpty { recents }
                        if modele.enGrille { grille } else { liste }
                    }
                    .padding(10)
                }
                .frame(height: modele.enGrille ? 300 : min(CGFloat(modele.entrees.count) * 44 + 20, 380))
                .onChange(of: modele.selection) { _, index in
                    guard modele.entrees.indices.contains(index) else { return }
                    defilement.scrollTo(modele.entrees[index].id)
                }
            }
        }
    }

    /// Les dernières copies, en pastilles : un clic recopie.
    private var recents: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                ForEach(modele.recents) { entree in
                    Text(entree.titre)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                        .onTapGesture { modele.executer(entree) }
                        .help(entree.titre)
                }
            }
        }
        .font(.system(size: 11))
    }

    private var grille: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: PaletteModele.colonnes),
                  spacing: 8) {
            ForEach(Array(modele.entrees.enumerated()), id: \.element.id) { index, entree in
                CarteZaap(entree: entree, choisie: index == modele.selection)
                    .id(entree.id)
                    .onTapGesture { modele.executer(entree) }
                    .contextMenu { menu(entree) }
            }
        }
    }

    private var liste: some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(modele.entrees.enumerated()), id: \.element.id) { index, entree in
                LigneResultat(entree: entree, choisie: index == modele.selection)
                    .id(entree.id)
                    .onTapGesture { modele.executer(entree) }
                    .contextMenu { menu(entree) }
            }
        }
    }

    @ViewBuilder
    private func menu(_ entree: EntreePalette) -> some View {
        if entree.cle != nil {
            Button(entree.favori ? L("palette.favori.retirer") : L("palette.favori.ajouter")) {
                modele.basculerFavori(entree)
            }
            Button(L("palette.etiquette.modifier")) { modele.commencerEtiquette(entree) }
        }
    }

    // MARK: - Pied

    @ViewBuilder
    private var pied: some View {
        if let edition = modele.edition {
            HStack(spacing: 8) {
                Text(L("palette.etiquette.pour", edition.titre))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                TextField(L("palette.etiquette.exemple"), text: $modele.texteEtiquette)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .focused($champ, equals: .etiquette)
                Touche("↵")
                Touche("esc")
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
        } else {
            HStack(spacing: 14) {
                aide("↵", entree)
                    .lineLimit(1)
                    .truncationMode(.middle)
                aide("⇥", L("palette.touche.filtre"))
                aide("⌘E", L("palette.touche.etiquette"))
                aide("⌘D", L("palette.touche.favori"))
                aide("⌘T", L("palette.touche.tri"))
                Spacer()
                aide("esc", L("palette.touche.fermer"))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(height: 36)
        }
    }

    /// Ce qu'Entrée fera de la sélection — le texte même qui sera copié.
    private var entree: String {
        guard modele.entrees.indices.contains(modele.selection) else { return L("palette.touche.valider") }
        switch modele.entrees[modele.selection].effet {
        case .copier(let texte): return L("palette.touche.copier", texte)
        case .completer: return L("palette.touche.completer")
        case .basculer, .action: return L("palette.touche.faire")
        }
    }

    private func aide(_ touche: String, _ texte: String) -> some View {
        HStack(spacing: 4) {
            Touche(touche)
            Text(texte)
        }
    }
}

/// Une touche du clavier, dessinée.
private struct Touche: View {
    let texte: String
    init(_ texte: String) { self.texte = texte }

    var body: some View {
        Text(texte)
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.15)))
    }
}

/// Une carte de zaap : étiquette, nom, zone et coordonnées.
private struct CarteZaap: View {
    let entree: EntreePalette
    let choisie: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let etiquette = entree.etiquette { PastilleEtiquette(texte: etiquette) }
                Spacer(minLength: 0)
                if entree.favori {
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Couleurs.ambre)
                }
            }
            .frame(height: 16)
            Text(entree.titre)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(entree.sousTitre ?? "")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(entree.detail ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(choisie ? Couleurs.accent.opacity(0.22) : Color.primary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(choisie ? Couleurs.accent : Color.primary.opacity(0.08)))
        .contentShape(Rectangle())
    }
}

/// Une ligne de résultat : genre, titre, étiquette, sous-titre, détail.
private struct LigneResultat: View {
    let entree: EntreePalette
    let choisie: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icone)
                .font(.system(size: 13))
                .foregroundStyle(choisie ? Couleurs.accent : Color.secondary)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entree.titre).font(.system(size: 13)).lineLimit(1)
                    if let etiquette = entree.etiquette { PastilleEtiquette(texte: etiquette) }
                    if entree.favori {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Couleurs.ambre)
                    }
                }
                if let sousTitre = entree.sousTitre {
                    Text(sousTitre).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let detail = entree.detail {
                Text(detail)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(choisie ? Couleurs.accent.opacity(0.22) : Color.clear))
        .contentShape(Rectangle())
    }

    private var icone: String {
        switch entree.genre {
        case .zaap: return "point.3.connected.trianglepath.dotted"
        case .lieu: return "mappin.and.ellipse"
        case .commande: return "slash.circle"
        case .variable: return "percent"
        case .perso: return "person"
        case .action: return "bolt"
        case .recent: return "clock.arrow.circlepath"
        }
    }
}

struct PastilleEtiquette: View {
    let texte: String

    var body: some View {
        Text(texte)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(Couleurs.ambre))
            .lineLimit(1)
    }
}
