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
    @Published private(set) var carte: CartesFiche.Position?
    /// Les cartes de la fiche dépliée ouvertes (clef, monstres, succès).
    @Published private(set) var ouvertes: Set<ActionFiche> = []
    @Published private(set) var entrees: [EntreePalette] = []
    /// La famille montrée, que Tab fait défiler.
    @Published private(set) var filtre: FiltrePalette = .tout
    @Published private(set) var tri: TriPalette = .proximite
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

    /// La carte et les quêtes arrivent après le lancement, lues ou
    /// téléchargées en tâche de fond : la recherche en cours les reçoit dès
    /// qu'elles sont là, et leurs textes se normalisent d'avance.
    private init() {
        contexteImpose = nil
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
    init(contexte: ContextePalette, requete: String = "", filtre: FiltrePalette = .tout) {
        contexteImpose = contexte
        self.contexte = contexte
        index = IndexPalette(contexte)
        self.requete = requete
        self.filtre = filtre
        recalculer()
    }

    var enGrille: Bool {
        requete.trimmingCharacters(in: .whitespaces).isEmpty
            && (filtre == .tout || filtre == .zaaps)
    }

    /// Sans elle, le filtre « Ici » n'a rien à montrer.
    var positionConnue: Bool { contexte.position != nil }

    /// D'où partent distances et trajets : le dernier perso lu devant, à
    /// l'ouverture de la palette.
    var origine: String {
        guard let perso = contexte.perso, let position = contexte.position else { return L("palette.depuis.inconnue") }
        return L("palette.depuis", perso, Coordonnees.texte(position.x, position.y))
    }

    /// Les dernières copies, montrées au-dessus des cartes.
    var recents: [EntreePalette] { RecherchePalette.recents(contexte) }

    /// La palette reprend où on l'a laissée : recherche (que le panneau
    /// sélectionne, une lettre la remplace), filtre, ligne et fiche dépliée,
    /// distances refaites depuis la position du moment. Échap vide avant de
    /// fermer : rouvrir est alors vierge.
    func ouvrir() {
        if contexteImpose == nil {
            QuetesStore.shared.preparer()
            AlmanaxStore.shared.preparer()
            DonjonsStore.shared.charger()
        }
        tri = contexteImpose == nil ? Preferences.shared.paletteTri : tri
        edition = nil
        rafraichir()
        if let deplie, !entrees.contains(where: { $0.id == deplie }) { self.deplie = nil }
        carte = cartes.valide(carte)
        ouverture += 1
    }

    // MARK: - Clavier

    /// Flèches : de carte en carte dans la grille, de ligne en ligne sinon —
    /// en passant par les rangées de la fiche dépliée.
    func deplacer(colonne: Int = 0, ligne: Int = 0) {
        guard !entrees.isEmpty else { return }
        if !enGrille, ligne != 0, surLaFiche {
            if ligne > 0, let dessous = cartes.dessous(carte) { carte = dessous; return }
            if ligne < 0, let position = carte { carte = cartes.dessus(position); return }
        }
        let pas = colonne + ligne * (enGrille ? Self.colonnes : 1)
        let avant = selection
        carte = nil
        selection = min(max(selection + pas, 0), entrees.count - 1)
        // En remontant sur une fiche dépliée, on arrive par sa dernière rangée.
        if ligne < 0, selection != avant, surLaFiche { carte = cartes.derniere }
    }

    /// ← et → hors de la grille : de carte en carte dans une rangée ; ← sur
    /// une ligne dépliée la replie. `false` : la flèche reste au champ.
    func lateral(_ pas: Int) -> Bool {
        guard !enGrille, edition == nil, surLaFiche else { return false }
        if let position = carte {
            carte = cartes.laterale(position, pas)
            return true
        }
        guard pas < 0 else { return false }
        deplie = nil
        return true
    }

    /// ↵ : la carte choisie de la fiche ; sur une ligne déjà dépliée, son
    /// geste par défaut (aller à l'entrée du donjon, au repaire le plus proche) ;
    /// sinon l'entrée elle-même.
    func valider() {
        if edition != nil { return validerEtiquette() }
        guard entrees.indices.contains(selection) else { return NSSound.beep() }
        let entree = entrees[selection]
        if surLaFiche {
            if let action = cartes.action(carte) ?? cartes.parDefaut { return agir(action) }
            if case .ouTrouver(.monstre(let id)) = entree.effet { return copierLePlusProche(monstre: id) }
        }
        executer(entree)
    }

    /// Tab : compléter une commande, sinon passer au filtre suivant (⇧Tab :
    /// au précédent).
    func tabulation(arriere: Bool = false) {
        if !arriere, entrees.indices.contains(selection), case .completer(let texte) = entrees[selection].effet {
            requete = texte
            return
        }
        choisir(filtre.suivant(arriere ? -1 : 1))
    }

    /// Un filtre : Tab, ou un clic sur sa capsule.
    func choisir(_ filtre: FiltrePalette) {
        self.filtre = filtre
        selection = 0
        deplie = nil
        recalculer()
    }

    /// ⌘T : proximité, ordre alphabétique, type — et le choix est gardé.
    func triSuivant() {
        tri = tri.suivant
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

    /// Échap : quitte l'étiquette ; efface la recherche et le filtre — une
    /// faute de frappe ne fait pas tout reprendre ; sinon ferme.
    func echap() {
        if edition != nil { edition = nil; return }
        guard requete.isEmpty, filtre == .tout else {
            requete = ""
            choisir(.tout)
            return
        }
        PalettePanel.shared.fermer()
    }

    // MARK: - Effets

    /// Ce qu'Entrée copiera pour cette entrée, trajet calculé depuis le perso devant.
    func texteACopier(_ entree: EntreePalette) -> String? {
        RecherchePalette.texte(de: entree.effet, contexte)
    }

    /// Un clic : la ligne choisie, puis son effet.
    func executer(_ entree: EntreePalette) {
        if let index = entrees.firstIndex(where: { $0.id == entree.id }) {
            selection = index
            carte = nil
        }
        switch entree.effet {
        case .copier, .trajet:
            guard let texte = texteACopier(entree) else { return }
            copier(texte)
        case .ouTrouver, .donjon:
            deplie = deplie == entree.id ? nil : entree.id
        case .completer(let texte):
            requete = texte
        case .ouvrirQuete(let id):
            PalettePanel.shared.fermer()
            QuetePanel.shared.ouvrir(id)
        case .action(let action):
            PalettePanel.shared.fermer()
            faire(action)
        }
    }

    // MARK: - Fiche dépliée

    /// La sélection est sur la ligne dépliée ou dans sa fiche.
    private var surLaFiche: Bool {
        entrees.indices.contains(selection) && entrees[selection].id == deplie
    }

    /// Les cartes de la fiche dépliée, refaites à chaque lecture : le détail
    /// du donjon arrive après l'ouverture.
    var cartes: CartesFiche {
        guard let deplie, let entree = entrees.first(where: { $0.id == deplie }),
              case .donjon(let id) = entree.effet, let donjon = DonjonsStore.shared.donjons?.donjon(id: id)
        else { return .vide }
        return .donjon(entree: Self.entree(de: donjon), guide: donjon.nomFrancais,
                       detail: DonjonsStore.shared.details[id])
    }

    /// Le repère de l'entrée d'un donjon sur la carte : par sa carte, sinon par son nom.
    private static func entree(de donjon: Donjon) -> Lieu? {
        let reperes = CarteStore.shared.reperes
        return donjon.entree.flatMap(reperes.donjon(carte:)) ?? donjon.nomFrancais.flatMap(reperes.donjon(nom:))
    }

    /// La carte de la fiche dépliée, à la souris : choisie, puis faite.
    func cliquer(_ position: CartesFiche.Position) {
        guard let action = cartes.action(position) else { return }
        if let index = entrees.firstIndex(where: { $0.id == deplie }) { selection = index }
        carte = position
        agir(action)
    }

    func agir(_ action: ActionFiche) {
        switch action {
        case .entree(let lieu): copierTrajet(vers: lieu)
        case .guide(let nom): Task { await DofusPourLesNoobs.ouvrir(nom) }
        case .clef, .monstres, .succes:
            if ouvertes.remove(action) == nil { ouvertes.insert(action) }
        }
    }

    /// Le trajet jusqu'à un lieu et ce qu'en dit sa ligne (« via … · 6 cartes »).
    func versLieu(_ lieu: Lieu) -> (texte: String?, itineraire: String?) {
        let vers = RecherchePalette.versLieu(lieu, contexte)
        return (RecherchePalette.texte(de: vers.effet, contexte), RecherchePalette.itineraire(vers.trajet, contexte.langue))
    }

    private func copierLePlusProche(monstre id: Int) {
        Task {
            guard await OuTrouverStore.shared.copierLePlusProche(monstre: id) else { return NSSound.beep() }
            PalettePanel.shared.fermer()
        }
    }

    /// Le Sanctuaire de l'Almanax, s'il est sur la carte.
    var sanctuaire: Lieu? { CarteStore.shared.reperes.lieu(id: Almanax.sanctuaire) }

    /// Le trajet jusqu'à un lieu, zaap compris — la décision des entrées de lieux.
    func copierTrajet(vers lieu: Lieu) {
        guard let texte = versLieu(lieu).texte else { return }
        copier(texte)
    }

    /// Copie, retient parmi les dernières copies et ferme.
    func copier(_ texte: String) {
        PressePapiers.copier(texte)
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
        case .boss(let boss): BossPanel.shared.ouvrir(boss)
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
    private func rafraichir() {
        let gardee = entrees.indices.contains(selection) ? entrees[selection].id : nil
        contexte = contexteImpose ?? Self.contexteCourant()
        recalculer()
        selection = gardee.flatMap { id in entrees.firstIndex { $0.id == id } } ?? 0
    }

    private func recalculer() {
        entrees = RecherchePalette.entrees(requete, index, filtre: filtre, tri: tri)
        if selection >= entrees.count { selection = max(entrees.count - 1, 0) }
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
        contexte.quetes = QuetesStore.shared.quetes
        contexte.donjons = DonjonsStore.shared.donjons
        contexte.gainMinimal = prefs.zaapGainMinimal
        contexte.zaapDuJeu = prefs.zaapDuJeu
        contexte.intercalees = prefs.commandesIntercalees
        contexte.invitationEquipe = InvitationComposer.groupee(format: prefs.inviteFormat, noms: candidats)
        contexte.invitations = candidats.map { ($0, InvitationComposer.commande(format: prefs.inviteFormat, nom: $0)) }
        return contexte
    }
}
