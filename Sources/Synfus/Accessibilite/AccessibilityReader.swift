import AppKit
import ApplicationServices

/// Poignée d'un élément Accessibilité, faite pour traverser les frontières
/// d'isolation.
///
/// Hypothèse documentée : un `AXUIElementRef` est un jeton immuable — pid,
/// identifiant distant — et le client HIServices est sûr d'un fil à l'autre,
/// chaque appel étant un message Mach indépendant. Rien n'est partagé côté
/// Synfus, seule la valeur circule ; d'où le `@unchecked Sendable`.
struct AXHandle: @unchecked Sendable, Hashable {
    let element: AXUIElement

    init(_ element: AXUIElement) { self.element = element }

    /// L'élément d'une application, par pid. Aucun IPC : c'est une adresse.
    static func application(_ pid: pid_t) -> AXHandle {
        AXHandle(AXUIElementCreateApplication(pid))
    }
}

/// L'unique foyer des lectures et écritures Accessibilité du projet.
///
/// Ni `@MainActor` ni état : tout est appelable du main comme de l'acteur
/// d'inventaire. Chaque fonction est un IPC synchrone vers le processus
/// propriétaire de l'élément, borné par `AXUIElementSetMessagingTimeout` sur
/// l'élément système — une borne **par processus**, posée dans
/// `WindowManager.start()`, qui vaut donc pour tous les fils.
enum AccessibilityReader {

    // MARK: - Lectures brutes

    static func value(_ element: AXHandle, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element.element, attribute as CFString, &result) == .success
        else { return nil }
        return result
    }

    static func stringAttribute(_ element: AXHandle, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    static func boolAttribute(_ element: AXHandle, _ attribute: String) -> Bool? {
        value(element, attribute) as? Bool
    }

    static func pointAttribute(_ element: AXHandle, _ attribute: String) -> CGPoint? {
        guard let raw = value(element, attribute) else { return nil }
        return point(raw)
    }

    static func sizeAttribute(_ element: AXHandle, _ attribute: String) -> CGSize? {
        guard let raw = value(element, attribute) else { return nil }
        return size(raw)
    }

    static func children(_ element: AXHandle) -> [AXHandle] {
        guard let list = value(element, kAXChildrenAttribute) as? [AXUIElement] else { return [] }
        return list.map(AXHandle.init)
    }

    /// Tous les noms d'attributs que l'élément expose — le mode exploration.
    static func attributeNames(_ element: AXHandle) -> [String] {
        var names: CFArray?
        AXUIElementCopyAttributeNames(element.element, &names)
        return names as? [String] ?? []
    }

    // MARK: - Fenêtres d'une application

    /// Réponse à `kAXWindows`. La distinction muet / autre échec est celle du
    /// veilleur de gel : un client gelé laisse expirer la borne
    /// (`.cannotComplete`), un client sain sans fenêtre rend une liste vide.
    enum WindowsAnswer {
        case windows([AXHandle])
        case mute
        case failed(AXError)
    }

    static func windows(of app: AXHandle) -> WindowsAnswer {
        var raw: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app.element, kAXWindowsAttribute as CFString, &raw)
        if error == .cannotComplete { return .mute }
        guard error == .success else { return .failed(error) }
        guard let list = raw as? [AXUIElement] else { return .windows([]) }
        return .windows(list.map(AXHandle.init))
    }

    /// Ce que l'inventaire veut savoir d'une fenêtre, lu en un seul appel.
    struct WindowFacts: Sendable, Equatable {
        var subrole: String?
        var size: CGSize?
        var title: String?
    }

    /// Sous-rôle, taille et titre en **un** IPC — `AXUIElementCopyMultipleAttributeValues`
    /// — là où trois lectures séparées en coûtaient trois par fenêtre et par
    /// tour. Sans `stopOnError`, un attribut absent arrive sous la forme d'un
    /// `AXValue` de type `.axError` à sa place : la fenêtre reste lue pour le
    /// reste, comme avant.
    static func windowFacts(_ window: AXHandle) -> WindowFacts {
        guard let raw = multiple(window, [kAXSubroleAttribute, kAXSizeAttribute, kAXTitleAttribute])
        else { return windowFactsOneByOne(window) }
        var facts = WindowFacts()
        facts.subrole = raw[0] as? String
        facts.size = size(raw[1])
        facts.title = raw[2] as? String
        return facts
    }

    /// Repli attribut par attribut si la lecture groupée échoue en bloc : un
    /// client qui refuserait cet appel (ou une version d'AX qui le boude)
    /// verrait sinon toutes ses fenêtres prises pour « sans titre », donc
    /// écartées — le perso disparaîtrait de la barre sans explication.
    private static func windowFactsOneByOne(_ window: AXHandle) -> WindowFacts {
        WindowFacts(
            subrole: stringAttribute(window, kAXSubroleAttribute),
            size: sizeAttribute(window, kAXSizeAttribute),
            title: stringAttribute(window, kAXTitleAttribute)
        )
    }

    /// Position et taille en un seul IPC — le relevé du Dock, dix fois par
    /// seconde. `nil` dès qu'une des deux valeurs manque : l'élément ne répond
    /// plus comme attendu.
    static func frame(of element: AXHandle) -> CGRect? {
        guard let raw = multiple(element, [kAXPositionAttribute, kAXSizeAttribute]),
              let position = point(raw[0]), let size = size(raw[1])
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Une fenêtre de jeu : sous-rôle standard (ou inconnu), et assez grande.
    /// Écarte les palettes, info-bulles et fenêtres de service, toujours
    /// petites ; une taille illisible ne condamne pas. C'est le **seul** seuil :
    /// l'inventaire, les aperçus, le relevé à travers les espaces et
    /// `--dump-windows` passent tous ici.
    static func isGameWindow(subrole: String?, size: CGSize?) -> Bool {
        if let subrole, subrole != kAXStandardWindowSubrole as String {
            return false
        }
        guard let size else { return true }
        return size.width > 200 && size.height > 200
    }

    static func isGameWindow(_ window: AXHandle) -> Bool {
        let facts = windowFacts(window)
        return isGameWindow(subrole: facts.subrole, size: facts.size)
    }

    // MARK: - Écritures

    @discardableResult
    static func set(_ element: AXHandle, _ attribute: String, _ value: CFTypeRef) -> AXError {
        AXUIElementSetAttributeValue(element.element, attribute as CFString, value)
    }

    @discardableResult
    static func set(_ element: AXHandle, position: CGPoint) -> AXError {
        var point = position
        guard let value = AXValueCreate(.cgPoint, &point) else { return .failure }
        return set(element, kAXPositionAttribute, value)
    }

    @discardableResult
    static func set(_ element: AXHandle, size: CGSize) -> AXError {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return .failure }
        return set(element, kAXSizeAttribute, value)
    }

    @discardableResult
    static func perform(_ element: AXHandle, action: String) -> AXError {
        AXUIElementPerformAction(element.element, action as CFString)
    }

    // MARK: - Décodage

    /// Plusieurs attributs en un IPC. `nil` si l'appel échoue en bloc ; sinon
    /// une valeur par attribut, éventuellement un `AXValue` d'erreur.
    private static func multiple(_ element: AXHandle, _ attributes: [String]) -> [AnyObject]? {
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(
            element.element, attributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values
        ) == .success,
            let raw = values as? [AnyObject], raw.count == attributes.count
        else { return nil }
        return raw
    }

    private static func point(_ raw: AnyObject) -> CGPoint? {
        guard CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        var point = CGPoint.zero
        guard AXValueGetType(value) == .cgPoint, AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(_ raw: AnyObject) -> CGSize? {
        guard CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        var size = CGSize.zero
        guard AXValueGetType(value) == .cgSize, AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }
}

/// Les processus Dofus. L'unique endroit qui sait reconnaître un client.
enum DofusProcesses {
    /// On teste le bundle ID en minuscules : l'Info.plist déclare
    /// « com.Ankama.Dofus », mais mieux vaut ne pas dépendre de la casse. Le
    /// launcher (com.ankama.zaap) ne contient pas « dofus », il est donc
    /// naturellement exclu.
    nonisolated static func isDofusBundle(_ bundleID: String?) -> Bool {
        guard let bundle = bundleID?.lowercased() else { return false }
        return bundle.contains("dofus")
    }

    /// Les clients lancés, dans l'ordre de `runningApplications` — c'est cet
    /// ordre qui suffixe les homonymes, il ne doit pas changer d'un tour à l'autre.
    @MainActor static func running() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { isDofusBundle($0.bundleIdentifier) }
    }
}
