import SwiftUI

/// La palette : un champ, puis les cartes de zaaps (rien de tapé) ou la liste
/// des résultats, et la ligne des touches. Le clavier est géré par le panneau
/// (`PanneauPalette`) ; la vue ne fait que montrer la sélection.
struct PaletteVue: View {
    @ObservedObject var modele = PaletteModele.shared
    @ObservedObject private var quetes = QuetesStore.shared
    @ObservedObject private var almanax = AlmanaxStore.shared
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
                .font(.synfus(.titre))
                .foregroundStyle(.secondary)
            TextField(L("palette.invite"), text: $modele.requete)
                .textFieldStyle(.plain)
                .font(.synfus(.grand))
                .focused($champ, equals: .recherche)
                .help(L("raccourcis.palette.aide"))
            Text(mode)
                .font(.synfus(.petit, gras: true))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Couleurs.accentPlein))
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
                    .font(.synfus(.petit, gras: choisi))
                    .foregroundStyle(choisi ? Color.white : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(choisi ? Couleurs.accentPlein : Color.primary.opacity(0.06)))
                    .contentShape(Capsule())
                    .onTapGesture { modele.choisir(filtre) }
                    .accessibilityAddTraits(choisi ? [.isButton, .isSelected] : .isButton)
            }
            Spacer()
            // D'où partent distances et trajets : le dernier perso lu devant,
            // pas forcément celui qu'on croit quand on joue plusieurs comptes.
            Text(modele.origine)
                .font(.synfus(.petit))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Text(L("palette.tri", modele.tri.titre))
                .font(.synfus(.petit))
                .foregroundStyle(.secondary)
                .onTapGesture { modele.triSuivant() }
                .accessibilityAddTraits(.isButton)
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
        if texte.hasPrefix("/quete") || texte.hasPrefix("/quête") { return "/quete" }
        if texte.hasPrefix("/pnj") { return "/pnj" }
        if texte.hasPrefix("/") { return L("palette.mode.commandes") }
        return L("palette.mode.tout")
    }

    // MARK: - Résultats

    @ViewBuilder
    private var resultats: some View {
        if modele.entrees.isEmpty {
            let sansLecture = modele.filtre == .ici && !modele.positionConnue && !Preferences.shared.lirePosition
            VStack(spacing: 8) {
                Text(quetes.chargement && quetes.quetes == nil ? L("palette.quetes.chargement")
                     : modele.filtre == .ici && !modele.positionConnue
                        ? (sansLecture ? L("palette.ici.sansPosition") : L("palette.ici.pasEncore"))
                        : L("palette.aucun"))
                    .font(.synfus(.corps))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if sansLecture {
                    Button(L("lecture.ouvrir")) { SettingsWindowController.shared.show(section: .lecture) }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
        } else {
            ScrollViewReader { defilement in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if modele.enGrille, let jour = almanax.almanax {
                            AlmanaxVue(almanax: jour, copier: { modele.copier($0) },
                                       allerAuSanctuaire: modele.sanctuaire.map { lieu in { modele.copierTrajet(vers: lieu) } })
                        }
                        if modele.enGrille, !modele.recents.isEmpty { recents }
                        if modele.enGrille { grille } else { liste }
                    }
                    .padding(10)
                }
                .frame(height: modele.enGrille ? 300
                       : modele.deplie != nil ? 380 : min(CGFloat(modele.entrees.count) * 44 + 20, 380))
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
                        .font(.synfus(.petit, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                        .onTapGesture { modele.executer(entree) }
                        .help(entree.titre)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .font(.synfus(.petit))
    }

    private var grille: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: PaletteModele.colonnes),
                  spacing: 8) {
            ForEach(Array(modele.entrees.enumerated()), id: \.element.id) { index, entree in
                CarteZaap(entree: entree, choisie: index == modele.selection)
                    .id(entree.id)
                    .onTapGesture { modele.executer(entree) }
                    .help(entree.complet)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .contextMenu { menu(entree) }
            }
        }
    }

    private var liste: some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(modele.entrees.enumerated()), id: \.element.id) { index, entree in
                let deplie = modele.deplie == entree.id
                LigneResultat(entree: entree, choisie: index == modele.selection, deplie: deplie)
                    .id(entree.id)
                    .onTapGesture { modele.executer(entree) }
                    .help(entree.complet)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .contextMenu { menu(entree) }
                if deplie, case .ouTrouver(let sujet) = entree.effet {
                    OuTrouverVue(sujet: sujet, metriques: .confort)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 48)
                        .padding(.bottom, 6)
                }
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
        if entree.genre == .objet {
            Button(L("quete.copierNom")) { modele.copier(entree.titre) }
        }
    }

    // MARK: - Pied

    @ViewBuilder
    private var pied: some View {
        if let edition = modele.edition {
            HStack(spacing: 8) {
                Text(L("palette.etiquette.pour", edition.titre))
                    .font(.synfus(.note))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                TextField(L("palette.etiquette.exemple"), text: $modele.texteEtiquette)
                    .textFieldStyle(.roundedBorder)
                    .font(.synfus(.note))
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
                // Sans saisie, ↵ a un texte court : la place d'annoncer `/` et `%`.
                if modele.requete.isEmpty {
                    aide("/", L("palette.touche.commandes"))
                    aide("%", L("palette.touche.variables"))
                } else {
                    aide("⇥", L("palette.touche.filtre"))
                }
                aide("⌘E", L("palette.touche.etiquette"))
                aide("⌘D", L("palette.touche.favori"))
                Spacer()
                aide("esc", L("palette.touche.fermer"))
            }
            .font(.synfus(.petit))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(height: 36)
        }
    }

    /// Ce qu'Entrée fera de la sélection — le texte même qui sera copié.
    private var entree: String {
        guard modele.entrees.indices.contains(modele.selection) else { return L("palette.touche.valider") }
        let entree = modele.entrees[modele.selection]
        switch entree.effet {
        case .copier, .trajet: return L("palette.touche.copier", modele.texteACopier(entree) ?? "")
        case .completer: return L("palette.touche.completer")
        case .action: return L("palette.touche.faire")
        case .ouvrirQuete: return L("palette.touche.ouvrir")
        case .ouTrouver: return L("palette.touche.ouTrouver")
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
            .font(.synfus(.petit, design: .monospaced))
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
                    Image(systemName: "star.fill").font(.synfus(.marque)).foregroundStyle(Couleurs.ambre)
                }
            }
            .frame(height: 16)
            Text(entree.titre)
                .font(.synfus(.note, gras: true))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(entree.itineraire ?? entree.sousTitre ?? "")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(entree.detail ?? "")
                    .font(.synfus(.petit, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .font(.synfus(.petit))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FondCarte(carte: entree.carte, teinte: choisie ? Couleurs.accent.opacity(0.22) : nil) }
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(choisie ? Couleurs.accent : Color.primary.opacity(0.08)))
        .contentShape(Rectangle())
    }
}

/// Une ligne de résultat : genre (ou pictogramme du lieu), titre, étiquette,
/// sous-titre, détail, vue de la carte.
private struct LigneResultat: View {
    let entree: EntreePalette
    let choisie: Bool
    var deplie = false

    var body: some View {
        HStack(spacing: 12) {
            PictogrammeLieu(gfx: entree.pictogramme) {
                Image(systemName: icone)
                    .font(.synfus(.corps))
                    .foregroundStyle(choisie ? Couleurs.accentTexte : Color.secondary)
            }
            .frame(width: 22, height: 22)
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entree.titre).font(.synfus(.corps)).lineLimit(1)
                    if let etiquette = entree.etiquette { PastilleEtiquette(texte: etiquette) }
                    if entree.favori {
                        Image(systemName: "star.fill").font(.synfus(.marque)).foregroundStyle(Couleurs.ambre)
                    }
                    if entree.interieur { EtiquetteInterieur(taille: .petit) }
                }
                if entree.sousTitre != nil || entree.itineraire != nil {
                    HStack(spacing: 6) {
                        if let sousTitre = entree.sousTitre { Text(sousTitre).foregroundStyle(.secondary) }
                        // Le zaap retenu, à lire avant d'Entrée : le trajet copié y passe.
                        if let itineraire = entree.itineraire {
                            Text(itineraire).foregroundStyle(Couleurs.accentTexte).layoutPriority(1)
                        }
                    }
                    .font(.synfus(.petit))
                    .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let detail = entree.detail {
                Text(detail)
                    .font(.synfus(.note, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let carte = entree.carte { MiniatureCarte(carte: carte, taille: Self.vignette) }
            if case .ouTrouver = entree.effet {
                Image(systemName: deplie ? "chevron.down" : "chevron.right")
                    .font(.synfus(.petit, gras: true))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(choisie ? Couleurs.accent.opacity(0.22) : Color.clear))
        .contentShape(Rectangle())
    }

    /// À la hauteur d'une ligne de deux textes : la liste ne s'allonge pas.
    private static let vignette = CGSize(width: 46, height: 32)

    private var icone: String {
        switch entree.genre {
        case .zaap: return "point.3.connected.trianglepath.dotted"
        case .lieu: return "mappin.and.ellipse"
        case .commande: return "slash.circle"
        case .variable: return "percent"
        case .perso: return "person"
        case .action: return "bolt"
        case .recent: return "clock.arrow.circlepath"
        case .quete: return "scroll"
        case .pnj: return "person.wave.2"
        case .monstre: return "pawprint"
        case .objet: return "bag"
        }
    }
}

/// Une carte qui n'est pas en extérieur : `/travel` mène devant, il reste
/// à entrer. La palette et le panneau des quêtes la disent pareil.
struct EtiquetteInterieur: View {
    let taille: TailleTexte

    var body: some View {
        Text(L("carte.interieur"))
            .font(.synfus(taille))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.5)))
            .lineLimit(1)
            .help(L("carte.interieur.aide"))
    }
}

struct PastilleEtiquette: View {
    let texte: String

    var body: some View {
        Text(texte)
            .font(.synfus(.petit, gras: true))
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(Couleurs.ambre))
            .lineLimit(1)
    }
}
