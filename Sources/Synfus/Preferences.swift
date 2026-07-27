import AppKit
import Carbon.HIToolbox

/// Réglages persistés dans les UserDefaults, sérialisés en JSON sous une seule clé.
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
    private let key = "fr.dofusyn.preferences"

    private init() {
        load()
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
            autoCenterBar: autoCenterBar
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        loading = true
        defer {
            loading = false
            resizeHotKeys()
        }

        guard let data = UserDefaults.standard.data(forKey: key),
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
        if let x = stored.barOriginX, let y = stored.barOriginY {
            barOrigin = CGPoint(x: x, y: y)
        }
    }
}
