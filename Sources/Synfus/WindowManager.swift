import AppKit
import ApplicationServices

/// Une fenêtre de client Dofus, c'est-à-dire un perso connecté.
struct DofusClient: Identifiable, Hashable {
    let pid: pid_t
    let slotKey: String
    let axWindow: AXUIElement
    let rawTitle: String
    let name: String
    /// Classe du perso, lue dans le titre de la fenêtre
    /// (« Syn-App - Feca - 3.6.7.7 - Release » → « Feca »).
    let characterClass: String?
    /// Perso connu de mémoire, dont l'Accessibilité ne rend plus la fenêtre —
    /// en pratique, un client dans un espace plein écran qui n'est pas actif.
    /// Il reste cliquable : l'activation du processus suffit à y basculer.
    let dormant: Bool

    var id: String { slotKey }

    /// Le même perso, tel qu'on se le rappelle une fois sa fenêtre hors de vue.
    func remembered() -> DofusClient {
        DofusClient(
            pid: pid, slotKey: slotKey, axWindow: axWindow, rawTitle: rawTitle,
            name: name, characterClass: characterClass, dormant: true
        )
    }

    static func == (lhs: DofusClient, rhs: DofusClient) -> Bool {
        lhs.slotKey == rhs.slotKey && lhs.name == rhs.name && lhs.dormant == rhs.dormant
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
    /// L'app au premier plan est-elle un client Dofus ? Tenu à jour en même temps
    /// que `frontmostPID`, pour que la barre puisse décider de sa visibilité sans
    /// refaire le tour des applications.
    @Published private(set) var frontmostIsDofus = false
    @Published private(set) var accessibilityGranted = false

    private var timer: Timer?
    private let prefs = Preferences.shared

    /// Fin du dernier inventaire, et attente déjà programmée. Cf. `refreshSoon()`.
    private var lastRefresh = Date.distantPast
    private var refreshScheduled = false

    /// Délai minimal entre deux inventaires déclenchés par notification.
    private static let refreshInterval: TimeInterval = 0.2

    /// Derniers persos vus pour chaque processus. La clé est le pid : il vit
    /// aussi longtemps que le client, alors que la fenêtre, elle, va et vient
    /// au gré des espaces.
    private var rememberedClients: [pid_t: [DofusClient]] = [:]

    private init() {}

    func start() {
        accessibilityGranted = AXIsProcessTrusted()

        // Les versions du client et les homonymes suffixés ont pu s'enregistrer
        // avant que le filtre n'existe : ils encombreraient la liste indéfiniment.
        prefs.purgeOrder(keeping: Self.isPersistableName)

        let center = NSWorkspace.shared.notificationCenter

        // L'application au premier plan change : la barre doit suivre *tout de
        // suite*. On lit l'app dans la notification plutôt que `frontmostApplication`,
        // qui est encore en retard d'un tour à cet instant précis, et on décide de
        // la visibilité avant de rafraîchir — l'inventaire des fenêtres passe par
        // l'Accessibilité, dont un client occupé met parfois plusieurs centaines de
        // millisecondes à répondre. La barre n'a pas à attendre cela.
        for note in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didDeactivateApplicationNotification] {
            center.addObserver(forName: note, object: nil, queue: .main) { [weak self] notification in
                // La notification elle-même ne peut pas franchir la frontière du
                // main actor sous concurrence stricte : on en tire tout de suite
                // les deux valeurs utiles, qui sont, elles, des types simples.
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let pid = app?.processIdentifier
                let bundleID = app?.bundleIdentifier
                let activated = note == NSWorkspace.didActivateApplicationNotification

                MainActor.assumeIsolated {
                    if activated, let pid {
                        self?.setFrontmost(pid: pid, bundleID: bundleID)
                    } else {
                        // Une désactivation ne dit pas qui prend la relève : là,
                        // `frontmostApplication` est à jour, ou le sera au prochain
                        // tour de timer.
                        self?.setFrontmost(NSWorkspace.shared.frontmostApplication)
                    }
                    FloatingBarController.shared.updateVisibility()
                    self?.refreshSoon()
                }
            }
        }

        for note in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: note, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshSoon()
                    FloatingBarController.shared.updateVisibility()
                }
            }
        }

        // Passer en plein écran ou changer de bureau ne réactive aucune app : sans
        // cette notification, la barre resterait derrière le nouvel espace.
        center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { FloatingBarController.shared.updateVisibility() }
        }

        // Les titres de fenêtres changent sans émettre de notification système
        // (reconnexion, changement de perso), d'où ce rafraîchissement régulier.
        // Il sert aussi de filet : une notification manquée figerait sinon la
        // barre dans un état faux jusqu'au prochain changement d'application.
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                FloatingBarController.shared.updateVisibility()
            }
        }
        refresh()
    }

    /// Mémorise l'application de premier plan et si c'est un client Dofus.
    private func setFrontmost(_ app: NSRunningApplication?) {
        setFrontmost(pid: app?.processIdentifier, bundleID: app?.bundleIdentifier)
    }

    private func setFrontmost(pid: pid_t?, bundleID: String?) {
        frontmostPID = pid
        frontmostIsDofus = Self.isDofusBundle(bundleID)
    }

    // MARK: - Découverte

    /// Inventaire regroupé, pour les rafales de notifications.
    ///
    /// Passer d'une application à l'autre en émet deux — une désactivation et
    /// une activation —, chacune réclamant un inventaire. Or celui-ci passe par
    /// l'Accessibilité, dont un client occupé met parfois plusieurs centaines de
    /// millisecondes à répondre : en enchaîner deux, c'est doubler ce gel au
    /// moment précis où l'utilisateur bascule. Le second est donc retardé, et
    /// fondu dans le premier s'ils se suivent de près.
    ///
    /// La visibilité de la barre, elle, n'attend pas : elle se décide sur le pid
    /// que porte la notification, sans rien demander à l'Accessibilité.
    func refreshSoon() {
        let elapsed = Date().timeIntervalSince(lastRefresh)
        guard elapsed >= Self.refreshInterval else {
            guard !refreshScheduled else { return }
            refreshScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.refreshInterval - elapsed) {
                MainActor.assumeIsolated {
                    self.refreshScheduled = false
                    self.refresh()
                }
            }
            return
        }
        refresh()
    }

    func refresh() {
        lastRefresh = Date()
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted { accessibilityGranted = granted }
        setFrontmost(NSWorkspace.shared.frontmostApplication)

        guard granted else {
            if !clients.isEmpty { clients = [] }
            return
        }

        var found: [DofusClient] = []
        var usedNames: [String: Int] = [:]
        var livePIDs: Set<pid_t> = []
        var talkativePIDs: Set<pid_t> = []

        for app in NSWorkspace.shared.runningApplications {
            guard isDofus(app) else { continue }
            livePIDs.insert(app.processIdentifier)
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement]
            else { continue }

            // Un client qui rend au moins une fenêtre est joignable : s'il n'en
            // ressort aucun perso, c'est qu'il est retourné à l'écran de
            // connexion, et non qu'il se cache sur un autre bureau.
            if !windows.isEmpty { talkativePIDs.insert(app.processIdentifier) }

            for (index, window) in windows.enumerated() {
                guard isGameWindow(window) else { continue }

                let rawTitle = stringAttribute(window, kAXTitleAttribute) ?? ""
                guard Self.isCharacterWindow(title: rawTitle) else { continue }

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
                    characterClass: Self.characterClass(fromTitle: rawTitle),
                    dormant: false
                ))
            }
        }

        // Un client dont l'espace plein écran n'est pas actif ne rend plus
        // *aucune* fenêtre à l'Accessibilité : il retire la sienne de l'ordre
        // d'affichage, et `kAXWindows` ne liste que ce qui s'y trouve. Sans
        // mémoire, le perso disparaîtrait de la barre à chaque fois qu'on le
        // quitte — et son icône du Dock, elle, resterait, décalant l'appariement
        // de la détection d'attention.
        remember(found)
        forgetDeadProcesses(livePIDs: livePIDs)
        found = Self.withRemembered(
            found: found,
            remembered: rememberedClients,
            silentPIDs: livePIDs.subtracting(talkativePIDs)
        )

        // Seuls les vrais noms de persos entrent dans la liste ; les clients au
        // login et les homonymes suffixés restent dans la barre sans s'y inscrire.
        prefs.registerIfNeeded(names: found.map(\.name).filter(Self.isPersistableName))

        let order = prefs.characterOrder
        found.sort { lhs, rhs in
            let li = order.firstIndex(of: lhs.name) ?? Int.max
            let ri = order.firstIndex(of: rhs.name) ?? Int.max
            if li != ri { return li < ri }
            return lhs.pid < rhs.pid
        }

        if found != clients {
            clients = found
            // Les vignettes des persos déconnectés n'ont plus de sens, et leur
            // `slotKey` sera repris par un autre client au prochain lancement.
            WindowPreviewService.shared.prune(keeping: found)
        }
    }

    /// Retient les persos effectivement vus, par processus. Un pid dont on ne
    /// voit plus rien garde sa dernière mémoire ; il ne sera oublié qu'à la
    /// fermeture du client (voir `withRemembered`).
    private func remember(_ found: [DofusClient]) {
        for (pid, clients) in Dictionary(grouping: found, by: \.pid) {
            rememberedClients[pid] = clients
        }
    }

    /// Complète les persos trouvés de ceux dont le processus vit encore mais ne
    /// rend plus aucune fenêtre — `silentPIDs`. Isolée et pure : c'est la règle
    /// qui décide ce que la barre affiche, elle mérite d'être testée.
    ///
    /// Un client rendu à l'écran de connexion n'en fait délibérément pas partie :
    /// il rend bien une fenêtre, simplement sans perso. Le ressusciter afficherait
    /// un perso qui n'est plus en jeu.
    static func withRemembered(
        found: [DofusClient],
        remembered: [pid_t: [DofusClient]],
        silentPIDs: Set<pid_t>
    ) -> [DofusClient] {
        let visible = Set(found.map(\.pid))
        let dormant = remembered
            .filter { silentPIDs.contains($0.key) && !visible.contains($0.key) }
            // Tri par pid : le dictionnaire n'a pas d'ordre, et la barre ne doit
            // pas se réorganiser d'un rafraîchissement à l'autre.
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
            .map { $0.remembered() }
        return found + dormant
    }

    /// Oublie les clients fermés — leur pid ne reviendra pas.
    private func forgetDeadProcesses(livePIDs: Set<pid_t>) {
        rememberedClients = rememberedClients.filter { livePIDs.contains($0.key) }
    }

    private func isDofus(_ app: NSRunningApplication) -> Bool {
        Self.isDofusBundle(app.bundleIdentifier)
    }

    /// On teste le bundle ID en minuscules : l'Info.plist déclare
    /// « com.Ankama.Dofus », mais mieux vaut ne pas dépendre de la casse. Le
    /// launcher (com.ankama.zaap) ne contient pas « dofus », il est donc
    /// naturellement exclu.
    static func isDofusBundle(_ bundleID: String?) -> Bool {
        guard let bundle = bundleID?.lowercased() else { return false }
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

    /// Séparateurs rencontrés dans les titres du client selon les versions.
    private static let separators = [" - ", " – ", " — ", " | ", " • "]

    /// Un client qui n'a pas encore de perso en jeu — écran de connexion,
    /// sélection de personnage, chargement — s'intitule simplement « Dofus ».
    /// Ce n'est pas un perso : il n'a rien à faire dans la barre, et lui donner
    /// un emplacement décalerait les raccourcis des vrais persos.
    ///
    /// Un perso connecté porte toujours « Nom - Classe - version - Release ».
    static func isCharacterWindow(title: String) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.lowercased() != "dofus" else { return false }
        return separators.contains { cleaned.contains($0) }
    }

    /// Extrait le nom du perso du titre de la fenêtre. Le client Dofus n'a pas de
    /// format garanti : on prend ce qui précède le premier séparateur, et à défaut
    /// le titre entier. Le panneau de diagnostic affiche les titres bruts pour
    /// vérifier ce que ça donne réellement.
    static func characterName(fromTitle title: String) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Sans titre" }

        for separator in separators {
            guard let range = cleaned.range(of: separator) else { continue }
            let head = String(cleaned[..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            if !head.isEmpty && head.lowercased() != "dofus" {
                return head
            }
        }
        return cleaned
    }

    /// Mots que le client affiche quand il n'a encore personne en jeu. Ils ne
    /// nomment aucun perso, et un nom qui n'est fait que de ceux-là ne mérite
    /// pas d'entrer dans la liste des persos connus.
    private static let clientOnlyWords: Set<String> = ["dofus", "release", "beta", "alpha", "retail"]

    /// Un nom digne d'être mémorisé dans l'ordre des persos.
    ///
    /// Deux formes doivent rester visibles dans la barre — on veut pouvoir
    /// cliquer dessus — sans pour autant s'inscrire à demeure dans les réglages :
    ///
    /// - « Dofus 3.3.4.9 » : un client resté à l'écran de connexion, dont le
    ///   titre n'annonce que la version. Le perso qui s'y connectera portera son
    ///   vrai nom, et cette entrée-là resterait à jamais dans la liste, à changer
    ///   à chaque mise à jour du jeu.
    /// - « Machin (2) » : le suffixe de désambiguïsation ajouté par `refresh()`,
    ///   qui dépend de l'ordre de découverte et ne désigne donc aucun perso en
    ///   propre.
    ///
    /// Non mémorisés, ces clients se retrouvent simplement en fin de barre : le
    /// tri les relègue derrière tous les noms connus, sans décaler personne.
    static func isPersistableName(_ name: String) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !hasDuplicateSuffix(cleaned) else { return false }

        // Découpé sur les espaces et les séparateurs : un titre peut être repris
        // en entier faute de segment exploitable (« Dofus - 3.3.4.9 - Release »).
        let words = cleaned
            .components(separatedBy: CharacterSet(charactersIn: " -–—|•"))
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        return words.contains { !clientOnlyWords.contains($0) && !isVersionNumber($0) }
    }

    /// « Machin (2) » — le suffixe que `refresh()` ajoute lui-même aux homonymes.
    static func hasDuplicateSuffix(_ name: String) -> Bool {
        guard name.hasSuffix(")"), let open = name.lastIndex(of: "(") else { return false }
        let digits = name[name.index(after: open)..<name.index(before: name.endIndex)]
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    /// « 3.3.4.9 », « 2.70 » — des chiffres et des points, rien d'autre.
    static func isVersionNumber(_ word: String) -> Bool {
        !word.isEmpty
            && word.contains(where: \.isNumber)
            && word.allSatisfy { $0.isNumber || $0 == "." }
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
        if !client.dormant,
           let minimized = boolAttribute(client.axWindow, kAXMinimizedAttribute), minimized {
            AXUIElementSetAttributeValue(client.axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        // L'activation vient en premier : c'est elle, et non `AXRaise`, qui fait
        // basculer macOS vers l'espace où vit la fenêtre quand le client est en
        // plein écran. Dans l'ordre inverse, le raise s'appliquait à une fenêtre
        // d'un autre espace et ne menait nulle part.
        NSRunningApplication(processIdentifier: client.pid)?.activate()

        // Les attributs AX ne servent qu'à départager plusieurs fenêtres d'un même
        // processus ; on les pose une fois la transition d'espace engagée. Sur un
        // perso seulement mémorisé, la référence de fenêtre est périmée — il n'y
        // a rien à y poser, l'activation du processus fait tout le travail.
        if !client.dormant {
            let window = client.axWindow
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                MainActor.assumeIsolated {
                    AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                }
            }
        }

        frontmostPID = client.pid
        frontmostIsDofus = true
        AttentionWatcher.shared.clear(client)
    }

    /// Délai de grâce entre la demande polie de fermeture et le coup de grâce.
    /// Assez long pour laisser un client sain écrire sa configuration et
    /// s'éteindre, assez court pour que le geste reste un seul geste.
    private static let closeGracePeriod: TimeInterval = 6

    /// Ferme un client — poliment d'abord, de force s'il ne répond plus.
    ///
    /// Le client gèle systématiquement à la fermeture chez certains joueurs, et
    /// il faut alors passer par « Forcer à quitter ». On automatise ce geste :
    /// un Quit Apple Event (`terminate()`), puis, si le processus est toujours
    /// là après le délai de grâce — un client gelé ignore les Apple Events —,
    /// un `forceTerminate()`. C'est une opération de **processus**, pas une
    /// saisie : la règle « Synfus n'émet aucun évènement » reste entière.
    func close(_ client: DofusClient) {
        guard let app = NSRunningApplication(processIdentifier: client.pid) else { return }
        let pid = client.pid
        app.terminate()
        Timer.scheduledTimer(withTimeInterval: Self.closeGracePeriod, repeats: false) { _ in
            MainActor.assumeIsolated {
                if let survivant = NSRunningApplication(processIdentifier: pid),
                   !survivant.isTerminated {
                    survivant.forceTerminate()
                }
                WindowManager.shared.refreshSoon()
            }
        }
        refreshSoon()
    }

    /// Ferme tous les clients, chacun avec la même escalade. Le geste de fin
    /// de session — sans lui, c'est autant de « Forcer à quitter » que de persos.
    func closeAll() {
        clients.forEach(close)
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
        // `kAXTrustedCheckOptionPrompt` est déclaré `extern CFStringRef` côté C,
        // donc vu comme une variable globale mutable que la concurrence stricte
        // refuse de lire. Sa valeur est une constante d'API : on la cite.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
