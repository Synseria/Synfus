import AppKit
import Combine

/// L'état de la palette : la recherche, la sélection, l'étiquette en cours
/// d'écriture. Ce qui se cherche est dans `RecherchePalette` ; ici, le
/// contexte du moment et ce qu'Entrée déclenche.
@MainActor
final class PaletteModele: ObservableObject {
    static let shared = PaletteModele()

    /// Les cartes de zaaps, quand rien n'est tapé.
    static let colonnes = 3

    @Published var requete = "" {
        didSet {
            guard requete != oldValue else { return }
            selection = 0
            deplie = nil
            changerDeJeu(avant: oldValue)
            recalculer()
        }
    }
    /// L'entrée dont la fiche est dépliée sous la ligne : où trouver un
    /// monstre ou un objet, un donjon.
    @Published private(set) var deplie: String? {
        didSet {
            guard deplie != oldValue else { return }
            carte = nil
            ouvertes = []
        }
    }
    /// La carte de la fiche dépliée où est le clavier ; `nil` : sur la ligne.
    @Published private(set) var carte: ActionFiche?
    /// Les cartes de la fiche dépliée ouvertes (clef, monstres, succès).
    @Published private(set) var ouvertes: Set<ActionFiche> = []
    @Published private(set) var entrees: [EntreePalette] = []
    /// La vue qu'on a quittée en tapant : le champ vidé y ramène.
    private var vueQuittee: FiltrePalette = .tout
    /// La famille montrée, que Tab fait défiler.
    @Published private(set) var filtre: FiltrePalette = .tout {
        didSet {
            guard filtre != oldValue else { return }
            almanaxDeplie = nil
            if filtre == .almanax, contexteImpose == nil { AlmanaxStore.shared.preparer() }
        }
    }
    /// La carte de l'almanax dont « Localiser » est déplié.
    @Published private(set) var almanaxDeplie: Int?
    @Published private(set) var tri: TriPalette = .auto
    /// Ce que « Tout » répondrait à la même recherche, demandé seulement quand la liste d'un filtre
    /// est vide et redemandé à chaque rendu : la clé dit tout ce dont il dépend.
    private var ailleursGarde = DernierCalcul<CleAilleurs, Int>()

    private var positionsGardees = DernierCalcul<ClePositions, [PositionPNJ]>()

    private struct ClePositions: Equatable {
        // periphery:ignore - lu par l'Equatable synthétisé
        let pnj: Int
        // periphery:ignore - lu par l'Equatable synthétisé
        let index: ObjectIdentifier
    }

    private struct CleAilleurs: Equatable {
        // periphery:ignore - lu par l'Equatable synthétisé, que Periphery ne voit pas
        let requete: String
        // periphery:ignore - lu par l'Equatable synthétisé
        let tri: TriPalette
        // periphery:ignore - lu par l'Equatable synthétisé
        let index: ObjectIdentifier
    }
    @Published var selection = 0
    /// L'entrée dont on écrit l'étiquette, et le texte en cours.
    @Published private(set) var edition: EntreePalette?
    @Published var texteEtiquette = ""
    /// Change à chaque ouverture : la vue redonne le clavier au champ.
    @Published private(set) var ouverture = 0
    private var abonnements: Set<AnyCancellable> = []

    private var contexte = ContextePalette() {
        didSet { index = IndexPalette(contexte, connus: champsConnus) }
    }
    private var index = IndexPalette(ContextePalette())
    /// Les textes normalisés de toutes les entrées, gardés d'une ouverture à
    /// l'autre et préparés hors du fil principal (`prechauffer`) : la première
    /// lettre tapée ne paie plus la normalisation de tout le jeu.
    private var champsConnus: [String: RecherchePalette.Champs] = [:]
    private var prechauffe: Task<Void, Never>?
    /// Le contexte imposé (tests, captures de la documentation) ; `nil` : celui
    /// du moment, relu à chaque ouverture.
    private let contexteImpose: ContextePalette?
    /// L'état de la carte imposé avec le contexte ; `nil` : celui de `CarteStore`.
    private let carteImposee: EtatCarte?

    /// La carte et les quêtes arrivent après le lancement, lues ou
    /// téléchargées en tâche de fond : la recherche en cours les reçoit dès
    /// qu'elles sont là, et leurs textes se normalisent d'avance.
    private init() {
        contexteImpose = nil
        carteImposee = nil
        QuetesStore.shared.$quetes
            .dropFirst()
            .sink { quetes in
                MainActor.assumeIsolated {
                    let modele = PaletteModele.shared
                    modele.contexte.quetes = quetes
                    modele.recalculer()
                    modele.prechauffer()
                }
            }
            .store(in: &abonnements)
        DonjonsStore.shared.$donjons
            .dropFirst()
            .sink { donjons in
                MainActor.assumeIsolated {
                    let modele = PaletteModele.shared
                    modele.contexte.donjons = donjons
                    modele.recalculer()
                    modele.prechauffer()
                }
            }
            .store(in: &abonnements)
        // Publiée avant d'être affectée, la carte se relit au tour suivant,
        // avec les zaaps qu'on en tire.
        CarteStore.shared.$carte
            .dropFirst()
            .sink { _ in
                Task { @MainActor in
                    PaletteModele.shared.rafraichir()
                    PaletteModele.shared.prechauffer()
                }
            }
            .store(in: &abonnements)
    }

    /// Normalise d'avance, en tâche de fond, les textes de tout ce que la
    /// palette cherche — quand la carte ou les quêtes arrivent. Une préchauffe
    /// attend la précédente : la dernière, qui voit tout, finit la dernière.
    func prechauffer() {
        guard contexteImpose == nil else { return }
        let precedente = prechauffe
        prechauffe = Task {
            await precedente?.value
            let contexte = Self.contexteCourant()
            let connus = champsConnus
            champsConnus = await Task.detached(priority: .utility) {
                IndexPalette.champs(de: contexte, connus: connus)
            }.value
        }
    }

    /// Une palette hors de l'app, sur un contexte donné.
    init(contexte: ContextePalette, requete: String = "", filtre: FiltrePalette = .tout, carte: EtatCarte = .prete) {
        contexteImpose = contexte
        carteImposee = carte
        self.contexte = contexte
        index = IndexPalette(contexte)
        self.requete = requete
        self.filtre = filtre
        recalculer()
    }

    /// Une recherche est en cours : la rangée montre des portées, sinon des vues.
    var enRecherche: Bool { !requete.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Les capsules de la rangée, que Tab et ⇧Tab parcourent.
    var jeu: [FiltrePalette] { FiltrePalette.jeu(enRecherche: enRecherche) }

    /// À la première lettre la rangée passe des vues aux portées, « Tout » d'office, même depuis une
    /// vue qui porte aussi un nom de portée ; le champ vidé revient à la vue quittée.
    private func changerDeJeu(avant ancienne: String) {
        let etaitVide = ancienne.trimmingCharacters(in: .whitespaces).isEmpty
        if etaitVide, enRecherche {
            vueQuittee = filtre
            filtre = .tout
        } else if !etaitVide, !enRecherche {
            filtre = vueQuittee
        }
    }

    /// Rien de tapé : l'Accueil, « Zaaps », « Donjons », « PNJ » et « Quêtes » se montrent en cartes — jusqu'à
    /// ce qu'une fiche se déplie, qui n'a de place que sous une ligne.
    var enGrille: Bool {
        requete.trimmingCharacters(in: .whitespaces).isEmpty && filtre.enCartes && deplie == nil
    }

    /// La vue « Almanax » : ses sept cartes, pas des entrées.
    var surAlmanax: Bool { requete.trimmingCharacters(in: .whitespaces).isEmpty && filtre == .almanax }

    /// Les flèches vont de carte en carte : la grille, ou la semaine de l'almanax.
    var enCartes: Bool { enGrille || surAlmanax }

    /// Pourquoi la liste est vide ; `nil` quand elle ne l'est pas.
    var vide: VidePalette? {
        guard entrees.isEmpty, !surAlmanax else { return nil }
        let ailleurs = filtre != .tout && !requete.trimmingCharacters(in: .whitespaces).isEmpty
            ? ailleursGarde.valeur(pour: CleAilleurs(requete: requete, tri: triAffiche, index: ObjectIdentifier(index))) {
                RecherchePalette.entrees(requete, index, filtre: .tout, tri: triAffiche).count
            } : 0
        return VidePalette.de(
            carte: carteImposee ?? CarteStore.shared.etat,
            requeteVide: requete.trimmingCharacters(in: .whitespaces).isEmpty, filtre: filtre,
            quetesEnChargement: QuetesStore.shared.chargement && QuetesStore.shared.quetes == nil, ailleurs: ailleurs)
    }

    /// Pourquoi la position manque, s'il lui manque quelque chose.
    var causeOrigine: OriginePalette {
        .de(positionConnue: contexte.position != nil, lectureAllumee: Preferences.shared.lirePosition,
            autorise: WindowPreviewService.shared.authorized)
    }

    /// La position du perso devant, lue tout de suite ; les distances suivent.
    func lirePosition() {
        Task {
            await LecteurEcran.shared.lirePositionDevant()
            rafraichir()
        }
    }

    /// D'où partent distances et trajets : le dernier perso lu devant, à
    /// l'ouverture de la palette.
    var origine: String {
        guard let perso = contexte.perso, let position = contexte.position else { return L("palette.depuis.inconnue") }
        return L("palette.depuis", perso, Coordonnees.texte(position.x, position.y))
    }

    /// La palette s'ouvre toujours sur l'Accueil, champ vide, première carte choisie ; distances
    /// refaites depuis la position du moment. Deux exceptions, celles qui disent où elles vont :
    /// `vue` (l'outil « Almanax » de la barre) et `requete`, une recherche posée d'office
    /// (« Aide au combat »), à compléter.
    func ouvrir(requete posee: String? = nil, vue: FiltrePalette = .tout) {
        requete = posee ?? ""
        filtre = posee == nil ? vue : .tout
        vueQuittee = .tout
        deplie = nil
        almanaxDeplie = nil
        edition = nil
        if contexteImpose == nil {
            QuetesStore.shared.preparer()
            DonjonsStore.shared.charger()
            AlmanaxStore.shared.preparer()
        }
        tri = contexteImpose == nil ? Preferences.shared.paletteTri : tri
        rafraichir()
        selection = 0
        ouverture += 1
    }

    // MARK: - Clavier

    /// Flèches : de carte en carte dans la grille, de ligne en ligne sinon —
    /// en passant par la rangée de cartes de la fiche dépliée.
    func deplacer(colonne: Int = 0, ligne: Int = 0) {
        if surAlmanax { return deplacerAlmanax(colonne: colonne, ligne: ligne) }
        guard !entrees.isEmpty else { return }
        if !enGrille, surLaFiche {
            if ligne > 0, carte == nil, let premiere = cartes.premiere { carte = premiere; return }
            if ligne < 0, carte != nil { return sortir(cartes.versLeHaut) }
        }
        let pas = colonne + ligne * (enGrille ? Self.colonnes : 1)
        let avant = selection
        carte = nil
        selection = min(max(selection + pas, 0), entrees.count - 1)
        // En remontant sur une fiche dépliée, on arrive par ses cartes.
        if ligne < 0, selection != avant, surLaFiche { carte = cartes.premiere }
    }

    /// Une flèche dans la semaine de l'almanax. → au bout d'une ligne déplie « Localiser » ; ← le replie.
    private func deplacerAlmanax(colonne: Int, ligne: Int) {
        if colonne < 0, almanaxDeplie != nil { return deplierAlmanax(nil) }
        let cible = NavigationAlmanax.cible(depuis: selection, colonne: colonne, ligne: ligne)
        if cible != selection {
            selection = cible
            almanaxDeplie = nil
        } else if colonne > 0, AlmanaxStore.shared.semaine()[selection].almanax != nil {
            deplierAlmanax(selection)
        }
    }

    /// « Localiser » sous une carte de l'almanax ; `nil` ou la carte déjà dépliée : replié.
    func deplierAlmanax(_ index: Int?) {
        almanaxDeplie = index == almanaxDeplie ? nil : index
    }

    /// Le nom de l'offrande d'un jour, copié pour l'hôtel de vente.
    func copierOffrande(_ index: Int) {
        let semaine = AlmanaxStore.shared.semaine()
        guard semaine.indices.contains(index), let nom = semaine[index].almanax?.nomOffrande(L10n.courante.langue)
        else { return NSSound.beep() }
        selection = index
        copier(nom)
    }

    /// ← et → hors de la grille : de carte en carte dans la fiche ; ← sur
    /// une ligne dépliée la replie, → sur celle d'un PNJ la déplie. `false` : la flèche reste au champ.
    func lateral(_ pas: Int) -> Bool {
        guard !enGrille, edition == nil, entrees.indices.contains(selection) else { return false }
        guard surLaFiche else {
            guard pas > 0, entrees[selection].pnj != nil else { return false }
            deplier(entrees[selection])
            return true
        }
        if let carte {
            sortir(cartes.lateral(depuis: carte, pas))
            return true
        }
        guard pas < 0 else { return false }
        deplie = nil
        return true
    }

    private func sortir(_ sortie: CartesFiche.Sortie) {
        switch sortie {
        case .carte(let action): carte = action
        case .ligne: carte = nil
        case .replier: deplie = nil
        }
    }

    /// ↵ : la carte choisie de la fiche ; sur la ligne, la déplie (le clavier
    /// arrive sur sa première carte, l'entrée d'un donjon) ou la replie.
    func valider() {
        if edition != nil { return validerEtiquette() }
        if surAlmanax { return copierOffrande(selection) }
        guard entrees.indices.contains(selection) else { return validerVide() }
        if surLaFiche, let action = cartes.valide(carte) { return agir(action) }
        executer(entrees[selection])
    }

    /// ↵ sur une liste vide : le geste que la cause propose, sinon rien.
    private func validerVide() {
        switch vide?.entree {
        case .reessayer: CarteStore.shared.reessayer()
        case .toutVoir: choisir(.tout)
        case nil: NSSound.beep()
        }
    }

    /// Tab : compléter une commande, sinon passer au filtre suivant (⇧Tab :
    /// au précédent).
    func tabulation(arriere: Bool = false) {
        if !arriere, entrees.indices.contains(selection), case .completer(let texte) = entrees[selection].effet {
            requete = texte
            return
        }
        choisir(filtre.suivant(arriere ? -1 : 1, dans: jeu))
    }

    /// Un filtre : Tab, ou un clic sur sa capsule.
    func choisir(_ filtre: FiltrePalette) {
        self.filtre = filtre
        selection = 0
        deplie = nil
        recalculer()
    }

    /// Le tri qui range ce qui est montré : le choix gardé, sauf s'il n'a pas de sens ici.
    var triAffiche: TriPalette { tris.contains(tri) ? tri : .auto }

    /// Les tris proposés par le menu du bouton et par ⌘T.
    var tris: [TriPalette] { filtre.tris(enRecherche: enRecherche) }

    /// Le bouton de tri se montre là où le tri range quelque chose.
    var triAgit: Bool { filtre.triAgit(enRecherche: enRecherche) }

    /// ⌘T : auto, proximité, ordre alphabétique, type — et le choix est gardé. Sans effet là où
    /// le tri ne range rien.
    func triSuivant() {
        guard triAgit else { return }
        choisirTri(triAffiche.suivant(dans: tris))
    }

    /// Un tri, par le menu du bouton ou par ⌘T.
    func choisirTri(_ nouveau: TriPalette) {
        tri = nouveau
        if contexteImpose == nil { Preferences.shared.paletteTri = tri }
        selection = 0
        recalculer()
    }

    /// ⌘E : l'étiquette de la sélection.
    func etiqueterSelection() {
        guard entrees.indices.contains(selection) else { return NSSound.beep() }
        commencerEtiquette(entrees[selection])
    }

    /// ⌘D : la sélection en favori, ou plus.
    func favoriSelection() {
        guard entrees.indices.contains(selection) else { return NSSound.beep() }
        basculerFavori(entrees[selection])
    }

    /// Échap : quitte l'étiquette ; efface la recherche (la vue d'avant revient), puis la vue
    /// pour l'Accueil — une faute de frappe ne fait pas tout reprendre ; sinon ferme.
    func echap() {
        if edition != nil { edition = nil; return }
        if deplie != nil { deplie = nil; return }
        if !requete.isEmpty { requete = ""; return }
        if filtre != .tout { return choisir(.tout) }
        PalettePanel.shared.fermer()
    }

    // MARK: - Effets

    /// Ce qu'Entrée copiera pour cette entrée, trajet calculé depuis le perso devant.
    func texteACopier(_ entree: EntreePalette) -> String? {
        RecherchePalette.texte(de: entree.effet, contexte)
    }

    /// Le texte que ↵ copiera pour la sélection, à lire avant de coller ; `nil` quand ↵ fait autre chose.
    var texteDeLaSelection: String? {
        if surAlmanax {
            let semaine = AlmanaxStore.shared.semaine()
            return semaine.indices.contains(selection) ? semaine[selection].almanax?.nomOffrande(L10n.courante.langue) : nil
        }
        guard entrees.indices.contains(selection) else { return nil }
        if entrees[selection].id == deplie {
            guard case .position(let position)? = cartes.valide(carte) else { return nil }
            return positionsDeplie.first { $0.position == position }.flatMap { RecherchePalette.texte(de: $0.entree.effet, contexte) }
        }
        return texteACopier(entrees[selection])
    }

    /// Un clic : la ligne choisie, puis son effet. Ce qui mène au jeu compte
    /// dans les habitudes (`FrequentationPalette`) — pas une fiche qu'on replie.
    func executer(_ entree: EntreePalette) {
        UsageStore.shared.compter(.palette(entree.genre))
        guard contexteImpose == nil else { return effectuer(entree) }
        let prefs = Preferences.shared
        // Le choix compté et la copie retenue : une seule écriture.
        prefs.enUneEcriture {
            if deplie != entree.id, let cle = FrequentationPalette.cle(de: entree) {
                prefs.paletteFrequentation.noter(cle)
            }
            effectuer(entree)
        }
    }

    private func effectuer(_ entree: EntreePalette) {
        if let index = entrees.firstIndex(where: { $0.id == entree.id }) {
            selection = index
            carte = nil
        }
        switch entree.effet {
        case .copier, .trajet:
            guard let texte = texteACopier(entree) else { return }
            copier(texte)
        case .ouTrouver, .donjon, .positions:
            deplier(entree)
        case .completer(let texte):
            requete = texte
        case .ouvrirQuete(let id):
            PalettePanel.shared.fermer()
            QuetePanel.shared.ouvrir(id)
        case .action(let action):
            PalettePanel.shared.fermer()
            faire(action)
        case .basculer(let slotKey):
            PalettePanel.shared.fermer()
            guard let client = WindowManager.shared.effectif.first(where: { $0.slotKey == slotKey }) else { return }
            WindowManager.shared.focus(client)
        }
    }

    // MARK: - Fiche dépliée

    /// Déplie la fiche de la ligne, le clavier sur sa première carte, ou la replie.
    func deplier(_ entree: EntreePalette) {
        if let index = entrees.firstIndex(where: { $0.id == entree.id }) { selection = index }
        deplie = deplie == entree.id ? nil : entree.id
        carte = cartes.premiere
    }

    /// La sélection est sur la ligne dépliée ou dans sa fiche.
    private var surLaFiche: Bool {
        entrees.indices.contains(selection) && entrees[selection].id == deplie
    }

    /// Les cartes de la fiche dépliée, refaites à chaque lecture : le détail
    /// du donjon arrive après l'ouverture.
    var cartes: CartesFiche {
        guard let deplie, let entree = entrees.first(where: { $0.id == deplie }) else { return .vide }
        if entree.pnj != nil { return .positions(positionsDeplie.map(\.position)) }
        guard case .donjon(let id) = entree.effet, let donjon = DonjonsStore.shared.donjons?.donjon(id: id)
        else { return .vide }
        return .donjon(entree: Self.entree(de: donjon), guide: donjon.nomFrancais,
                       detail: DonjonsStore.shared.details[id], conseils: !(DonjonsStore.shared.conseils[id] ?? []).isEmpty)
    }

    /// Les positions du PNJ de la ligne dépliée ; refaites quand le contexte change (habitudes, position du perso).
    var positionsDeplie: [PositionPNJ] {
        guard let deplie, let pnj = entrees.first(where: { $0.id == deplie })?.pnj else { return [] }
        return positionsGardees.valeur(pour: ClePositions(pnj: pnj, index: ObjectIdentifier(index))) {
            RecherchePalette.positions(de: pnj, contexte)
        }
    }

    /// Le repère de l'entrée d'un donjon sur la carte : par sa carte, sinon par son nom.
    private static func entree(de donjon: Donjon) -> Lieu? {
        let reperes = CarteStore.shared.reperes
        return donjon.entree.flatMap(reperes.donjon(carte:)) ?? donjon.nomFrancais.flatMap(reperes.donjon(nom:))
    }

    /// La carte de la fiche dépliée, à la souris : choisie, puis faite.
    func cliquer(_ action: ActionFiche) {
        if let index = entrees.firstIndex(where: { $0.id == deplie }) { selection = index }
        carte = action
        agir(action)
    }

    func agir(_ action: ActionFiche) {
        switch action {
        case .entree(let lieu): copierTrajet(vers: lieu)
        case .guide(let nom): Task { await DofusPourLesNoobs.ouvrir(nom) }
        case .clef, .conseils, .monstres, .succes:
            if ouvertes.remove(action) == nil { ouvertes.insert(action) }
        case .position(let position): copier(positionDe: position)
        }
    }

    /// Le texte du trajet jusqu'à un lieu, la décision de sa ligne.
    func trajet(vers lieu: Lieu) -> String? {
        RecherchePalette.texte(de: RecherchePalette.versLieu(lieu, contexte).effet, contexte)
    }

    /// Copie le trajet vers une position du PNJ déplié ; elle et le PNJ comptent dans les habitudes.
    private func copier(positionDe position: PNJ.Position) {
        guard let ligne = entrees.first(where: { $0.id == deplie }), let pnj = ligne.pnj, let cle = ligne.cle,
              let cible = positionsDeplie.first(where: { $0.position == position }),
              let texte = RecherchePalette.texte(de: cible.entree.effet, contexte)
        else { return NSSound.beep() }
        UsageStore.shared.compter(.palette(.pnj))
        if contexteImpose == nil {
            let prefs = Preferences.shared
            prefs.enUneEcriture {
                prefs.paletteFrequentation.noter(cle)
                prefs.paletteFrequentation.noter(PNJ.cle(pnj, en: position))
            }
        }
        copier(texte)
    }

    /// Le Sanctuaire de l'Almanax, s'il est sur la carte.
    var sanctuaire: Lieu? { CarteStore.shared.reperes.lieu(id: Almanax.sanctuaire) }

    /// Le trajet jusqu'à un lieu, zaap compris — la décision des entrées de lieux.
    func copierTrajet(vers lieu: Lieu) {
        guard let texte = trajet(vers: lieu) else { return }
        copier(texte)
    }

    /// Copie, retient parmi les dernières copies et ferme.
    func copier(_ texte: String) {
        PressePapiers.copier(texte)
        ZaapClipboard.shared.signaler()
        if contexteImpose == nil {
            Preferences.shared.paletteRecents = RecherchePalette.noterRecent(texte, dans: Preferences.shared.paletteRecents)
        }
        PalettePanel.shared.fermer()
    }

    private func faire(_ action: ActionPalette) {
        switch action {
        case .rangerFenetres: Task { await WindowArranger.shared.appliquerDerniere() }
        case .lancerSession: WindowManager.shared.lancerSession()
        case .equipeSuivante: WindowManager.shared.equipeSuivante()
        case .inviterEquipe: InvitationClipboard.shared.copierEquipe()
        case .chasse: ChassePanel.shared.ouvrir()
        case .quetes: QuetePanel.shared.ouvrir()
        case .boss(let boss, _): BossPanel.shared.ouvrir(boss)
        case .reglages: SettingsWindowController.shared.show()
        }
    }

    // MARK: - Favoris et étiquettes

    func basculerFavori(_ entree: EntreePalette) {
        guard let cle = entree.cle else { return NSSound.beep() }
        Preferences.shared.basculerFavori(cle)
        rafraichir()
    }

    func commencerEtiquette(_ entree: EntreePalette) {
        guard entree.cle != nil else { return NSSound.beep() }
        edition = entree
        texteEtiquette = entree.etiquette ?? ""
    }

    func validerEtiquette() {
        guard let cle = edition?.cle else { return }
        let texte = texteEtiquette.trimmingCharacters(in: .whitespaces)
        Preferences.shared.etiquettes[cle] = texte.isEmpty ? nil : texte
        edition = nil
        rafraichir()
    }

    /// Après un favori, une étiquette, à la réouverture : même recherche,
    /// même sélection, contexte relu.
    func rafraichir() {
        let gardee = entrees.indices.contains(selection) ? entrees[selection].id : nil
        contexte = contexteImpose ?? Self.contexteCourant()
        recalculer()
        // La carte choisie de l'almanax ne dépend pas des entrées de la recherche, qui sont vides.
        guard !surAlmanax else { return }
        selection = gardee.flatMap { id in entrees.firstIndex { $0.id == id } } ?? 0
    }

    private func recalculer() {
        entrees = RecherchePalette.entrees(requete, index, filtre: filtre, tri: triAffiche)
        if !surAlmanax, selection >= entrees.count { selection = max(entrees.count - 1, 0) }
    }

    // MARK: - Contexte

    private static func contexteCourant() -> ContextePalette {
        let prefs = Preferences.shared
        let manager = WindowManager.shared
        let candidats = InvitationComposer.candidats(manager.effectif, chefPID: manager.frontmostPID)
        var contexte = ContextePalette()
        contexte.langue = L10n.courante.langue
        contexte.perso = LecteurEcran.shared.persoDevant
        contexte.position = LecteurEcran.shared.positionDuPersoDevant
        contexte.zaaps = ZaapClipboard.shared.zaapsSitues
        contexte.lieux = CarteStore.shared.carte.lieux
        contexte.interieurs = CarteStore.shared.interieurs
        contexte.etiquettes = prefs.etiquettes
        contexte.favoris = prefs.favoris
        contexte.recents = prefs.paletteRecents
        contexte.frequentation = prefs.paletteFrequentation
        contexte.quetes = QuetesStore.shared.quetes
        contexte.quetesSuivies = Set(prefs.quetesEpinglees).union(LectureSuivi.shared.reconnues.map(\.id))
        contexte.donjons = DonjonsStore.shared.donjons
        contexte.gainMinimal = prefs.zaapGainMinimal
        contexte.zaapDuJeu = prefs.zaapDuJeu
        contexte.intercalees = prefs.commandesIntercalees
        contexte.invitationEquipe = InvitationComposer.groupee(format: prefs.inviteFormat, noms: candidats)
        contexte.persos = manager.effectif.enumerated().map { rang, client in
            PersoPalette(slotKey: client.slotKey, nom: client.name, classe: client.characterClass,
                         position: LecteurEcran.shared.positions[client.name],
                         touche: BarView.toucheDuPerso(index: rang, raccourcis: prefs.hotKeys))
        }
        contexte.invitations = candidats.map { ($0, InvitationComposer.commande(format: prefs.inviteFormat, nom: $0)) }
        return contexte
    }
}
