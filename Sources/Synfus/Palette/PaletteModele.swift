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
    /// La quête dont on voit le détail ; Échap revient à la recherche d'où
    /// elle a été ouverte.
    @Published private(set) var queteOuverte: Int?
    private var requeteAvantQuete = ""
    private var abonnements: Set<AnyCancellable> = []

    private var contexte = ContextePalette() {
        didSet { index = IndexPalette(contexte) }
    }
    private var index = IndexPalette(ContextePalette())
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
                }
            }
            .store(in: &abonnements)
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
        queteOuverte == nil && requete.trimmingCharacters(in: .whitespaces).isEmpty
            && (filtre == .tout || filtre == .zaaps)
    }

    /// Le nom de la quête ouverte, pour l'en-tête.
    var titreQuete: String? {
        guard let id = queteOuverte, let quete = contexte.quetes?.quetes.first(where: { $0.id == id }) else { return nil }
        return Lieu.traduit(quete.noms, contexte.langue)
    }

    /// Les dernières copies, montrées au-dessus des cartes.
    var recents: [EntreePalette] { RecherchePalette.recents(contexte) }

    func ouvrir() {
        if contexteImpose == nil { QuetesStore.shared.preparer() }
        contexte = contexteImpose ?? Self.contexteCourant()
        filtre = .tout
        queteOuverte = nil
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
        guard queteOuverte == nil else { return }
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

    /// Échap : quitte l'étiquette, puis la quête ouverte, sinon ferme.
    func echap() {
        if edition != nil {
            edition = nil
        } else if queteOuverte != nil {
            queteOuverte = nil
            requete = requeteAvantQuete
            recalculer()
        } else {
            PalettePanel.shared.fermer()
        }
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
            requeteAvantQuete = requete
            queteOuverte = id
            requete = ""
            selection = 0
            recalculer()
        case .basculer(let slotKey):
            PalettePanel.shared.fermer()
            if let client = WindowManager.shared.clients.first(where: { $0.slotKey == slotKey }) {
                WindowManager.shared.focus(client)
            }
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
        let prefs = Preferences.shared
        if cle.hasPrefix(Lieu.prefixeCle) {
            if prefs.lieuxFavoris.contains(cle) { prefs.lieuxFavoris.removeAll { $0 == cle } } else { prefs.lieuxFavoris.append(cle) }
        } else {
            if prefs.zaapsFavoris.contains(cle) { prefs.zaapsFavoris.removeAll { $0 == cle } } else { prefs.zaapsFavoris.append(cle) }
        }
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
        if let queteOuverte {
            entrees = RecherchePalette.quete(queteOuverte, requete, contexte)
        } else {
            entrees = RecherchePalette.entrees(requete, index, filtre: filtre, tri: tri)
        }
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
        contexte.lieux = CarteStore.shared.carte.lieux
        contexte.etiquettes = prefs.etiquettes
        contexte.favoris = Set(prefs.zaapsFavoris + prefs.lieuxFavoris)
        contexte.recents = prefs.paletteRecents
        contexte.quetes = QuetesStore.shared.quetes
        contexte.persos = manager.clients
            .filter { WindowTitle.isPersistableName($0.name) }
            .map { ($0.name, $0.slotKey) }
        contexte.gainMinimal = prefs.zaapGainMinimal
        contexte.invitationEquipe = InvitationComposer.groupee(format: prefs.inviteFormat, noms: candidats)
        contexte.invitations = candidats.map { ($0, InvitationComposer.commande(format: prefs.inviteFormat, nom: $0)) }
        return contexte
    }
}
