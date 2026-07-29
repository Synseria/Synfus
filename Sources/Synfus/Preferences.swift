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

    /// N'afficher la barre que lorsque Dofus est au premier plan.
    @Published var barOnlyWithDofus: Bool = false { didSet { save() } }

    /// Recentrer la barre en haut de l'écran tant qu'elle n'a pas été déplacée
    /// à la main.
    @Published var autoCenterBar: Bool = true { didSet { save() } }

    /// Icône du `NSStatusItem`. Le rafraîchissement est à la charge de l'appelant
    /// (`MenuBarController.refreshIcon()`) : les préférences ne pilotent pas l'UI.
    @Published var menuBarIcon: MenuBarIcon = .logo { didSet { save() } }

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
        var barOnlyWithDofus: Bool?
        var autoCenterBar: Bool?
        var menuBarIcon: MenuBarIcon?
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
            barOnlyWithDofus: barOnlyWithDofus,
            autoCenterBar: autoCenterBar,
            menuBarIcon: menuBarIcon
        )
        if let data = try? JSONEncoder().encode(stored) {
            store.enregistrer(data, pour: Self.key)
        }
    }

    private func load() {
        loading = true
        defer {
            loading = false
            resizeHotKeys()
        }

        guard let data = store.donnees(pour: Self.key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else {
            // Premier lancement : ⌘1 à ⌘5 pour l'accès direct.
            slotCount = 5
            hotKeys = (0..<5).map { HotKey.defaultHotKey(slot: $0) }
            // Cycle sur ⌃⇥ et non ⌘⇥ : macOS réserve ⌘⇥ pour son sélecteur
            // d'applications et refuserait purement et simplement de nous l'attribuer.
            cycleNext = HotKey(keyCode: 48, modifiers: UInt32(controlKey))
            cyclePrevious = HotKey(keyCode: 48, modifiers: UInt32(controlKey) | UInt32(shiftKey))
            // ⌘@ : la touche sous Échap sur un clavier Mac français.
            toggleAutoFocus = HotKey(keyCode: 50, modifiers: UInt32(cmdKey))
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
        toggleAutoFocus = stored.toggleAutoFocus ?? HotKey(keyCode: 50, modifiers: UInt32(cmdKey))
        barOnlyWithDofus = stored.barOnlyWithDofus ?? false
        autoCenterBar = stored.autoCenterBar ?? true
        menuBarIcon = stored.menuBarIcon ?? .logo
        if let x = stored.barOriginX, let y = stored.barOriginY {
            barOrigin = CGPoint(x: x, y: y)
        }
    }
}
