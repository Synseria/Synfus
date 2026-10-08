import AppKit
import Combine

/// L'état de la palette : la recherche, la sélection, l'étiquette en cours
/// d'écriture. Ce qui se cherche est dans `RecherchePalette` ; ici, le
/// contexte du moment et ce qu'Entrée déclenche.
@MainActor
final class PaletteModele: ObservableObject {
    static let shared = PaletteModele()

    /// Les cartes de zaaps, quand rien n'est tapé.
    static let colonnes = 4

    @Published var requete = "" {
        didSet {
            guard requete != oldValue else { return }
            selection = 0
            recalculer()
        }
    }
    @Published private(set) var entrees: [EntreePalette] = []
    /// La famille montrée, que Tab fait défiler ; revient à « Tout » à
    /// chaque ouverture.
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
    /// Le contexte imposé (tests, captures de la documentation) ; `nil` : celui
    /// du moment, relu à chaque ouverture.
    private let contexteImpose: ContextePalette?

    /// Les quêtes arrivent après l'ouverture la première fois : la recherche
    /// en cours les reçoit dès qu'elles sont là.
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
    }

    /// Normalise d'avance, en tâche de fond, les textes de tout ce que la
    /// palette cherche — au lancement, et quand les quêtes arrivent.
    func prechauffer() {
        guard contexteImpose == nil else { return }
        let contexte = Self.contexteCourant()
        let connus = champsConnus
        Task.detached(priority: .utility) {
            let champs = IndexPalette.champs(de: contexte, connus: connus)
            await MainActor.run { PaletteModele.shared.champsConnus = champs }
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

    /// Les dernières copies, montrées au-dessus des cartes.
    var recents: [EntreePalette] { RecherchePalette.recents(contexte) }

    func ouvrir() {
        if contexteImpose == nil { QuetesStore.shared.preparer() }
        contexte = contexteImpose ?? Self.contexteCourant()
        filtre = .tout
        tri = contexteImpose == nil ? Preferences.shared.paletteTri : tri
        edition = nil
        requete = ""
        selection = 0
        recalculer()
        ouverture += 1
    }

    // MARK: - Clavier

    /// Flèches : de carte en carte dans la grille, de ligne en ligne sinon.
    func deplacer(colonne: Int = 0, ligne: Int = 0) {
        guard !entrees.isEmpty else { return }
        let pas = colonne + ligne * (enGrille ? Self.colonnes : 1)
        selection = min(max(selection + pas, 0), entrees.count - 1)
    }

    func valider() {
        if edition != nil { return validerEtiquette() }
        guard entrees.indices.contains(selection) else { return NSSound.beep() }
        executer(entrees[selection])
    }

    /// Tab : compléter une commande, sinon passer au filtre suivant (⇧Tab :
    /// au précédent).
    func tabulation(arriere: Bool = false) {
        if !arriere, entrees.indices.contains(selection), case .completer(let texte) = entrees[selection].effet {
            requete = texte
            return
        }
        filtre = filtre.suivant(arriere ? -1 : 1)
        selection = 0
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

    /// Échap : quitte l'étiquette, sinon ferme.
    func echap() {
        if edition != nil { edition = nil } else { PalettePanel.shared.fermer() }
    }

    // MARK: - Effets

    /// Ce qu'Entrée copiera pour cette entrée, trajet calculé depuis le perso devant.
    func texteACopier(_ entree: EntreePalette) -> String? {
        RecherchePalette.texte(de: entree.effet, contexte)
    }

    func executer(_ entree: EntreePalette) {
        switch entree.effet {
        case .copier, .trajet:
            guard let texte = texteACopier(entree) else { return }
            PressePapiers.copier(texte)
            if contexteImpose == nil {
                Preferences.shared.paletteRecents = RecherchePalette.noterRecent(texte, dans: Preferences.shared.paletteRecents)
            }
            PalettePanel.shared.fermer()
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

    private func faire(_ action: ActionPalette) {
        switch action {
        case .rangerFenetres: Task { await WindowArranger.shared.appliquerDerniere() }
        case .lancerSession: WindowManager.shared.lancerSession()
        case .equipeSuivante: WindowManager.shared.equipeSuivante()
        case .inviterEquipe:
            guard let texte = contexte.invitationEquipe else { return NSSound.beep() }
            PressePapiers.copier(texte)
        case .chasse: ChassePanel.shared.ouvrir()
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

    /// Après un favori ou une étiquette : même recherche, même sélection.
    private func rafraichir() {
        let gardee = entrees.indices.contains(selection) ? entrees[selection].id : nil
        contexte = contexteImpose ?? Self.contexteCourant()
        recalculer()
        if let gardee, let index = entrees.firstIndex(where: { $0.id == gardee }) { selection = index }
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
        contexte.position = LecteurEcran.shared.positionDuPersoDevant
        contexte.zaaps = prefs.zaapsActifs
        contexte.reseau = CarteStore.shared.reseau
        contexte.lieux = CarteStore.shared.carte.lieux
        contexte.etiquettes = prefs.etiquettes
        contexte.favoris = Set(prefs.zaapsFavoris + prefs.lieuxFavoris)
        contexte.recents = prefs.paletteRecents
        contexte.quetes = QuetesStore.shared.quetes
        contexte.gainMinimal = prefs.zaapGainMinimal
        contexte.invitationEquipe = InvitationComposer.groupee(format: prefs.inviteFormat, noms: candidats)
        contexte.invitations = candidats.map { ($0, InvitationComposer.commande(format: prefs.inviteFormat, nom: $0)) }
        return contexte
    }
}
