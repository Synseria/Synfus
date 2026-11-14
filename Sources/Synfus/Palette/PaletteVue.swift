import SwiftUI

/// La palette : un champ, puis les cartes de zaaps (rien de tapé) ou la liste
/// des résultats, et la ligne des touches. Le clavier est géré par le panneau
/// (`PanneauPalette`) ; la vue ne fait que montrer la sélection.
struct PaletteVue: View {
    @ObservedObject var modele = PaletteModele.shared
    @ObservedObject private var quetes = QuetesStore.shared
    @ObservedObject private var almanax = AlmanaxStore.shared
    @ObservedObject private var carte = CarteStore.shared
    /// Le détail d'un donjon arrive après l'ouverture : ↵ et les cartes de sa fiche changent.
    @ObservedObject private var donjons = DonjonsStore.shared
    @FocusState private var champ: Champ?
    @State private var filtreSurvole: FiltrePalette?
    @State private var prefixeSurvole: String?
    @State private var triSurvole = false

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
                .font(Jetons.Typo.titre.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
            TextField(L("palette.invite"), text: $modele.requete)
                .textFieldStyle(.plain)
                .font(Jetons.Typo.titre.police)
                .focused($champ, equals: .recherche)
                .help(L("raccourcis.palette.aide"))
            origine
            if let mode {
                Text(mode)
                    .font(Jetons.Typo.raccourci.police)
                    .foregroundStyle(EtatVisuel.courant.encre)
                    .padding(.horizontal, Jetons.Espace.deux)
                    .frame(height: Jetons.Taille.cibleMin)
                    .fondEtat(.courant, rayon: Jetons.Rayon.capsule)
            }
        }
        .padding(.horizontal, Jetons.Espace.quatre)
        .frame(height: Jetons.Taille.rangeePalette + Jetons.Espace.quatre)
    }

    /// D'où partent distances et trajets : le dernier perso lu devant, pas forcément celui qu'on
    /// croit quand on joue plusieurs comptes. Position inconnue : le geste qui la rend.
    @ViewBuilder
    private var origine: some View {
        switch modele.causeOrigine {
        case .connue:
            Label(modele.origine, systemImage: "location")
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
                .lineLimit(1)
                .fixedSize()
                .help(L("palette.depuis.aide"))
        case .lectureEteinte:
            boutonOrigine(L("palette.origine.lire"), aide: L("palette.origine.lire.aide")) {
                SettingsWindowController.shared.show(section: .lecture)
            }
        case .sansAutorisation:
            boutonOrigine(L("palette.origine.autoriser"), aide: L("palette.origine.autoriser.aide")) {
                WindowPreviewService.shared.requestAuthorization()
            }
        case .inconnue:
            boutonOrigine(L("palette.depuis.inconnue"), aide: L("palette.origine.inconnue.aide")) { modele.lirePosition() }
        }
    }

    private func boutonOrigine(_ titre: String, aide: String, _ geste: @escaping () -> Void) -> some View {
        Button(action: geste) {
            Label(titre, systemImage: "location")
                .font(Jetons.Typo.petit.police)
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(.bouton(.tertiaire, dense: true))
        .focusable(false)
        .help(aide)
    }

    /// Les familles que Tab fait défiler, les préfixes des commandes et des
    /// variables, et le tri (⌘T).
    private var filtres: some View {
        HStack(spacing: Jetons.Espace.un) {
            ForEach(FiltrePalette.allCases, id: \.self) { filtre in
                let choisi = modele.filtre == filtre
                // Le filtre est le niveau au-dessus des résultats, que les flèches parcourent : son choix est gris.
                let etat: EtatVisuel = choisi ? .inactif : EtatVisuel(survole: filtreSurvole == filtre)
                // Tab et ⇧Tab parcourent les filtres (le panneau) : aucun d'eux ne prend le focus.
                Button { modele.choisir(filtre) } label: {
                    Text(filtre.titre)
                        .font((choisi ? Jetons.Typo.raccourci : Jetons.Typo.petit).police)
                        .foregroundStyle(choisi ? etat.encre : etat.encreSecondaire)
                        .padding(.horizontal, Jetons.Espace.deux)
                        .frame(height: Jetons.Taille.cibleMin)
                        .fondEtat(etat, rayon: Jetons.Rayon.capsule)
                }
                .buttonStyle(.plain)
                .elementDeGroupe()
                .onHover { filtreSurvole = $0 ? filtre : nil }
                .accessibilityAddTraits(choisi ? .isSelected : [])
            }
            ToucheRaccourci("⇥")
                .padding(.leading, Jetons.Espace.un)
                .help(L("palette.touche.filtre"))
            prefixe("/", L("palette.touche.commandes"))
            prefixe("%", L("palette.touche.variables"))
            Spacer(minLength: Jetons.Espace.deux)
            tri
            ToucheRaccourci("⌘T")
        }
        .padding(.horizontal, Jetons.Espace.quatre)
        .padding(.bottom, Jetons.Espace.deux)
    }

    /// Le tri courant, en capsule comme les préfixes : un clic ouvre les quatre, ⌘T passe au suivant.
    private var tri: some View {
        let etat = EtatVisuel(survole: triSurvole)
        return Menu {
            Picker(L("palette.tri.titre"), selection: Binding(get: { modele.tri }, set: { modele.choisirTri($0) })) {
                ForEach(TriPalette.allCases, id: \.self) { Text($0.titre).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Label(modele.tri.titre, systemImage: "arrow.up.arrow.down")
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(etat.encreSecondaire)
                .padding(.horizontal, Jetons.Espace.deux)
                .frame(height: Jetons.Taille.cibleMin)
                .fondEtat(etat, rayon: Jetons.Rayon.capsule)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .focusable(false)
        .onHover { triSurvole = $0 }
        .help(L("palette.tri.aide"))
    }

    /// Un préfixe de la recherche, dessiné comme un filtre : un clic le pose
    /// dans le champ, qui garde le clavier.
    private func prefixe(_ texte: String, _ aide: String) -> some View {
        let etat = EtatVisuel(survole: prefixeSurvole == texte)
        return Button {
            modele.requete = texte
            champ = .recherche
        } label: {
            Text(texte)
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(etat.encreSecondaire)
                .padding(.horizontal, Jetons.Espace.deux)
                .frame(height: Jetons.Taille.cibleMin)
                .fondEtat(etat, rayon: Jetons.Rayon.capsule)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { prefixeSurvole = $0 ? texte : nil }
        .help(aide)
        .accessibilityLabel(aide)
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
        if let vide = modele.vide {
            videVue(vide)
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

    /// La liste vide dit pourquoi, et propose ce qui répare.
    private func videVue(_ vide: VidePalette) -> some View {
        VStack(spacing: Jetons.Espace.deux) {
            switch vide {
            case .carteEnChargement:
                ProgressView().controlSize(.small)
                texteVide(L("palette.carte.chargement"))
            case .carteIndisponible:
                texteVide(L("palette.carte.indisponible"))
                Button(L("palette.carte.reessayer")) { carte.reessayer() }
                    .buttonStyle(.bouton(.secondaire))
            case .quetesEnChargement:
                texteVide(L("palette.quetes.chargement"))
            case .iciSansLecture:
                texteVide(L("palette.ici.sansPosition"))
            case .iciPasEncoreLu:
                texteVide(L("palette.ici.pasEncore"))
            case .rienDansLeFiltre(let filtre, let ailleurs):
                texteVide(L("palette.vide.filtre", filtre.titre))
                Button { modele.choisir(.tout) } label: {
                    Text(L("palette.vide.ailleurs", nombre: ailleurs, ailleurs, FiltrePalette.tout.titre))
                        .font(Jetons.Typo.corps.police)
                        .foregroundStyle(EtatVisuel.choisi.encre)
                        .padding(.horizontal, Jetons.Espace.trois)
                        .frame(height: Jetons.Taille.rangee)
                        .fondEtat(.choisi)
                }
                .buttonStyle(.plain)
            case .aucun:
                texteVide(L("palette.aucun"))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private func texteVide(_ texte: String) -> some View {
        Text(texte)
            .font(Jetons.Typo.corps.police)
            .foregroundStyle(Color.jeton(\.encreSecondaire))
            .multilineTextAlignment(.center)
    }

    /// Les dernières copies, en pastilles : un clic recopie.
    private var recents: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Jetons.Espace.un) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(Color.jeton(\.encreSecondaire))
                ForEach(modele.recents) { entree in
                    Text(entree.titre)
                        .font(Jetons.Typo.codeInterface.police)
                        .lineLimit(1)
                        .padding(.horizontal, Jetons.Espace.deux)
                        .frame(height: Jetons.Taille.cibleMin)
                        .background(Capsule().fill(Color.jeton(\.creux)))
                        .onTapGesture { modele.executer(entree) }
                        .help(entree.titre)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .font(Jetons.Typo.petit.police)
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
                    .font(Jetons.Typo.note.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .lineLimit(1)
                TextField(L("palette.etiquette.exemple"), text: $modele.texteEtiquette)
                    .textFieldStyle(.roundedBorder)
                    .font(Jetons.Typo.note.police)
                    .focused($champ, equals: .etiquette)
                ToucheRaccourci("↵")
                ToucheRaccourci("esc")
            }
            .padding(.horizontal, Jetons.Espace.quatre)
            .frame(height: Jetons.Taille.rangeePalette + Jetons.Espace.un)
        } else {
            HStack(spacing: Jetons.Espace.trois) {
                if let vide = modele.vide {
                    switch vide.entree {
                    case .reessayer: aide("↵", L("palette.carte.reessayer"))
                    case .toutVoir: aide("↵", FiltrePalette.tout.titre)
                    case nil: EmptyView()
                    }
                } else {
                    aide("↵", entree)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    aide("⌘E", L("palette.touche.etiquette"))
                    aide("⌘D", L("palette.touche.favori"))
                }
                Spacer()
                aide("esc", L("palette.touche.fermer"))
            }
            .font(Jetons.Typo.petit.police)
            .foregroundStyle(Color.jeton(\.encreSecondaire))
            .padding(.horizontal, Jetons.Espace.quatre)
            .frame(height: Jetons.Taille.rangeePalette)
        }
    }

    /// Ce qu'Entrée fera de la sélection, en un verbe.
    private var entree: String {
        guard modele.entrees.indices.contains(modele.selection) else { return L("palette.touche.copier") }
        let entree = modele.entrees[modele.selection]
        if entree.id == modele.deplie {
            return modele.cartes.valide(modele.carte).map(aide) ?? L("palette.touche.replier")
        }
        switch entree.effet {
        case .copier, .trajet: return L("palette.touche.copier")
        case .completer: return L("palette.touche.completer")
        case .action: return L("palette.touche.faire")
        case .basculer: return L("palette.touche.basculer")
        case .ouvrirQuete: return L("palette.touche.ouvrir")
        case .ouTrouver: return L("palette.touche.ouTrouver")
        case .donjon: return L("palette.touche.deplier")
        }
    }

    private func aide(_ action: ActionFiche) -> String {
        switch action {
        case .entree(let lieu): return L("palette.touche.copier")
        case .guide: return L("palette.touche.ouvrir")
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

/// Une carte de zaap : nom et zone en haut, étiquette et coordonnées en bas. Sur l'image de la
/// carte, le texte est clair ; sans image, il prend les encres du thème.
private struct CarteZaap: View {
    let entree: EntreePalette
    let choisie: Bool
    @ObservedObject private var prefs = Preferences.shared

    private var etat: EtatVisuel { choisie ? .choisi : .repos }
    private var surImage: Bool { FondCarte.surImage(entree.carte) }
    private var encre: Color { surImage ? Color.jeton(\.encre, en: .sombre) : etat.encre }
    private var encreSecondaire: Color { surImage ? Color.jeton(\.encreSecondaire, en: .sombre) : etat.encreSecondaire }

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entree.titre)
                    .font(Jetons.Typo.corpsFort.police)
                    .foregroundStyle(encre)
                    .lineLimit(1)
                    .padding(.trailing, entree.favori ? Jetons.Espace.quatre : 0)
                Text(entree.itineraire ?? entree.sousTitre ?? "")
                    .font(Jetons.Typo.petit.police)
                    .foregroundStyle(encreSecondaire)
                    .lineLimit(1)
            }
            Spacer(minLength: Jetons.Espace.quatre)
            HStack(spacing: Jetons.Espace.un) {
                if let etiquette = entree.etiquette { PastilleEtiquette(texte: etiquette) }
                Spacer(minLength: 0)
                Text(entree.detail ?? "")
                    .font(Jetons.Typo.codeInterface.police)
                    .foregroundStyle(encreSecondaire)
                    .lineLimit(1)
            }
            .frame(minHeight: Jetons.Espace.quatre)
        }
        .padding(Jetons.Espace.deux)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            if entree.favori {
                Image(systemName: "star.fill").font(Jetons.Typo.micro.police)
                    .foregroundStyle(surImage ? Color.jeton(\.safran) : Color.jeton(\.safranTexte))
                    .padding(Jetons.Espace.deux)
            }
        }
        .background { FondCarte(carte: entree.carte, choisie: choisie) }
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
            Group {
                if case .basculer = entree.effet {
                    EmblemeClasse(classe: entree.classe, contour: Color.jeton(\.filet))
                } else {
                    PictogrammeLieu(gfx: entree.pictogramme) {
                        Image(systemName: icone)
                            .font(Jetons.Typo.corps.police)
                            .foregroundStyle(choisie ? Color.jeton(\.primaireEncre) : Color.jeton(\.encreSecondaire))
                    }
                }
            }
            .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
            .frame(width: Jetons.Taille.rangee, height: Jetons.Taille.rangee)
            // Le carré teinté de l'icône ; sur la rangée choisie, qui l'est déjà, il passe en `surface`.
            .background(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille, style: .continuous)
                .fill(Color.jeton(choisie ? \.surface : \.primaireFond)))
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                HStack(spacing: Jetons.Espace.un) {
                    Text(entree.titre).font(Jetons.Typo.corps.police).foregroundStyle(etat.encre).lineLimit(1)
                    if let etiquette = entree.etiquette { PastilleEtiquette(texte: etiquette) }
                    if entree.favori {
                        Image(systemName: "star.fill").font(Jetons.Typo.micro.police).foregroundStyle(Color.jeton(\.safranTexte))
                    }
                    if entree.interieur { EtiquetteInterieur(taille: .petit) }
                }
                if entree.sousTitre != nil || entree.itineraire != nil {
                    HStack(spacing: Jetons.Espace.un) {
                        if let sousTitre = entree.sousTitre { Text(sousTitre).foregroundStyle(etat.encreSecondaire) }
                        // Le zaap retenu, à lire avant d'Entrée : le trajet copié y passe.
                        if let itineraire = entree.itineraire {
                            if entree.sousTitre != nil { Text("·").foregroundStyle(etat.encreSecondaire) }
                            Text(itineraire).foregroundStyle(Color.jeton(\.primaireEncre)).layoutPriority(1)
                        }
                    }
                    .font(Jetons.Typo.petit.police)
                    .lineLimit(1)
                }
            }
            Spacer(minLength: Jetons.Espace.deux)
            if let detail = entree.detail {
                Text(detail)
                    .font(Jetons.Typo.codeInterface.police)
                    .foregroundStyle(etat.encreSecondaire)
                    .lineLimit(1)
            }
            if let touche = entree.touche { ToucheRaccourci(touche) }
            if let carte = entree.carte { MiniatureCarte(carte: carte, taille: Self.vignette) }
            if entree.effet.sePlie {
                Image(systemName: deplie ? "chevron.down" : "chevron.right")
                    .font(Jetons.Typo.raccourci.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .frame(width: Jetons.Taille.case)
            }
        }
        .padding(.horizontal, Jetons.Espace.deux)
        .padding(.vertical, Jetons.Espace.un)
        .fondEtat(etat)
        .onHover { survole = $0 }
    }

    private var etat: EtatVisuel { choisie ? .choisi : EtatVisuel(survole: survole) }

    /// À la hauteur d'une ligne de deux textes : la liste ne s'allonge pas.
    private static let vignette = CGSize(width: 46, height: 32)

    private var icone: String {
        if let symbole = entree.symbole { return symbole }
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
            .font(taille.police)
            .foregroundStyle(Color.jeton(\.encreSecondaire))
            .padding(.horizontal, Jetons.Espace.un)
            .overlay(Capsule().strokeBorder(Color.jeton(\.contourControle), lineWidth: Jetons.Trait.filet))
            .lineLimit(1)
            .help(L("carte.interieur.aide"))
    }
}

struct PastilleEtiquette: View {
    let texte: String

    var body: some View {
        Text(texte)
            .font(Jetons.Typo.raccourci.police)
            .foregroundStyle(Color.jeton(\.nuitProfond))
            .padding(.horizontal, Jetons.Espace.un)
            .background(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille).fill(Color.jeton(\.safran)))
            .lineLimit(1)
    }
}
