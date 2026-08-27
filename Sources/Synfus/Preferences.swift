import AppKit
import Carbon.HIToolbox

/// Où les réglages sont rangés. `UserDefaults` en production.
///
/// Cette indirection existe pour les tests : un `UserDefaults(suiteName:)` crée
/// un domaine persistant que `removePersistentDomain` ne supprime pas vraiment —
/// `cfprefsd` réécrit le fichier derrière, et la machine finit constellée de
/// plists de test dans `~/Library/Preferences`. Les tests se donnent donc un
/// stockage en mémoire.
///
/// Les noms diffèrent de ceux de `UserDefaults` à dessein : une surcharge de
/// `set(_:forKey:)` entrerait en ambiguïté avec la version `Any?` existante.
protocol PreferencesStore: AnyObject {
    func donnees(pour cle: String) -> Data?
    func enregistrer(_ donnees: Data, pour cle: String)
}

extension UserDefaults: PreferencesStore {
    func donnees(pour cle: String) -> Data? { data(forKey: cle) }
    func enregistrer(_ donnees: Data, pour cle: String) { set(donnees, forKey: cle) }
}

/// Ce que Synfus affiche dans la barre de menus du système.
enum MenuBarIcon: String, Codable, CaseIterable, Identifiable {
    case logo
    case symbole

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logo: return "Logo Synfus"
        case .symbole: return "Symbole système"
        }
    }
}

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

    /// Rendre disponible le mode « enchaîner » : chaque clic sur un client de
    /// jeu passe au perso suivant tant que le mode est actif. Éteint par défaut
    /// — il installe un moniteur global de souris, et personne n'a demandé ça en
    /// installant l'app.
    @Published var advanceOnClick: Bool = false { didSet { save() } }

    /// Raccourci qui active ou coupe le mode. Il n'est réservé auprès du système
    /// que lorsque `advanceOnClick` est vrai : lui donner un défaut ne confisque
    /// donc rien à qui n'utilise pas la fonction.
    @Published var advanceArmHotKey: HotKey? = .defaultAdvanceArm { didSet { save() } }

    /// Icône du `NSStatusItem`. Le rafraîchissement est à la charge de l'appelant
    /// (`MenuBarController.refreshIcon()`) : les préférences ne pilotent pas l'UI.
    @Published var menuBarIcon: MenuBarIcon = .logo { didSet { save() } }

    /// Dernière disposition de rangement appliquée — celle que rejoue le
    /// raccourci. `nil` = jamais rangé.
    @Published var lastArrangement: Disposition? = nil { didSet { save() } }

    /// Raccourci de rangement des fenêtres. Sans défaut, comme `toggleBar` :
    /// une combinaison réservée au système est une combinaison prise à
    /// l'utilisateur.
    @Published var arrangeHotKey: HotKey? { didSet { save() } }

    /// Nombre de slots exposés (et donc de raccourcis potentiels).
    ///
    /// Le garde-fou `clamping` n'est pas décoratif : `@Published` remplace la
    /// propriété stockée par une propriété calculée, donc réassigner `slotCount`
    /// depuis son propre `didSet` le redéclenche au lieu de court-circuiter comme
    /// le ferait une propriété stockée classique — et part en récursion infinie.
    @Published var slotCount: Int = 5 {
        didSet {
            guard !clamping else { return }
            let clamped = min(max(slotCount, 1), HotKey.digitRow.count)
            if clamped != slotCount {
                clamping = true
                slotCount = clamped
                clamping = false
            }
            resizeHotKeys()
            save()
        }
    }

    private var clamping = false
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

    private func resizeHotKeys() {
        if hotKeys.count < slotCount {
            for slot in hotKeys.count..<slotCount {
                hotKeys.append(HotKey.defaultHotKey(slot: slot))
            }
        } else if hotKeys.count > slotCount {
            hotKeys.removeSubrange(slotCount...)
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
        characterOrder.removeAll { $0 == name }
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
    }

    // MARK: - Persistance

    private struct Stored: Codable {
        var characterOrder: [String]
        var hotKeys: [HotKey?]
        var cycleNext: HotKey?
        var cyclePrevious: HotKey?
        var barVisible: Bool
        var barOriginX: Double?
        var barOriginY: Double?
        var showNumbers: Bool
        var slotCount: Int
        var showClasses: Bool?
        var attentionAction: AttentionAction?
        var toggleAutoFocus: HotKey?
        var toggleBar: HotKey?
        var barOnlyWithDofus: Bool?
        var autoCenterBar: Bool?
        var menuBarIcon: MenuBarIcon?
        var showPreviewOnHover: Bool?
        var previewHotKey: HotKey?
        var advanceOnClick: Bool?
        var advanceArmHotKey: HotKey?
        var lastArrangement: Disposition?
        var arrangeHotKey: HotKey?
        /// Génération du jeu de raccourcis par défaut appliqué à cette
        /// sauvegarde. Absente des sauvegardes d'avant la refonte, d'où le repli
        /// sur 1 à la lecture.
        var defaultsVersion: Int?
    }

    /// Génération courante des raccourcis par défaut. À incrémenter — avec la
    /// reprise correspondante dans `adoptDefaults` — chaque fois que les défauts
    /// changent, sans quoi les installations existantes resteraient sur les
    /// anciens à jamais.
    static let defaultsVersion = 5

    /// Les défauts de la génération 1, ceux qu'une installation existante peut
    /// encore porter sans que l'utilisateur les ait choisis. Seules ces
    /// valeurs-là sont reprises : un raccourci personnalisé, ou effacé
    /// délibérément, n'est jamais réécrit.
    private static let legacyCycleNext = HotKey(keyCode: 48, modifiers: UInt32(controlKey))
    private static let legacyCyclePrevious = HotKey(
        keyCode: 48, modifiers: UInt32(controlKey) | UInt32(shiftKey))
    private static let legacyToggleAutoFocus = HotKey(keyCode: 50, modifiers: UInt32(cmdKey))

    /// Fait passer une sauvegarde ancienne au jeu de raccourcis courant.
    ///
    /// ⌘@ change de rôle : il ouvrait la bascule du passage automatique, il fait
    /// désormais avancer dans la barre — le geste que l'on répète le plus, sur la
    /// touche la plus facile à atteindre. La bascule glisse d'un modificateur, et
    /// l'aperçu d'ensemble reçoit enfin un défaut.
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

        // La bascule du mode « enchaîner » est arrivée après coup : une
        // sauvegarde plus ancienne que la clé ne l'a jamais eue. Rien n'est
        // confisqué pour autant — ce raccourci n'est réservé auprès du système
        // que lorsque la fonction est activée, et elle est éteinte par défaut.
        if from < 4, advanceArmHotKey == nil { advanceArmHotKey = .defaultAdvanceArm }

        // La génération 4 la posait sur ⌃⌥⌘@ — trois modificateurs pour une
        // bascule que l'on presse deux fois par session. C'était la première
        // combinaison libre trouvée, pas la plus simple.
        if from < 5, advanceArmHotKey == Self.legacyAdvanceArm {
            advanceArmHotKey = .defaultAdvanceArm
        }
        return true
    }

    private static var legacyAdvanceArm: HotKey {
        HotKey(
            keyCode: HotKey.escapeRowKey,
            modifiers: UInt32(cmdKey) | UInt32(controlKey) | UInt32(optionKey)
        )
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

    private func save() {
        guard !loading else { return }
        let stored = Stored(
            characterOrder: characterOrder,
            hotKeys: hotKeys,
            cycleNext: cycleNext,
            cyclePrevious: cyclePrevious,
            barVisible: barVisible,
            barOriginX: barOrigin.map { Double($0.x) },
            barOriginY: barOrigin.map { Double($0.y) },
            showNumbers: showNumbers,
            slotCount: slotCount,
            showClasses: showClasses,
            attentionAction: attentionAction,
            toggleAutoFocus: toggleAutoFocus,
            toggleBar: toggleBar,
            barOnlyWithDofus: barOnlyWithDofus,
            autoCenterBar: autoCenterBar,
            menuBarIcon: menuBarIcon,
            showPreviewOnHover: showPreviewOnHover,
            previewHotKey: previewHotKey,
            advanceOnClick: advanceOnClick,
            advanceArmHotKey: advanceArmHotKey,
            lastArrangement: lastArrangement,
            arrangeHotKey: arrangeHotKey,
            defaultsVersion: Self.defaultsVersion
        )
        if let data = try? JSONEncoder().encode(stored) {
            store.enregistrer(data, pour: Self.key)
        }
    }

    private func load() {
        loading = true

        guard let data = store.donnees(pour: Self.key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else {
            // Premier lancement : ⌘1 à ⌘5 pour l'accès direct, et toute la
            // navigation sur la touche sous Échap.
            slotCount = 5
            hotKeys = (0..<5).map { HotKey.defaultHotKey(slot: $0) }
            cycleNext = .defaultCycleNext
            cyclePrevious = .defaultCyclePrevious
            toggleAutoFocus = .defaultToggleAutoFocus
            previewHotKey = .defaultPreview
            loading = false
            resizeHotKeys()
            return
        }

        characterOrder = stored.characterOrder
        hotKeys = stored.hotKeys
        cycleNext = stored.cycleNext
        cyclePrevious = stored.cyclePrevious
        barVisible = stored.barVisible
        showNumbers = stored.showNumbers
        slotCount = stored.slotCount
        showClasses = stored.showClasses ?? true
        attentionAction = stored.attentionAction ?? .highlight
        // Sans repli : un raccourci vide est un choix. Les sauvegardes plus
        // anciennes que la clé sont rattrapées par `adoptDefaults`, une fois.
        toggleAutoFocus = stored.toggleAutoFocus
        toggleBar = stored.toggleBar
        barOnlyWithDofus = stored.barOnlyWithDofus ?? false
        autoCenterBar = stored.autoCenterBar ?? true
        menuBarIcon = stored.menuBarIcon ?? .logo
        showPreviewOnHover = stored.showPreviewOnHover ?? false
        previewHotKey = stored.previewHotKey
        advanceOnClick = stored.advanceOnClick ?? false
        advanceArmHotKey = stored.advanceArmHotKey
        lastArrangement = stored.lastArrangement
        arrangeHotKey = stored.arrangeHotKey
        if let x = stored.barOriginX, let y = stored.barOriginY {
            barOrigin = CGPoint(x: x, y: y)
        }

        loading = false
        resizeHotKeys()
        // La reprise se fait le drapeau `loading` relâché : c'est elle, et elle
        // seule, qui doit réécrire la sauvegarde — ne serait-ce que pour y
        // inscrire la génération, sans quoi elle se rejouerait à chaque lancement.
        if adoptDefaults(from: stored.defaultsVersion) { save() }
    }
}
