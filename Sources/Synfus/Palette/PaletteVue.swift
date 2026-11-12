import SwiftUI

/// La palette : un champ, puis les cartes de zaaps (rien de tapé) ou la liste
/// des résultats, et la ligne des touches. Le clavier est géré par le panneau
/// (`PanneauPalette`) ; la vue ne fait que montrer la sélection.
struct PaletteVue: View {
    @ObservedObject var modele = PaletteModele.shared
    @ObservedObject private var quetes = QuetesStore.shared
    @ObservedObject private var almanax = AlmanaxStore.shared
    /// Le détail d'un donjon arrive après l'ouverture : ↵ et les cartes de sa fiche changent.
    @ObservedObject private var donjons = DonjonsStore.shared
    @FocusState private var champ: Champ?
    @State private var filtreSurvole: FiltrePalette?

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
        .surfaceFlottante()
        .onAppear { champ = .recherche }
        .onChange(of: modele.ouverture) { _, _ in champ = .recherche }
        .onChange(of: modele.edition) { _, edition in champ = edition == nil ? .recherche : .etiquette }
    }

    // MARK: - Champ

    private var recherche: some View {
        HStack(spacing: Jetons.Espace.deux) {
            Image(systemName: "magnifyingglass")
                .font(.synfus(.titre))
                .foregroundStyle(Couleurs.encreSecondaire)
            TextField(L("palette.invite"), text: $modele.requete)
                .textFieldStyle(.plain)
                .font(.synfus(.titre))
                .focused($champ, equals: .recherche)
                .help(L("raccourcis.palette.aide"))
            // D'où partent distances et trajets : le dernier perso lu devant,
            // pas forcément celui qu'on croit quand on joue plusieurs comptes.
            Label(modele.origine, systemImage: "location")
                .font(.synfus(.petit))
                .foregroundStyle(Couleurs.encreSecondaire)
                .lineLimit(1)
                .fixedSize()
                .help(L("palette.depuis.aide"))
            if let mode {
                Text(mode)
                    .font(.synfus(.raccourci))
                    .foregroundStyle(EtatVisuel.courant.encre)
                    .padding(.horizontal, Jetons.Espace.deux)
                    .frame(height: Jetons.Taille.controleDense)
                    .fondEtat(.courant, rayon: Jetons.Rayon.capsule)
            }
        }
        .padding(.horizontal, Jetons.Espace.quatre)
        .frame(height: Jetons.Taille.rangeePalette + Jetons.Espace.quatre)
    }

    /// Les familles que Tab fait défiler, et le tri (⌘T).
    private var filtres: some View {
        HStack(spacing: Jetons.Espace.un) {
            ForEach(FiltrePalette.allCases, id: \.self) { filtre in
                let choisi = modele.filtre == filtre
                let etat: EtatVisuel = choisi ? .courant : EtatVisuel(survole: filtreSurvole == filtre)
                Text(filtre.titre)
                    .font(.synfus(choisi ? .raccourci : .petit))
                    .foregroundStyle(choisi ? etat.encre : etat.encreSecondaire)
                    .padding(.horizontal, Jetons.Espace.deux)
                    .frame(height: Jetons.Taille.controleDense)
                    .fondEtat(etat, rayon: Jetons.Rayon.capsule)
                    .onHover { filtreSurvole = $0 ? filtre : nil }
                    .onTapGesture { modele.choisir(filtre) }
                    .accessibilityAddTraits(choisi ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: Jetons.Espace.deux)
            Label(modele.tri.titre, systemImage: "arrow.up.arrow.down")
                .font(.synfus(.petit))
                .foregroundStyle(Couleurs.encreSecondaire)
                .lineLimit(1)
                .fixedSize()
                .contentShape(Rectangle())
                .onTapGesture { modele.triSuivant() }
                .help(L("palette.tri.aide"))
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, Jetons.Espace.quatre)
        .padding(.bottom, Jetons.Espace.deux)
    }

    /// Le mode d'une commande tapée ; rien quand on cherche partout, que les filtres disent déjà.
    private var mode: String? {
        let texte = modele.requete.trimmingCharacters(in: .whitespaces)
        if !texte.hasPrefix("/"), !texte.hasPrefix("%") { return nil }
        if texte.hasPrefix("%") { return L("palette.mode.variables") }
        if texte.hasPrefix("/zaap") { return "/zaap" }
        if texte.hasPrefix("/travel") { return "/travel" }
        if texte.hasPrefix("/invite") { return "/invite" }
        if texte.hasPrefix("/quete") || texte.hasPrefix("/quête") { return "/quete" }
        if texte.hasPrefix("/pnj") { return "/pnj" }
        return L("palette.mode.commandes")
    }

    // MARK: - Résultats

    @ViewBuilder
    private var resultats: some View {
        if modele.entrees.isEmpty {
            let sansLecture = modele.filtre == .ici && !modele.positionConnue && !Preferences.shared.lirePosition
            VStack(spacing: Jetons.Espace.deux) {
                Text(quetes.chargement && quetes.quetes == nil ? L("palette.quetes.chargement")
                     : modele.filtre == .ici && !modele.positionConnue
                        ? (sansLecture ? L("palette.ici.sansPosition") : L("palette.ici.pasEncore"))
                        : L("palette.aucun"))
                    .font(.synfus(.corps))
                    .foregroundStyle(Couleurs.encreSecondaire)
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
                    VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
                        if modele.enGrille, let jour = almanax.almanax {
                            AlmanaxVue(almanax: jour, copier: { modele.copier($0) },
                                       allerAuSanctuaire: modele.sanctuaire.map { lieu in { modele.copierTrajet(vers: lieu) } })
                        }
                        if modele.enGrille, !modele.recents.isEmpty { recents }
                        if modele.enGrille { grille } else { liste }
                    }
                    .padding(Jetons.Espace.deux)
                }
                .frame(height: modele.enGrille ? 300
                       : modele.deplie != nil ? 380 : min(CGFloat(modele.entrees.count) * 44 + 20, 380))
                .onChange(of: modele.selection) { _, index in
                    guard modele.entrees.indices.contains(index) else { return }
                    defilement.scrollTo(modele.entrees[index].id)
                }
                .onChange(of: modele.carte) { _, carte in
                    guard let carte else { return }
                    defilement.scrollTo(FicheDonjonVue.ancre(carte))
                }
            }
        }
    }

    /// Les dernières copies, en pastilles : un clic recopie.
    private var recents: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Jetons.Espace.un) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(Couleurs.encreSecondaire)
                ForEach(modele.recents) { entree in
                    Text(entree.titre)
                        .font(.synfus(.codeInterface))
                        .lineLimit(1)
                        .padding(.horizontal, Jetons.Espace.deux)
                        .frame(height: Jetons.Taille.controleDense)
                        .background(Capsule().fill(Couleurs.creux))
                        .onTapGesture { modele.executer(entree) }
                        .help(entree.titre)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .font(.synfus(.petit))
    }

    private var grille: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Jetons.Espace.deux), count: PaletteModele.colonnes),
                  spacing: Jetons.Espace.deux) {
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
        LazyVStack(spacing: Jetons.Espace.un) {
            ForEach(Array(modele.entrees.enumerated()), id: \.element.id) { index, entree in
                let deplie = modele.deplie == entree.id
                // Le clavier dans la fiche : la ligne ne se dit plus choisie, la carte l'est.
                LigneResultat(entree: entree, choisie: index == modele.selection && modele.carte == nil, deplie: deplie)
                    .id(entree.id)
                    .onTapGesture { modele.executer(entree) }
                    .help(entree.complet)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .contextMenu { menu(entree) }
                if deplie {
                    Group {
                        switch entree.effet {
                        case .ouTrouver(let sujet): OuTrouverVue(sujet: sujet, metriques: .confort)
                        case .donjon(let id): FicheDonjonVue(id: id, modele: modele)
                        default: EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, Jetons.Espace.dix + Jetons.Espace.deux)
                    .padding(.bottom, Jetons.Espace.un)
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
            HStack(spacing: Jetons.Espace.deux) {
                Text(L("palette.etiquette.pour", edition.titre))
                    .font(.synfus(.note))
                    .foregroundStyle(Couleurs.encreSecondaire)
                    .lineLimit(1)
                TextField(L("palette.etiquette.exemple"), text: $modele.texteEtiquette)
                    .textFieldStyle(.roundedBorder)
                    .font(.synfus(.note))
                    .focused($champ, equals: .etiquette)
                ToucheRaccourci("↵")
                ToucheRaccourci("esc")
            }
            .padding(.horizontal, Jetons.Espace.quatre)
            .frame(height: Jetons.Taille.rangeePalette + Jetons.Espace.un)
        } else {
            HStack(spacing: Jetons.Espace.trois) {
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
            .foregroundStyle(Couleurs.encreSecondaire)
            .padding(.horizontal, Jetons.Espace.quatre)
            .frame(height: Jetons.Taille.rangeePalette)
        }
    }

    /// Ce qu'Entrée fera de la sélection — le texte même qui sera copié.
    private var entree: String {
        guard modele.entrees.indices.contains(modele.selection) else { return L("palette.touche.valider") }
        let entree = modele.entrees[modele.selection]
        if entree.id == modele.deplie {
            return modele.cartes.valide(modele.carte).map(aide) ?? L("palette.touche.replier")
        }
        switch entree.effet {
        case .copier, .trajet: return L("palette.touche.copier", modele.texteACopier(entree) ?? "")
        case .completer: return L("palette.touche.completer")
        case .action: return L("palette.touche.faire")
        case .ouvrirQuete: return L("palette.touche.ouvrir")
        case .ouTrouver: return L("palette.touche.ouTrouver")
        case .donjon: return L("palette.touche.fiche")
        }
    }

    private func aide(_ action: ActionFiche) -> String {
        switch action {
        case .entree(let lieu): return L("palette.touche.copier", modele.trajet(vers: lieu) ?? "")
        case .guide: return L("palette.touche.guide")
        case .clef, .conseils, .monstres, .succes:
            return modele.ouvertes.contains(action) ? L("palette.touche.replier") : L("palette.touche.deplier")
        }
    }

    private func aide(_ touche: String, _ texte: String) -> some View {
        HStack(spacing: Jetons.Espace.un) {
            ToucheRaccourci(touche)
            Text(texte)
        }
    }
}

/// Une carte de zaap : étiquette, nom, zone et coordonnées.
private struct CarteZaap: View {
    let entree: EntreePalette
    let choisie: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            HStack(spacing: Jetons.Espace.un) {
                if let etiquette = entree.etiquette { PastilleEtiquette(texte: etiquette) }
                Spacer(minLength: 0)
                if entree.favori {
                    Image(systemName: "star.fill").font(.synfus(.micro)).foregroundStyle(Couleurs.safranTexte)
                }
            }
            .frame(height: Jetons.Espace.quatre)
            Text(entree.titre)
                .font(.synfus(.corpsFort))
                .lineLimit(1)
            HStack(spacing: Jetons.Espace.un) {
                Text(entree.itineraire ?? entree.sousTitre ?? "")
                    .lineLimit(1)
                    .foregroundStyle(Couleurs.encreSecondaire)
                Spacer(minLength: 0)
                Text(entree.detail ?? "")
                    .font(.synfus(.codeInterface))
                    .foregroundStyle(Couleurs.encreSecondaire)
            }
            .font(.synfus(.petit))
        }
        .padding(Jetons.Espace.deux)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FondCarte(carte: entree.carte, teinte: choisie ? Couleurs.primaireFond : nil) }
        .contentShape(Rectangle())
    }
}

/// Une ligne de résultat : genre (ou pictogramme du lieu), titre, étiquette,
/// sous-titre, détail, vue de la carte.
private struct LigneResultat: View {
    let entree: EntreePalette
    let choisie: Bool
    var deplie = false
    @State private var survole = false

    var body: some View {
        HStack(spacing: Jetons.Espace.trois) {
            PictogrammeLieu(gfx: entree.pictogramme) {
                Image(systemName: icone)
                    .font(.synfus(.corps))
                    .foregroundStyle(choisie ? Couleurs.primaireEncre : Couleurs.encreSecondaire)
            }
            .frame(width: Jetons.Taille.controleDense, height: Jetons.Taille.controleDense)
            .frame(width: Jetons.Taille.rangee, height: Jetons.Taille.rangee)
            .background(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille, style: .continuous).fill(Couleurs.creux))
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                HStack(spacing: Jetons.Espace.un) {
                    Text(entree.titre).font(.synfus(.corps)).lineLimit(1)
                    if let etiquette = entree.etiquette { PastilleEtiquette(texte: etiquette) }
                    if entree.favori {
                        Image(systemName: "star.fill").font(.synfus(.micro)).foregroundStyle(Couleurs.safranTexte)
                    }
                    if entree.interieur { EtiquetteInterieur(taille: .petit) }
                }
                if entree.sousTitre != nil || entree.itineraire != nil {
                    HStack(spacing: Jetons.Espace.un) {
                        if let sousTitre = entree.sousTitre { Text(sousTitre).foregroundStyle(Couleurs.encreSecondaire) }
                        // Le zaap retenu, à lire avant d'Entrée : le trajet copié y passe.
                        if let itineraire = entree.itineraire {
                            Text(itineraire).foregroundStyle(Couleurs.primaireEncre).layoutPriority(1)
                        }
                    }
                    .font(.synfus(.petit))
                    .lineLimit(1)
                }
            }
            Spacer(minLength: Jetons.Espace.deux)
            if let detail = entree.detail {
                Text(detail)
                    .font(.synfus(.codeInterface))
                    .foregroundStyle(Couleurs.encreSecondaire)
                    .lineLimit(1)
            }
            if let carte = entree.carte { MiniatureCarte(carte: carte, taille: Self.vignette) }
            if entree.effet.sePlie {
                Image(systemName: deplie ? "chevron.down" : "chevron.right")
                    .font(.synfus(.raccourci))
                    .foregroundStyle(Couleurs.encreSecondaire)
                    .frame(width: Jetons.Taille.case)
            }
        }
        .padding(.horizontal, Jetons.Espace.deux)
        .padding(.vertical, Jetons.Espace.un)
        .fondEtat(choisie ? .choisi : EtatVisuel(survole: survole))
        .onHover { survole = $0 }
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
    let taille: Jetons.Typo

    var body: some View {
        Text(L("carte.interieur"))
            .font(.synfus(taille))
            .foregroundStyle(Couleurs.encreSecondaire)
            .padding(.horizontal, Jetons.Espace.un)
            .overlay(Capsule().strokeBorder(Couleurs.contourControle, lineWidth: Jetons.Trait.filet))
            .lineLimit(1)
            .help(L("carte.interieur.aide"))
    }
}

struct PastilleEtiquette: View {
    let texte: String

    var body: some View {
        Text(texte)
            .font(.synfus(.raccourci))
            .foregroundStyle(Couleurs.encreSurSafran)
            .padding(.horizontal, Jetons.Espace.un)
            .background(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille).fill(Couleurs.safran))
            .lineLimit(1)
    }
}
