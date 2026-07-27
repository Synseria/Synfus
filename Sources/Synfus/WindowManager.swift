import AppKit
import ApplicationServices

/// Une fenêtre de client Dofus, c'est-à-dire un perso connecté.
struct DofusClient: Identifiable, Hashable {
    let pid: pid_t
    let slotKey: String
    let axWindow: AXUIElement
    let rawTitle: String
    let name: String
    /// Icône affichée dans le Dock par ce client. Dofus y place le symbole de la
    /// classe du perso, ce qui en fait un repère visuel bien plus rapide à lire
    /// qu'un nom. Volontairement exclue de `==` : elle ne change pas en cours de
    /// session, et la comparer à chaque rafraîchissement coûterait plus cher que
    /// ça ne rapporte.
    let icon: NSImage?
    /// Classe du perso, lue dans le titre de la fenêtre
    /// (« Syn-App - Feca - 3.6.7.7 - Release » → « Feca »).
    let characterClass: String?

    var id: String { slotKey }

    static func == (lhs: DofusClient, rhs: DofusClient) -> Bool {
        lhs.slotKey == rhs.slotKey && lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(slotKey)
    }
}

@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()

    /// Persos connectés, déjà triés selon l'ordre de préférence.
    @Published private(set) var clients: [DofusClient] = []
    @Published private(set) var frontmostPID: pid_t?
    @Published private(set) var accessibilityGranted = false

    private var timer: Timer?
    private let prefs = Preferences.shared

    private init() {}

    func start() {
        accessibilityGranted = AXIsProcessTrusted()

        let center = NSWorkspace.shared.notificationCenter
        for note in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            center.addObserver(forName: note, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                    FloatingBarController.shared.updateVisibility()
                }
            }
        }

        // Les titres de fenêtres changent sans émettre de notification système
        // (reconnexion, changement de perso), d'où ce rafraîchissement régulier.
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    // MARK: - Découverte

    func refresh() {
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted { accessibilityGranted = granted }
        frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        guard granted else {
            if !clients.isEmpty { clients = [] }
            return
        }

        var found: [DofusClient] = []
        var usedNames: [String: Int] = [:]

        for app in NSWorkspace.shared.runningApplications {
            guard isDofus(app) else { continue }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement]
            else { continue }

            for (index, window) in windows.enumerated() {
                guard isGameWindow(window) else { continue }

                let rawTitle = stringAttribute(window, kAXTitleAttribute) ?? ""
                var name = Self.characterName(fromTitle: rawTitle)

                // Deux persos peuvent porter un titre identique (ou vide) : on les
                // distingue visuellement plutôt que de les laisser se confondre.
                let seen = usedNames[name, default: 0] + 1
                usedNames[name] = seen
                if seen > 1 { name = "\(name) (\(seen))" }

                found.append(DofusClient(
                    pid: app.processIdentifier,
                    slotKey: "\(app.processIdentifier)#\(index)",
                    axWindow: window,
                    rawTitle: rawTitle,
                    name: name,
                    icon: app.icon,
                    characterClass: Self.characterClass(fromTitle: rawTitle)
                ))
            }
        }

        prefs.registerIfNeeded(names: found.map(\.name))

        let order = prefs.characterOrder
        found.sort { lhs, rhs in
            let li = order.firstIndex(of: lhs.name) ?? Int.max
            let ri = order.firstIndex(of: rhs.name) ?? Int.max
            if li != ri { return li < ri }
            return lhs.pid < rhs.pid
        }

        if found != clients { clients = found }
    }

    private func isDofus(_ app: NSRunningApplication) -> Bool {
        // On teste le bundle ID en minuscules : l'Info.plist déclare
        // « com.Ankama.Dofus », mais mieux vaut ne pas dépendre de la casse.
        // Le launcher (com.ankama.zaap) ne contient pas « dofus », il est donc
        // naturellement exclu.
        guard let bundle = app.bundleIdentifier?.lowercased() else { return false }
        return bundle.contains("dofus")
    }

    private func isGameWindow(_ window: AXUIElement) -> Bool {
        if let subrole = stringAttribute(window, kAXSubroleAttribute),
           subrole != kAXStandardWindowSubrole as String {
            return false
        }
        // Écarte les palettes et fenêtres de service, qui sont toujours petites.
        guard let size = sizeAttribute(window, kAXSizeAttribute) else { return true }
        return size.width > 200 && size.height > 200
    }

    /// Extrait le nom du perso du titre de la fenêtre. Le client Dofus n'a pas de
    /// format garanti : on prend ce qui précède le premier séparateur, et à défaut
    /// le titre entier. Le panneau de diagnostic affiche les titres bruts pour
    /// vérifier ce que ça donne réellement.
    static func characterName(fromTitle title: String) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Sans titre" }

        for separator in [" - ", " – ", " — ", " | ", " • "] {
            guard let range = cleaned.range(of: separator) else { continue }
            let head = String(cleaned[..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            if !head.isEmpty && head.lowercased() != "dofus" {
                return head
            }
        }
        return cleaned
    }

    /// Deuxième segment du titre. Le client Dofus y place la classe, juste après
    /// le nom du perso — plus fiable que l'icône du Dock, identique pour tous les
    /// clients puisqu'ils partagent le même bundle.
    static func characterClass(fromTitle title: String) -> String? {
        let parts = title.components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }
        let candidate = parts[1]
        // Écarte un numéro de version qui occuperait cette position.
        guard !candidate.isEmpty,
              candidate.rangeOfCharacter(from: .letters) != nil,
              !candidate.allSatisfy({ $0.isNumber || $0 == "." })
        else { return nil }
        return candidate
    }

    // MARK: - Focus

    func focus(slot: Int) {
        guard slot >= 0, slot < clients.count else {
            NSSound.beep()
            return
        }
        focus(clients[slot])
    }

    func focus(_ client: DofusClient) {
        if let minimized = boolAttribute(client.axWindow, kAXMinimizedAttribute), minimized {
            AXUIElementSetAttributeValue(client.axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementSetAttributeValue(client.axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(client.axWindow, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: client.pid)?.activate()
        frontmostPID = client.pid
        AttentionWatcher.shared.clear(client)
    }

    func cycle(by step: Int) {
        guard !clients.isEmpty else {
            NSSound.beep()
            return
        }
        // Depuis Chrome ou Discord, on ne « cycle » pas : on revient au premier perso.
        guard let current = currentIndex else {
            focus(clients[0])
            return
        }
        let count = clients.count
        let next = ((current + step) % count + count) % count
        focus(clients[next])
    }

    var currentIndex: Int? {
        guard let pid = frontmostPID else { return nil }
        return clients.firstIndex { $0.pid == pid }
    }

    func isFrontmost(_ client: DofusClient) -> Bool {
        client.pid == frontmostPID
    }

    // MARK: - Lecture d'attributs Accessibilité

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? Bool)
    }

    private func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == AXValueGetTypeID()
        else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    /// Ouvre le panneau Accessibilité, en demandant d'abord à macOS d'afficher
    /// sa propre invite si l'app n'a jamais été autorisée.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
