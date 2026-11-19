import SwiftUI

/// La palette : un champ, puis les cartes de la vue (rien de tapé) ou la liste
/// des résultats, et la ligne des touches. Le clavier est géré par le panneau
/// (`PanneauPalette`) ; la vue ne fait que montrer la sélection.
struct PaletteVue: View {
    @ObservedObject var modele = PaletteModele.shared
    @ObservedObject private var almanax = AlmanaxStore.shared
    @ObservedObject private var carte = CarteStore.shared
    /// Le détail d'un donjon arrive après l'ouverture : ↵ et les cartes de sa fiche changent.
    @ObservedObject private var donjons = DonjonsStore.shared
    @FocusState private var champ: Champ?

    private enum Champ { case recherche, etiquette }

    /// Trois rangées de cartes entières et leurs interstices, puis le haut de la quatrième : la grille
    /// dit qu'elle défile.
    static let hauteurCartes = 3 * CarteZaap<Never>.hauteur() + 3 * Jetons.espace2 + Jetons.espace5

    var body: some View {
        VStack(spacing: Jetons.espace2) {
            recherche
            filtres
            resultats
            pied
        }
        .padding(Jetons.espace2)
        .frame(width: PalettePanel.largeur)
        .surfaceFlottante()
        .onAppear { champ = .recherche }
        .onChange(of: modele.ouverture) { _, _ in champ = .recherche }
        .onChange(of: modele.edition) { _, edition in champ = edition == nil ? .recherche : .etiquette }
    }

    // MARK: - Champ

    /// Le champ de la palette : la plaque pleine, son filet, l'accent quand il a le clavier.
    private var recherche: some View {
        HStack(spacing: Jetons.espace2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.jeton(\.encre2))
            TextField(L("palette.invite"), text: $modele.requete, prompt: Text(L("palette.invite")))
                .textFieldStyle(.plain)
                .focused($champ, equals: .recherche)
                .help(L("palette.invite.aide"))
            origine
            if let mode {
                Text(mode)
                    .font(Jetons.typoMicro.font)
                    .foregroundStyle(EtatVisuel.courant.encre)
                    .padding(.horizontal, Jetons.espace2)
                    .frame(height: Jetons.hauteurCase)
                    .fondEtat(.courant, rayon: Jetons.rayonPilule)
            }
        }
        .font(Jetons.typoCorps.font)
        .padding(.horizontal, Jetons.espace3)
        .frame(height: Jetons.hauteurRangee + Jetons.espace2)
        .plaquePleine()
        .overlay {
            if champ == .recherche {
                RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
                    .strokeBorder(Color.jeton(\.accent), lineWidth: Jetons.epaisseurFocus)
            }
        }
    }

    /// D'où partent distances et trajets : le dernier perso lu devant, pas forcément celui qu'on
    /// croit quand on joue plusieurs comptes. Position inconnue : le geste qui la rend.
    @ViewBuilder
    private var origine: some View {
        switch modele.causeOrigine {
        case .connue:
            Label(modele.origine, systemImage: "location")
                .font(Jetons.typoMeta.font)
                .foregroundStyle(Color.jeton(\.encre2))
                .lineLimit(1)
                .fixedSize()
                .help(L("palette.depuis.aide"))
        case .lectureEteinte:
            boutonOrigine(L("palette.origine.lire"), aide: L("palette.origine.lire.aide")) {
                SettingsWindowController.shared.show(section: .lecture)
            }
        case .sansAutorisation:
            boutonOrigine(L("autorisation.lectureEcran"), aide: L("palette.origine.autoriser.aide")) {
                WindowPreviewService.shared.requestAuthorization()
            }
        case .inconnue:
            boutonOrigine(L("palette.depuis.inconnue"), aide: L("palette.origine.inconnue.aide")) { modele.lirePosition() }
        }
    }

    private func boutonOrigine(_ titre: String, aide: String, _ geste: @escaping () -> Void) -> some View {
        Button(action: geste) {
            Label(titre, systemImage: "location")
                .font(Jetons.typoMeta.font)
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(BoutonTertiaire())
        .focusable(false)
        .help(aide)
    }

    /// Les familles que Tab fait défiler, en puces ; le tri, un bouton-icône (⌘T).
    private var filtres: some View {
        HStack(spacing: Jetons.espace2) {
            HStack(spacing: Jetons.espace2) {
                ForEach(modele.jeu, id: \.self) { filtre in
                    let choisi = modele.filtre == filtre
                    // Tab et ⇧Tab parcourent les filtres (le panneau) : aucun d'eux ne prend le focus.
                    Button { modele.choisir(filtre) } label: {
                        Puce(libelle: filtre.titre(enRecherche: modele.enRecherche), choisie: choisi)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .curseurDeClic(true)
                    .elementDeGroupe()
                    .accessibilityAddTraits(choisi ? .isSelected : [])
                }
            }
            .help(L("palette.touche.filtre"))
            Spacer(minLength: Jetons.espace2)
            if modele.triAgit { tri }
        }
        .padding(.horizontal, Jetons.espace1)
    }

    /// Le tri courant : un clic ouvre les choix, ⌘T passe au suivant.
    private var tri: some View {
        let aide = L("palette.tri.bouton", modele.triAffiche.titre)
        return Menu {
            Picker(L("palette.tri.titre"), selection: Binding(get: { modele.triAffiche }, set: { modele.choisirTri($0) })) {
                ForEach(modele.tris, id: \.self) { Text($0.titre).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Label(aide, systemImage: "list.bullet")
        }
        .menuIcone()
        .focusable(false)
        .aide(aide)
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
                    VStack(alignment: .leading, spacing: Jetons.espace2) {
                        if modele.surAlmanax { semaineAlmanax }
                        if modele.enGrille { grille } else if !modele.surAlmanax { liste.padding(Jetons.espace1) }
                    }
                }
                // Une liste se lit sur sa plaque ; les cartes (accueil, almanax) sont chacune la leur.
                .background { if !modele.enCartes, !modele.surAlmanax { RoundedRectangle(cornerRadius: Jetons.rayon2).fill(.clear).plaquePleine() } }
                .clipShape(RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular))
                .frame(height: modele.enCartes ? Self.hauteurCartes
                       : modele.deplie != nil ? 380 : min(CGFloat(modele.entrees.count) * 44 + Jetons.espace4, 380))
                .onChange(of: modele.selection) { _, index in
                    if modele.surAlmanax { return defilement.scrollTo(AlmanaxSemaineVue.ancre(index)) }
                    guard modele.entrees.indices.contains(index) else { return }
                    defilement.scrollTo(modele.entrees[index].id)
                }
                // Cartes et liste n'ont pas la même hauteur : la sélection reste à l'écran quand la fiche s'ouvre ou se ferme.
                .onChange(of: modele.deplie) { _, _ in
                    guard modele.entrees.indices.contains(modele.selection) else { return }
                    defilement.scrollTo(modele.entrees[modele.selection].id)
                }
                .onChange(of: modele.carte) { _, carte in
                    guard let carte else { return }
                    defilement.scrollTo(FicheDonjonVue.ancre(carte))
                }
                // Une rangée de positions défile d'elle-même : la liste n'a qu'à montrer la ligne et la rangée.
                .onChange(of: modele.position) { _, position in
                    guard position != nil, let deplie = modele.deplie else { return }
                    defilement.scrollTo(deplie, anchor: .top)
                }
            }
        }
    }

    private var semaineAlmanax: some View {
        AlmanaxSemaineVue(semaine: almanax.semaine(), selection: modele.selection, deplie: modele.almanaxDeplie,
                          copier: { modele.copierOffrande($0) }, deplier: { modele.deplierAlmanax($0) },
                          allerAuSanctuaire: modele.sanctuaire.map { lieu in { modele.copierTrajet(vers: lieu) } })
    }

    /// La liste vide dit pourquoi, et propose ce qui répare : l'état vide de la trousse, sur la plaque.
    @ViewBuilder
    private func videVue(_ vide: VidePalette) -> some View {
        Group {
            switch vide {
            case .carteEnChargement:
                ProgressView().controlSize(.small).help(L("palette.carte.chargement"))
            case .carteIndisponible:
                EtatVide(L("palette.carte.indisponible"), symbole: "exclamationmark.triangle", ton: .danger) {
                    Button { carte.reessayer() } label: { Label(L("palette.carte.reessayer"), systemImage: "arrow.clockwise") }
                }
            case .quetesEnChargement:
                ProgressView().controlSize(.small).help(L("palette.quetes.chargement"))
            case .rienDansLeFiltre(let filtre, let ailleurs):
                EtatVide(L("palette.vide.filtre", filtre.titre), symbole: "magnifyingglass") {
                    Button(L("palette.vide.rechercherDans", FiltrePalette.tout.titre)) { modele.choisir(.tout) }
                        .help(L("palette.vide.ailleurs", nombre: ailleurs, ailleurs, FiltrePalette.tout.titre))
                }
            case .aucun:
                EtatVide(L("palette.aucun"), symbole: "magnifyingglass")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Jetons.hauteurRangee * 4 + Jetons.espace4)
        .plaquePleine()
    }

    private var grille: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Jetons.espace2), count: PaletteModele.colonnes),
                  spacing: Jetons.espace2) {
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
        LazyVStack(spacing: Jetons.espace1) {
            ForEach(Array(modele.entrees.enumerated()), id: \.element.id) { index, entree in
                let deplie = modele.deplie == entree.id
                // Le clavier dans la fiche : la ligne ne se dit plus choisie, la carte l'est.
                LigneResultat(entree: entree, choisie: index == modele.selection && modele.carte == nil && modele.position == nil, deplie: deplie,
                              deplier: entree.pnj == nil ? nil : { modele.deplier(entree) })
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
                        default: if entree.pnj != nil { PositionsPNJVue(modele: modele) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, Jetons.espace7)
                    .padding(.bottom, Jetons.espace1)
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
            HStack(spacing: Jetons.espace2) {
                Text(L("palette.etiquette.pour", edition.titre))
                    .font(Jetons.typoMeta.font)
                    .foregroundStyle(Color.jeton(\.encre2))
                    .lineLimit(1)
                TextField(L("palette.etiquette.exemple"), text: $modele.texteEtiquette)
                    .textFieldStyle(.roundedBorder)
                    .font(Jetons.typoMeta.font)
                    .focused($champ, equals: .etiquette)
                ToucheDeClavier(touche: "↵")
                ToucheDeClavier(touche: "esc")
            }
            .padding(.horizontal, Jetons.espace2)
            .frame(height: Jetons.hauteurRangee)
        } else {
            HStack(spacing: Jetons.espace3) {
                if let vide = modele.vide {
                    switch vide.entree {
                    case .reessayer: aide("↵", L("palette.carte.reessayer"))
                    case .toutVoir: aide("↵", FiltrePalette.tout.titre)
                    case nil: EmptyView()
                    }
                } else {
                    aide("↵", entree)
                        .layoutPriority(1)
                    if let texte = modele.texteDeLaSelection {
                        Text(texte)
                            .font(Jetons.typoCode.font)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(texte)
                    }
                    if !modele.surAlmanax {
                        aide("⌘E", L("palette.touche.etiquette"))
                            .layoutPriority(1)
                        aide("⌘D", L("palette.touche.favori"))
                            .layoutPriority(1)
                    }
                }
                Spacer(minLength: 0)
                aide("esc", L("palette.touche.fermer"))
                    .layoutPriority(1)
            }
            .font(Jetons.typoMeta.font)
            .foregroundStyle(Color.jeton(\.encre2))
            .padding(.horizontal, Jetons.espace2)
            .frame(height: Jetons.hauteurCase)
        }
    }

    /// Ce qu'Entrée fera de la sélection, en un verbe.
    private var entree: String {
        guard modele.entrees.indices.contains(modele.selection) else { return L("palette.touche.copier") }
        let entree = modele.entrees[modele.selection]
        if entree.id == modele.deplie {
            if modele.cartesPositions.valide(modele.position) != nil { return L("palette.touche.copier") }
            return modele.cartes.valide(modele.carte).map(aide) ?? L("palette.touche.replier")
        }
        switch entree.effet {
        case .copier, .trajet: return L("palette.touche.copier")
        case .completer: return L("palette.touche.completer")
        case .action: return L("palette.touche.faire")
        case .basculer: return L("palette.touche.basculer")
        case .ouvrirQuete: return L("palette.touche.ouvrir")
        case .ouTrouver: return L("palette.touche.ouTrouver")
        case .donjon, .positions: return L("palette.touche.deplier")
        }
    }

    private func aide(_ action: ActionFiche) -> String {
        switch action {
        case .entree: return L("palette.touche.copier")
        case .guide, .aide: return L("palette.touche.ouvrir")
        case .clef, .conseils, .monstres, .succes:
            return modele.ouvertes.contains(action) ? L("palette.touche.replier") : L("palette.touche.deplier")
        }
    }

    private func aide(_ touche: String, _ texte: String) -> some View {
        HStack(spacing: Jetons.espace1) {
            ToucheDeClavier(touche: touche)
            Text(texte)
        }
    }
}

/// Une carte de la palette (zaap, lieu, donjon, PNJ, quête), pleine : titre et sous-titre, la vignette de
/// la carte du jeu à droite, puis l'étiquette, le favori et les coordonnées. Toutes les cartes d'une
/// grille ont la même hauteur (`hauteur`) : le titre sur deux lignes au plus, coupé en fin, le
/// sous-titre et le pied sur une. Choisie, le fond du choix et son titre à l'accent.
struct CarteZaap<Corps: View>: View {
    let entree: EntreePalette
    let choisie: Bool
    /// Ce qui prend la place entre l'en-tête et le pied (les quêtes d'une position), sur une ligne.
    private let corps: (() -> Corps)?
    @State private var survole = false

    init(entree: EntreePalette, choisie: Bool, @ViewBuilder corps: @escaping () -> Corps) {
        (self.entree, self.choisie, self.corps) = (entree, choisie, corps)
    }

    /// La hauteur d'une carte : deux lignes de titre, une de sous-titre, le pied, leurs interstices et
    /// la marge — et la ligne du corps quand la carte en a un.
    static func hauteur(avecCorps: Bool = false) -> CGFloat {
        let texte = 2 * Jetons.typoTitreCarte.interligne + Jetons.typoMeta.interligne
        let corps = avecCorps ? Jetons.typoMeta.interligne + Jetons.espace1 : 0
        return 2 * Jetons.espace2 + texte + Jetons.espace1 + corps + Jetons.espace1 + Jetons.hauteurCase
    }

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            HStack(alignment: .top, spacing: Jetons.espace2) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entree.titre)
                        .font(Jetons.typoTitreCarte.font)
                        .foregroundStyle(Color.jeton(choisie ? \.accentTexte : \.encre))
                        .lineLimit(2)
                        .truncationMode(.tail)
                    Text(entree.itineraire ?? entree.sousTitre ?? "")
                        .font(Jetons.typoMeta.font)
                        .foregroundStyle(Color.jeton(entree.itineraire != nil ? \.accentTexte : \.encre2))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let carte = entree.carte { MiniatureCarte(carte: carte, taille: LigneResultat.vignette) }
            }
            if let corps { corps() }
            Spacer(minLength: 0)
            pied
        }
        .padding(.vertical, Jetons.espace2)
        .padding(.horizontal, Jetons.espace3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.hauteur(avecCorps: corps != nil))
        // Le fond du choix et le survol se posent sur la plaque, sous le texte.
        .background {
            ZStack {
                forme.fill(Color.jeton(\.plaque))
                if choisie || survole { forme.fill(Color.jeton(choisie ? \.selection : \.survol)) }
            }
        }
        .overlay { forme.strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.epaisseurFilet) }
        .contentShape(forme)
        .onHover { survole = $0 }
    }

    /// L'étiquette et le favori à gauche, « intérieur » et les coordonnées à droite, sur une ligne :
    /// les coordonnées ne se coupent jamais, l'étiquette cède et se coupe en fin.
    private var pied: some View {
        HStack(spacing: Jetons.espace2) {
            // L'étiquette en une ligne micro, sans pastille : elle aide à reconnaître la carte, elle
            // n'a pas à peser plus que son titre.
            if let etiquette = entree.etiquette {
                Text(etiquette)
                    .font(Jetons.typoMicro.font)
                    .foregroundStyle(Color.jeton(\.accentTexte))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if entree.favori {
                Image(systemName: "star.fill").font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.accentTexte))
            }
            Spacer(minLength: 0)
            if entree.interieur { EtiquetteInterieur(taille: Jetons.typoMicro) }
            Text(entree.detail ?? "")
                .font(Jetons.typoCode.font)
                .foregroundStyle(Color.jeton(\.encre2))
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: Jetons.hauteurCase)
    }
}

extension CarteZaap where Corps == Never {
    init(entree: EntreePalette, choisie: Bool) {
        (self.entree, self.choisie, self.corps) = (entree, choisie, nil)
    }
}

/// Une ligne de résultat : genre (ou pictogramme du lieu), titre, étiquette,
/// sous-titre, détail, vue de la carte.
struct LigneResultat: View {
    let entree: EntreePalette
    let choisie: Bool
    var deplie = false
    /// Le clic sur le chevron d'une ligne qui ne se déplie pas d'Entrée (un PNJ à une position).
    var deplier: (() -> Void)?
    @State private var survole = false

    var body: some View {
        HStack(spacing: Jetons.espace3) {
            Group {
                if case .basculer = entree.effet {
                    EmblemeClasse(classe: entree.classe, contour: Color.jeton(\.filet))
                } else {
                    PictogrammeLieu(gfx: entree.pictogramme) {
                        Image(systemName: icone)
                            .font(Jetons.typoCorps.font)
                            .foregroundStyle(choisie ? Color.jeton(\.accentTexte) : Color.jeton(\.encre2))
                    }
                }
            }
            .frame(width: Jetons.tailleIcone, height: Jetons.tailleIcone)
            .frame(width: Jetons.hauteurControle, height: Jetons.hauteurControle)
            // Le rond `creux` de l'icône ; sur la rangée choisie, qui l'est déjà, il passe en `plaque`.
            .background(Circle().fill(Color.jeton(choisie ? \.plaque : \.creux)))
            VStack(alignment: .leading, spacing: Jetons.espace1) {
                HStack(spacing: Jetons.espace1) {
                    Text(entree.titre).font(Jetons.typoCorps.font).foregroundStyle(Color.jeton(\.encre)).lineLimit(1)
                    if let etiquette = entree.etiquette { Badge(texte: etiquette, ton: .accent) }
                    if entree.favori {
                        Image(systemName: "star.fill").font(Jetons.typoMicro.font).foregroundStyle(Color.jeton(\.accentTexte))
                    }
                    if entree.interieur { EtiquetteInterieur(taille: Jetons.typoMeta) }
                }
                if entree.sousTitre != nil || entree.itineraire != nil {
                    HStack(spacing: Jetons.espace1) {
                        if let sousTitre = entree.sousTitre { Text(sousTitre).foregroundStyle(Color.jeton(\.encre2)) }
                        // Le zaap retenu, à lire avant d'Entrée : le trajet copié y passe.
                        if let itineraire = entree.itineraire {
                            if entree.sousTitre != nil { Text("·").foregroundStyle(Color.jeton(\.encre2)) }
                            Text(itineraire).foregroundStyle(Color.jeton(\.accentTexte)).layoutPriority(1)
                        }
                    }
                    .font(Jetons.typoMeta.font)
                    .lineLimit(1)
                }
            }
            Spacer(minLength: Jetons.espace2)
            if let detail = entree.detail {
                Text(detail)
                    .font(Jetons.typoMeta.font.monospaced())
                    .foregroundStyle(Color.jeton(\.encre2))
                    .lineLimit(1)
            }
            if let touche = entree.touche { ToucheDeClavier(touche: touche) }
            if let carte = entree.carte { MiniatureCarte(carte: carte, taille: Self.vignette) }
            if entree.effet.sePlie || deplier != nil {
                let chevron = Image(systemName: deplie ? "chevron.down" : "chevron.right")
                    .font(Jetons.typoMicro.font)
                    .foregroundStyle(Color.jeton(\.encre3))
                    .frame(width: Jetons.tailleIcone)
                if let deplier {
                    Button(action: deplier) { chevron.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .focusable(false)
                } else {
                    chevron
                }
            }
        }
        .padding(.horizontal, Jetons.espace2)
        .padding(.vertical, Jetons.espace1)
        .frame(minHeight: Jetons.hauteurRangee)
        .fondEtat(etat, rayon: Jetons.rayon2)
        .onHover { survole = $0 }
    }

    private var etat: EtatVisuel { choisie ? .choisi : EtatVisuel(survole: survole) }

    /// La vignette d'une carte du jeu, à la hauteur d'une rangée.
    static let vignette = CGSize(width: Jetons.largeurVignette, height: Jetons.hauteurRangee)

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
            .font(taille.font)
            .foregroundStyle(Color.jeton(\.encre2))
            .padding(.horizontal, Jetons.espace1)
            .overlay(Capsule().strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.epaisseurFilet))
            .lineLimit(1)
            .help(L("carte.interieur.aide"))
    }
}
