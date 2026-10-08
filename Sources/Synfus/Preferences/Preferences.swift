import AppKit
import Carbon.HIToolbox

/// Réglages persistés dans les UserDefaults, sérialisés en JSON sous une seule clé.
///
/// Isolée au main actor comme le reste de l'app : c'est ce qui rend le singleton
/// acceptable pour la concurrence stricte de Swift 6, sans verrou ni copie.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    /// Ordre de préférence des persos, par nom. Sert à donner un numéro stable à
    /// chaque perso : ceux qui ne sont pas lancés sont simplement sautés, donc
    /// avoir 30 persos déclarés pour 3 clients ouverts ne pose aucun problème.
    @Published var characterOrder: [String] = [] { didSet { save() } }

    /// Raccourci par slot. `nil` = ce slot n'a pas de raccourci.
    @Published var hotKeys: [HotKey?] = [] { didSet { save() } }

    @Published var cycleNext: HotKey? { didSet { save() } }
    @Published var cyclePrevious: HotKey? { didSet { save() } }

    @Published var barVisible: Bool = true { didSet { save() } }
    @Published var barOrigin: CGPoint? = nil { didSet { save() } }
    @Published var showNumbers: Bool = true { didSet { save() } }
    @Published var showClasses: Bool = true { didSet { save() } }

    /// Réaction quand un perso réclame l'attention (rebond de son icône du Dock).
    @Published var attentionAction: AttentionAction = .highlight { didSet { save() } }

    /// Raccourci de bascule du passage automatique.
    @Published var toggleAutoFocus: HotKey? { didSet { save() } }

    /// Raccourci d'affichage / masquage de la barre. Sans valeur par défaut :
    /// une combinaison réservée au système est une combinaison prise à
    /// l'utilisateur, on ne le fait pas sans qu'il l'ait demandé.
    @Published var toggleBar: HotKey? { didSet { save() } }

    /// N'afficher la barre que lorsque Dofus est au premier plan.
    @Published var barOnlyWithDofus: Bool = false { didSet { save() } }

    /// Les panneaux du jeu (quêtes, chasse) ne se montrent que devant Dofus.
    @Published var panneauxSeulementDofus: Bool = true { didSet { save() } }

    /// Aperçu de la fenêtre au survol d'une pastille. Désactivé par défaut :
    /// la première capture réclame l'autorisation « Enregistrement de l'écran »,
    /// et une mise à jour n'a pas à faire surgir une demande que personne n'a
    /// demandée.
    @Published var showPreviewOnHover: Bool = false { didSet { save() } }

    /// Raccourci d'aperçu de tous les persos, actif tant qu'il est maintenu.
    @Published var previewHotKey: HotKey? { didSet { save() } }

    /// Recentrer la barre en haut de l'écran tant qu'elle n'a pas été déplacée
    /// à la main.
    @Published var autoCenterBar: Bool = true { didSet { save() } }

    /// Enchaîner les persos au clic : un clic sur un client de jeu avec
    /// `advanceModifier` tenue passe au perso suivant. Éteint par défaut — il
    /// installe un moniteur global de souris, et personne n'a demandé ça en
    /// installant l'app.
    @Published var advanceOnClick: Bool = false { didSet { save() } }

    /// La touche à tenir pendant le clic. `fn` : la seule que ni le jeu ni
    /// macOS n'interprètent sur un clic (voir `ClickModifier`).
    @Published var advanceModifier: ClickModifier = .fn { didSet { save() } }

    /// Faire clignoter la pastille du perso à chaque bascule. Activé par
    /// défaut — rien à autoriser, et c'est ce qui manquait pour ne pas se
    /// perdre en enchaînant au clic.
    @Published var signalerBascule: Bool = true { didSet { save() } }

    /// Lire la position du perso (coordonnées de la carte, en haut à gauche
    /// de la fenêtre) par OCR. Désactivé par défaut : il faut l'autorisation
    /// « Enregistrement de l'écran », jamais demandée d'office.
    @Published var lirePosition: Bool = false { didSet { save() } }

    /// Détecter le combat — bouton « Fin de tour » rose, gris ou absent — par
    /// la même lecture de l'écran. Désactivé par défaut, pour la même raison.
    @Published var lireCombat: Bool = false { didSet { save() } }

    /// Zones de lecture calibrées (onglet Lecture de l'écran), une par
    /// `GenreLecture` ; `nil` : son défaut (`GenreLecture.parDefaut`), qui
    /// suit ainsi ses corrections futures tant qu'on ne l'a pas remplacé.
    @Published var zonePosition: ZoneEcran? { didSet { save() } }
    @Published var zoneCombat: ZoneEcran? { didSet { save() } }
    @Published var zoneChasse: ZoneEcran? { didSet { save() } }
    @Published var zoneQuetes: ZoneEcran? { didSet { save() } }

    /// Icône du `NSStatusItem`. Le rafraîchissement est à la charge de l'appelant
    /// (`MenuBarController.refreshIcon()`) : les préférences ne pilotent pas l'UI.
    @Published var menuBarIcon: MenuBarIcon = .logo { didSet { save() } }

    /// Achever les clients gelés à la fermeture (voir `FreezeWatcher`). Activé
    /// par défaut : la règle d'abattage est assez stricte pour ne viser que des
    /// processus déjà morts en pratique, et c'est tout l'intérêt de la fonction
    /// qu'elle agisse sans qu'on la lui demande à chaque fois.
    @Published var killFrozenClients: Bool = true { didSet { save() } }

    /// Dernière disposition de rangement appliquée — celle que rejoue le
    /// raccourci. `nil` = jamais rangé.
    @Published var lastArrangement: Disposition? = nil { didSet { save() } }

    /// Raccourci de rangement des fenêtres. Sans défaut, comme `toggleBar` :
    /// une combinaison réservée au système est une combinaison prise à
    /// l'utilisateur.
    @Published var arrangeHotKey: HotKey? { didSet { save() } }

    /// Raccourci du geste « lancer la session ». Sans défaut, même règle.
    @Published var sessionHotKey: HotKey? { didSet { save() } }

    /// Les équipes — leurs compositions, persistées. Pas de bascule : la
    /// fonction n'existe que par ses équipes, et la rangée de la barre
    /// n'apparaît que s'il y en a, ou le temps d'un glisser pour en créer une.
    /// L'équipe **active**, elle, est un état de session de `WindowManager` —
    /// Synfus démarre toujours sur « Tous ».
    @Published var equipes: [Equipe] = [] { didSet { save() } }

    /// Raccourci « équipe suivante ». Sans défaut.
    @Published var equipeSuivanteHotKey: HotKey? { didSet { save() } }

    /// Raccourci « copier l'invitation suivante ». ⌘: par défaut — un choix de
    /// l'utilisateur, posé par `adoptDefaults` sur les sauvegardes antérieures.
    @Published var inviteHotKey: HotKey? { didSet { save() } }

    /// Le texte posé dans le presse-papiers, `%nom` remplacé par le perso.
    @Published var inviteFormat: String = InvitationComposer.formatParDefaut { didSet { save() } }

    /// Le raccourci copie toutes les invitations en une ligne plutôt qu'une
    /// par appui.
    @Published var inviteGroupee: Bool = false { didSet { save() } }

    /// Raccourci « zaap le plus proche du /travel copié ». Sans défaut.
    @Published var zaapHotKey: HotKey? { didSet { save() } }

    /// Le bouton zaap dans la barre — montré seulement si la position est lue.
    @Published var zaapBouton: Bool = true { didSet { save() } }

    /// Réécrire de soi-même chaque `/travel` copié. Éteint par défaut : il
    /// regarde chaque copie, de n'importe quelle app.
    @Published var zaapAuto: Bool = false { didSet { save() } }

    /// Les cartes que le zaap doit épargner pour être proposé.
    @Published var zaapGainMinimal: Int = ItineraireZaap.gainParDefaut { didSet { save() } }

    /// Passer par le zaap que le jeu rattache à la sous-zone visée, même plus
    /// loin qu'un autre (`ItineraireZaap.zaap(vers:)`).
    @Published var zaapDuJeu: Bool = true { didSet { save() } }

    /// Les zaaps ajoutés à la main.
    @Published var zaapsAjoutes: [Zaap] = [] { didSet { save() } }

    /// Activation choisie, par `Zaap.cle` ; absent : `CatalogueZaaps.actifParDefaut`.
    @Published var zaapsChoix: [String: Bool] = [:] { didSet { save() } }

    /// Les zaaps proposés au clic droit du bouton de la barre, par `Zaap.cle`,
    /// dans l'ordre où ils ont été marqués.
    @Published var zaapsFavoris: [String] = [] { didSet { save() } }

    /// Les vues des cartes du jeu, téléchargées de DofusDB à la première
    /// ouverture : en vignette dans la palette, les listes et le panneau des
    /// quêtes, en fond des zaaps de l'onglet Zaaps — d'où sa clé.
    @Published var vuesCartes: Bool = true { didSet { save() } }

    /// Les lieux de la carte mis en avant dans la palette, par `Lieu.cle`.
    @Published var lieuxFavoris: [String] = [] { didSet { save() } }

    /// Les étiquettes libres (« Fri 1 », « Bouftou »), par `Zaap.cle` ou
    /// `Lieu.cle` : la palette les cherche avant les noms.
    @Published var etiquettes: [String: String] = [:] { didSet { save() } }

    /// Les derniers textes copiés depuis la palette, le plus récent d'abord.
    @Published var paletteRecents: [String] = [] { didSet { save() } }

    /// L'ordre des résultats de la palette, après les zaaps (⌘T).
    @Published var paletteTri: TriPalette = .proximite { didSet { save() } }

    /// Les quêtes épinglées dans leur panneau, dans l'ordre d'ouverture.
    @Published var quetesEpinglees: [Int] = [] { didSet { save() } }

    /// L'étape où l'on en est de chaque quête, par identifiant de quête.
    @Published var quetesEtape: [String: Int] = [:] { didSet { save() } }

    /// Les objectifs cochés de chaque quête (identifiants DofusDB), par
    /// identifiant de quête.
    @Published var quetesValides: [String: [Int]] = [:] { didSet { save() } }

    /// Le bouton des quêtes dans la barre.
    @Published var quetesBouton: Bool = true { didSet { save() } }

    /// Les objets de quête hors des ressources à réunir : ils ne s'achètent pas.
    @Published var quetesMasquerObjets: Bool = false { didSet { save() } }

    /// Raccourci de la palette. ⌘: par défaut (génération 7).
    @Published var paletteHotKey: HotKey? { didSet { save() } }

    /// Raccourci du panneau de chasse au trésor. Sans défaut.
    @Published var chasseHotKey: HotKey? { didSet { save() } }

    /// Le bouton de chasse dans la barre.
    @Published var chasseBouton: Bool = true { didSet { save() } }

    private var loading = false

    /// Clé unique sous laquelle tout est sérialisé, dans le domaine
    /// `UserDefaults` de l'app — lui-même nommé d'après le `BUNDLE_ID`.
    static let key = "fr.synseria.synfus.preferences"

    private let store: PreferencesStore

    private init(store: PreferencesStore = UserDefaults.standard) {
        self.store = store
        load()
    }

    /// Instance jetable adossée à un stockage fourni, pour les tests.
    static func forTesting(store: PreferencesStore) -> Preferences {
        Preferences(store: store)
    }

    /// Un emplacement par chiffre, toujours : combien servent dépend des persos
    /// connectés (`HotKeyManager.rebind`), pas d'un réglage. Un emplacement que
    /// la sauvegarde n'a pas encore prend son défaut ; un raccourci effacé à la
    /// main reste effacé.
    private func completerHotKeys() {
        let emplacements = HotKey.digitRow.count
        if hotKeys.count < emplacements {
            hotKeys += (hotKeys.count..<emplacements).map { HotKey.defaultHotKey(slot: $0) }
        } else if hotKeys.count > emplacements {
            hotKeys.removeSubrange(emplacements...)
        }
    }

    /// Permute deux persos dans l'ordre de préférence.
    func swapOrder(_ first: String, _ second: String) {
        guard let a = characterOrder.firstIndex(of: first),
              let b = characterOrder.firstIndex(of: second)
        else { return }
        characterOrder.swapAt(a, b)
    }

    /// Déplacement depuis une liste (fenêtre de réglages).
    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var order = characterOrder
        order.move(fromOffsets: offsets, toOffset: destination)
        characterOrder = order
    }

    /// Enregistre les persos rencontrés pour la première fois, en fin de liste.
    func registerIfNeeded(names: [String]) {
        let unknown = names.filter { !characterOrder.contains($0) }
        guard !unknown.isEmpty else { return }
        characterOrder.append(contentsOf: unknown)
    }

    func forget(name: String) {
        forget(names: [name])
    }

    /// Oublie plusieurs persos d'un coup. Une écriture, pas une par nom :
    /// chaque affectation de `characterOrder` sérialise le JSON et réveille
    /// toutes les vues qui observent les préférences — « oublier les hors
    /// ligne » sur une liste de trente persos en faisait autant de tours.
    func forget(names: [String]) {
        let aRetirer = Set(names)
        guard characterOrder.contains(where: aRetirer.contains) else { return }
        characterOrder.removeAll(where: aRetirer.contains)
        restreindreEquipes()
    }

    /// Ne conserve dans l'ordre que les noms retenus par `isKept`.
    ///
    /// Sert à purger les entrées héritées d'avant le filtre d'enregistrement —
    /// versions du client, homonymes suffixés. L'égalité des tailles court-circuite
    /// l'écriture : sans elle, chaque démarrage réenregistrerait les préférences
    /// pour rien.
    func purgeOrder(keeping isKept: (String) -> Bool) {
        let filtered = characterOrder.filter(isKept)
        guard filtered.count != characterOrder.count else { return }
        characterOrder = filtered
        restreindreEquipes()
    }

    /// Change un perso d'équipe — ou l'en retire, avec `nil`. Le pendant de
    /// `swapOrder` : la règle est dans `Equipes`, et rien n'est écrit si rien
    /// ne change.
    func affecter(_ nom: String, aEquipe index: Int?) {
        let nouvelles = Equipes.affecter(nom, a: index, dans: equipes)
        if nouvelles != equipes { equipes = nouvelles }
    }

    /// Les équipes restent un sous-ensemble de `characterOrder` : un perso
    /// oublié ou purgé en sort aussi.
    private func restreindreEquipes() {
        let restreintes = Equipes.restreintes(equipes, aux: Set(characterOrder))
        if restreintes != equipes { equipes = restreintes }
    }

    /// Génération courante des raccourcis par défaut. À incrémenter — avec la
    /// reprise correspondante dans `adoptDefaults` — chaque fois que les défauts
    /// changent, sans quoi les installations existantes resteraient sur les
    /// anciens à jamais.
    static let defaultsVersion = 7

    /// Les défauts de la génération 1, ceux qu'une installation existante peut
    /// encore porter sans que l'utilisateur les ait choisis. Seules ces
    /// valeurs-là sont reprises : un raccourci personnalisé, ou effacé
    /// délibérément, n'est jamais réécrit.
    private static let legacyCycleNext = HotKey(keyCode: 48, modifiers: UInt32(controlKey))
    private static let legacyCyclePrevious = HotKey(
        keyCode: 48, modifiers: UInt32(controlKey) | UInt32(shiftKey))
    private static let legacyToggleAutoFocus = HotKey(keyCode: 50, modifiers: UInt32(cmdKey))
    /// ⌘:, l'invitation des générations 6 : la palette le prend en 7.
    private static let legacyInvite = HotKey(keyCode: 47, modifiers: UInt32(cmdKey))

    /// Fait passer une sauvegarde ancienne au jeu de raccourcis courant.
    ///
    /// ⌘@ devient l'avancée dans la barre — le geste le plus répété, sur la
    /// touche la plus facile à atteindre — et la bascule du passage automatique
    /// migre vers un autre modificateur ; l'aperçu d'ensemble reçoit son
    /// premier défaut.
    ///
    /// Rend `true` s'il y a eu quelque chose à reprendre, pour que l'appelant
    /// n'écrive les préférences que dans ce cas.
    @discardableResult
    func adoptDefaults(from version: Int?) -> Bool {
        let from = version ?? 1
        guard from < Self.defaultsVersion else { return false }

        if from < 2 {
            if cycleNext == Self.legacyCycleNext { cycleNext = .defaultCycleNext }
            if cyclePrevious == Self.legacyCyclePrevious { cyclePrevious = .defaultCyclePrevious }
            // `nil` compris : la bascule est apparue après coup, une sauvegarde
            // plus ancienne que la clé ne l'a jamais eue. Passé cette reprise, un
            // raccourci effacé le reste — c'est la génération inscrite qui fait la
            // différence entre « jamais eu » et « retiré exprès ».
            if toggleAutoFocus == Self.legacyToggleAutoFocus || toggleAutoFocus == nil {
                toggleAutoFocus = .defaultToggleAutoFocus
            }
            // L'aperçu d'ensemble n'a jamais eu de défaut : le poser ne retire
            // donc rien à personne. Il ne déclenche aucune demande d'autorisation
            // — la capture ne part que si l'enregistrement de l'écran est déjà
            // accordé.
            if previewHotKey == nil { previewHotKey = .defaultPreview }
        }

        // La génération 2 posait la navigation sur le keycode 50 en le croyant
        // « la touche sous Échap ». C'est vrai d'un clavier ANSI seulement : sur
        // un ISO, cette position est le keycode 10 et le 50 est la touche `<>`.
        // Les raccourcis étaient donc bien enregistrés, mais sur une touche que
        // personne n'allait chercher — muets, en pratique.
        if from < 3 { moveToEscapeRow() }

        // Les générations 4 et 5 donnaient et déplaçaient le raccourci qui
        // armait le mode « enchaîner ». Le mode a disparu au profit du clic
        // modifié (`ClickModifier`) : la clé `advanceArmHotKey` d'une
        // sauvegarde ancienne est simplement ignorée à la lecture.

        // L'invitation par presse-papiers est arrivée avec la génération 6 :
        // une sauvegarde plus ancienne ne l'a jamais eue.
        if from < 6, inviteHotKey == nil { inviteHotKey = .defaultInvite }

        // La palette arrive avec la génération 7 et prend ⌘: ; l'invitation,
        // aussi dans la palette (`/invite`), passe à ⇧⌘: si elle y était.
        if from < 7 {
            if inviteHotKey == Self.legacyInvite { inviteHotKey = .defaultInvite }
            if paletteHotKey == nil { paletteHotKey = .defaultPalette }
        }
        return true
    }

    /// Tous les raccourcis globaux — ceux dont un doublon se signale, quel
    /// que soit l'onglet qui les règle.
    var raccourcisGlobaux: [HotKey?] {
        hotKeys + [
            cycleNext, cyclePrevious, toggleBar, previewHotKey, arrangeHotKey, sessionHotKey,
            equipeSuivanteHotKey, inviteHotKey, zaapHotKey, chasseHotKey, paletteHotKey, toggleAutoFocus,
        ]
    }

    /// Remet tous les raccourcis à leur défaut — ceux qui n'en ont pas sont
    /// effacés. L'appelant réenregistre (`HotKeyManager.rebind`).
    func resetShortcuts() {
        hotKeys = HotKey.digitRow.indices.map { HotKey.defaultHotKey(slot: $0) }
        cycleNext = .defaultCycleNext
        cyclePrevious = .defaultCyclePrevious
        toggleAutoFocus = .defaultToggleAutoFocus
        previewHotKey = .defaultPreview
        inviteHotKey = .defaultInvite
        paletteHotKey = .defaultPalette
        toggleBar = nil
        arrangeHotKey = nil
        sessionHotKey = nil
        equipeSuivanteHotKey = nil
        zaapHotKey = nil
        chasseHotKey = nil
    }

    /// Reporte sur la touche sous Échap les raccourcis restés sur le keycode 50.
    /// Sur un clavier ANSI, où les deux coïncident, c'est sans effet.
    private func moveToEscapeRow() {
        guard HotKey.escapeRowKey != HotKey.ansiGraveKey else { return }
        func replaced(_ hotKey: HotKey?) -> HotKey? {
            guard let hotKey, hotKey.keyCode == HotKey.ansiGraveKey else { return hotKey }
            return HotKey(keyCode: HotKey.escapeRowKey, modifiers: hotKey.modifiers)
        }
        cycleNext = replaced(cycleNext)
        cyclePrevious = replaced(cyclePrevious)
        toggleAutoFocus = replaced(toggleAutoFocus)
        previewHotKey = replaced(previewHotKey)
        toggleBar = replaced(toggleBar)
    }

    // MARK: - Persistance

    /// Chaque réglage, une ligne : sa clé dans la sauvegarde et sa propriété.
    /// Le défaut n'y figure pas — c'est la valeur initiale de la propriété, que
    /// garde une clé absente : `load()` ne passe qu'une fois, sur une instance
    /// neuve. Les clés sont celles des sauvegardes existantes, à ne jamais
    /// renommer ; une clé inconnue de cette table est ignorée à la lecture.
    private static let reglages: [Reglage] = [
        .requis("characterOrder", \.characterOrder),
        .requis("hotKeys", \.hotKeys),
        .optionnel("cycleNext", \.cycleNext),
        .optionnel("cyclePrevious", \.cyclePrevious),
        .requis("barVisible", \.barVisible),
        .point(x: "barOriginX", y: "barOriginY", \.barOrigin),
        .requis("showNumbers", \.showNumbers),
        .facultatif("showClasses", \.showClasses),
        .facultatif("attentionAction", \.attentionAction),
        // Sans défaut à la lecture : un raccourci vide est un choix. Les
        // sauvegardes plus anciennes que la clé sont rattrapées par
        // `adoptDefaults`, une fois.
        .optionnel("toggleAutoFocus", \.toggleAutoFocus),
        .optionnel("toggleBar", \.toggleBar),
        .facultatif("barOnlyWithDofus", \.barOnlyWithDofus),
        .facultatif("panneauxSeulementDofus", \.panneauxSeulementDofus),
        .facultatif("autoCenterBar", \.autoCenterBar),
        .facultatif("menuBarIcon", \.menuBarIcon),
        .facultatif("showPreviewOnHover", \.showPreviewOnHover),
        .optionnel("previewHotKey", \.previewHotKey),
        .facultatif("advanceOnClick", \.advanceOnClick),
        .facultatif("advanceModifier", \.advanceModifier),
        .facultatif("signalerBascule", \.signalerBascule),
        .facultatif("lirePosition", \.lirePosition),
        .facultatif("lireCombat", \.lireCombat),
        .optionnel("zonePosition", \.zonePosition),
        .optionnel("zoneCombat", \.zoneCombat),
        .optionnel("zoneChasse", \.zoneChasse),
        .optionnel("zoneQuetes", \.zoneQuetes),
        .facultatif("killFrozenClients", \.killFrozenClients),
        .optionnel("lastArrangement", \.lastArrangement),
        .optionnel("arrangeHotKey", \.arrangeHotKey),
        .optionnel("sessionHotKey", \.sessionHotKey),
        .facultatif("equipes", \.equipes),
        .optionnel("equipeSuivanteHotKey", \.equipeSuivanteHotKey),
        .optionnel("inviteHotKey", \.inviteHotKey),
        .facultatif("inviteFormat", \.inviteFormat),
        .facultatif("inviteGroupee", \.inviteGroupee),
        .optionnel("zaapHotKey", \.zaapHotKey),
        .facultatif("zaapBouton", \.zaapBouton),
        .facultatif("zaapAuto", \.zaapAuto),
        .facultatif("zaapGainMinimal", \.zaapGainMinimal),
        .facultatif("zaapDuJeu", \.zaapDuJeu),
        .facultatif("zaapsAjoutes", \.zaapsAjoutes),
        .facultatif("zaapsChoix", \.zaapsChoix),
        .facultatif("zaapsFavoris", \.zaapsFavoris),
        .optionnel("chasseHotKey", \.chasseHotKey),
        .facultatif("lieuxFavoris", \.lieuxFavoris),
        .facultatif("etiquettes", \.etiquettes),
        .optionnel("paletteHotKey", \.paletteHotKey),
        .facultatif("paletteRecents", \.paletteRecents),
        .facultatif("paletteTri", \.paletteTri),
        .facultatif("quetesEpinglees", \.quetesEpinglees),
        .facultatif("quetesEtape", \.quetesEtape),
        .facultatif("chasseBouton", \.chasseBouton),
        .facultatif("quetesValides", \.quetesValides),
        .facultatif("quetesBouton", \.quetesBouton),
        .facultatif("quetesMasquerObjets", \.quetesMasquerObjets),
        .facultatif("zaapsVueCarte", \.vuesCartes),
    ]

    /// Génération du jeu de raccourcis par défaut appliqué à la sauvegarde.
    /// Absente des sauvegardes d'avant la refonte, d'où le repli sur 1 à la
    /// lecture (`adoptDefaults`).
    private static let cleGeneration: Cle = "defaultsVersion"

    private func save() {
        guard !loading else { return }
        if let data = try? JSONEncoder().encode(Ecriture(prefs: self)) {
            store.enregistrer(data, pour: Self.key)
        }
    }

    private func load() {
        loading = true

        guard let data = store.donnees(pour: Self.key),
              let lecture = try? JSONDecoder().decode(Lecture.self, from: data)
        else {
            // Premier lancement : ⌘1 à ⌘0 pour l'accès direct, et toute la
            // navigation sur la touche sous Échap.
            hotKeys = HotKey.digitRow.indices.map { HotKey.defaultHotKey(slot: $0) }
            cycleNext = .defaultCycleNext
            cyclePrevious = .defaultCyclePrevious
            toggleAutoFocus = .defaultToggleAutoFocus
            previewHotKey = .defaultPreview
            inviteHotKey = .defaultInvite
            paletteHotKey = .defaultPalette
            loading = false
            completerHotKeys()
            return
        }

        for affecter in lecture.affectations { affecter(self) }

        loading = false
        completerHotKeys()
        // La reprise se fait le drapeau `loading` relâché : c'est elle, et elle
        // seule, qui doit réécrire la sauvegarde — ne serait-ce que pour y
        // inscrire la génération, sans quoi elle se rejouerait à chaque lancement.
        if adoptDefaults(from: lecture.generation) { save() }
    }

    /// Une clé de la sauvegarde JSON.
    private struct Cle: CodingKey, ExpressibleByStringLiteral {
        let stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        init(stringLiteral value: String) { stringValue = value }
        var intValue: Int? { nil }
        init?(intValue _: Int) { nil }
    }

    /// Comment un réglage s'écrit et se relit. La lecture n'affecte rien : elle
    /// rend l'affectation à faire, pour que la sauvegarde se lise entière ou
    /// pas du tout — une valeur mal typée la rend illisible, comme autrefois.
    @MainActor
    private struct Reglage {
        let ecrire: @MainActor (Preferences, inout KeyedEncodingContainer<Cle>) throws -> Void
        let lire: @MainActor (KeyedDecodingContainer<Cle>) throws -> (@MainActor (Preferences) -> Void)?

        /// Une clé des toutes premières sauvegardes : sans elle, la sauvegarde
        /// est illisible et l'on repart des défauts du premier lancement.
        static func requis<V: Codable>(
            _ cle: Cle, _ chemin: ReferenceWritableKeyPath<Preferences, V>
        ) -> Reglage {
            Reglage(ecrire: { try $1.encode($0[keyPath: chemin], forKey: cle) },
                    lire: { conteneur in
                        let valeur = try conteneur.decode(V.self, forKey: cle)
                        return { $0[keyPath: chemin] = valeur }
                    })
        }

        /// Une clé apparue après coup : absente ou `null`, la propriété garde
        /// sa valeur initiale.
        static func facultatif<V: Codable>(
            _ cle: Cle, _ chemin: ReferenceWritableKeyPath<Preferences, V>
        ) -> Reglage {
            Reglage(ecrire: { try $1.encode($0[keyPath: chemin], forKey: cle) },
                    lire: { conteneur in
                        guard let valeur = try conteneur.decodeIfPresent(V.self, forKey: cle)
                        else { return nil }
                        return { $0[keyPath: chemin] = valeur }
                    })
        }

        /// Une valeur qui peut manquer : `nil` n'est pas écrit du tout.
        static func optionnel<V: Codable>(
            _ cle: Cle, _ chemin: ReferenceWritableKeyPath<Preferences, V?>
        ) -> Reglage {
            Reglage(ecrire: { try $1.encodeIfPresent($0[keyPath: chemin], forKey: cle) },
                    lire: { conteneur in
                        guard let valeur = try conteneur.decodeIfPresent(V.self, forKey: cle)
                        else { return nil }
                        return { $0[keyPath: chemin] = valeur }
                    })
        }

        /// Un point écrit en deux coordonnées ; il n'est relu que si les deux
        /// y sont — toutes deux décodées d'abord, pour qu'une valeur mal typée
        /// rende la sauvegarde illisible quelle que soit sa voisine.
        static func point(
            x cleX: Cle, y cleY: Cle, _ chemin: ReferenceWritableKeyPath<Preferences, CGPoint?>
        ) -> Reglage {
            Reglage(ecrire: { prefs, conteneur in
                        let point = prefs[keyPath: chemin]
                        try conteneur.encodeIfPresent(point.map { Double($0.x) }, forKey: cleX)
                        try conteneur.encodeIfPresent(point.map { Double($0.y) }, forKey: cleY)
                    },
                    lire: { conteneur in
                        let x = try conteneur.decodeIfPresent(Double.self, forKey: cleX)
                        let y = try conteneur.decodeIfPresent(Double.self, forKey: cleY)
                        guard let x, let y else { return nil }
                        return { $0[keyPath: chemin] = CGPoint(x: x, y: y) }
                    })
        }
    }

    /// La sauvegarde à écrire : chaque réglage, puis la génération courante.
    @MainActor
    private struct Ecriture: @MainActor Encodable {
        let prefs: Preferences

        func encode(to encoder: any Encoder) throws {
            var conteneur = encoder.container(keyedBy: Cle.self)
            for reglage in Preferences.reglages { try reglage.ecrire(prefs, &conteneur) }
            try conteneur.encode(Preferences.defaultsVersion, forKey: Preferences.cleGeneration)
        }
    }

    /// Une sauvegarde relue : les affectations à faire, et sa génération.
    @MainActor
    private struct Lecture: @MainActor Decodable {
        let affectations: [@MainActor (Preferences) -> Void]
        let generation: Int?

        init(from decoder: any Decoder) throws {
            let conteneur = try decoder.container(keyedBy: Cle.self)
            affectations = try Preferences.reglages.compactMap { try $0.lire(conteneur) }
            generation = try conteneur.decodeIfPresent(Int.self, forKey: Preferences.cleGeneration)
        }
    }
}
