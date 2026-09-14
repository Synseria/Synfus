import AppKit
import ApplicationServices

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

    /// Clients en cours de fermeture. Tant qu'un pid y figure, l'inventaire ne
    /// l'interroge plus — questionner l'Accessibilité d'un mourant, c'est payer
    /// la borne d'une seconde à chaque tour — et sa pastille porte l'indicateur
    /// d'attente. Le pid en sort quand le processus meurt.
    @Published private(set) var closingPIDs: Set<pid_t> = []

    /// Processus à qui l'on ne pose plus de question Accessibilité par un
    /// **geste** : ceux qui se ferment, et ceux que le veilleur de gel tient
    /// pour suspects. `focus()` se contente alors d'activer le processus, et
    /// l'arrangeur les écarte. L'inventaire, lui, resonde un suspect à
    /// l'échéance — c'est lui qui peut le blanchir — et applique donc sa
    /// propre liste (voir `refresh`).
    var unreachablePIDs: Set<pid_t> {
        closingPIDs.union(FreezeWatcher.shared.suspects)
    }

    /// Un client sur lequel un geste AX a un sens : ni dormant, ni injoignable.
    func isReachable(_ client: DofusClient) -> Bool {
        !client.dormant && !unreachablePIDs.contains(client.pid)
    }

    private var timer: Timer?
    private let prefs = Preferences.shared

    /// Fin du dernier inventaire, et inventaire différé en attente, avec son
    /// échéance. Cf. `refreshSoon(after:)`.
    private var lastRefresh = Date.distantPast
    private var pendingRefresh: DispatchWorkItem?
    private var pendingDeadline = Date.distantPast

    /// Délai minimal entre deux inventaires déclenchés par notification.
    private static let refreshInterval: TimeInterval = 0.2

    /// Délai minimal entre deux inventaires quand c'est le timer qui parle :
    /// une notification arrivée juste avant lui a déjà fait le travail.
    private static let timerMinimumGap: TimeInterval = 1.0

    /// Délai laissé à une bascule faite par Synfus avant l'inventaire qui la
    /// suit : le temps que la transition d'espace s'achève, plutôt que de
    /// questionner l'Accessibilité au beau milieu.
    private static let selfActivationSettle: TimeInterval = 1.0

    /// Le pid qu'une bascule de Synfus vient d'activer. La notification
    /// d'activation qui en découle n'est pas une nouvelle de l'extérieur : elle
    /// n'a pas besoin d'un inventaire dans les 200 ms.
    private var selfActivatedPID: pid_t?
    /// Tous les processus Dofus vivants, persos ou non : un client resté au
    /// login sur un autre bureau n'est pas dans `clients` mais a bien son icône
    /// dans le Dock, et c'est ce compte-là qui périme le cache de structure.
    private(set) var liveDofusPIDs: Set<pid_t> = []

    /// Dernière lecture de CGWindowList pour un pid sans mémoire. Un client
    /// resté au login sur un autre bureau n'a rien à livrer et le resterait à
    /// chaque tour : le tour de toutes les fenêtres du système ne se paie donc
    /// qu'une fois par `crossSpaceInterval` pour un même pid.
    private var crossSpaceChecked: [pid_t: Date] = [:]
    private static let crossSpaceInterval: TimeInterval = 10

    /// Derniers persos vus pour chaque processus. La clé est le pid : il vit
    /// aussi longtemps que le client, alors que la fenêtre, elle, va et vient
    /// au gré des espaces.
    private var rememberedClients: [pid_t: [DofusClient]] = [:]

    private init() {}

    func start() {
        accessibilityGranted = AXIsProcessTrusted()

        // Borne l'attente de tous les appels AX du processus : un client gelé
        // ne répond jamais, et sans cette borne chaque inventaire resterait
        // suspendu plusieurs secondes sur lui — barre comprise. Les clients
        // simplement occupés tiennent bien en deçà de la seconde.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)

        // Les versions du client et les homonymes suffixés ont pu s'enregistrer
        // avant que le filtre n'existe : ils encombreraient la liste indéfiniment.
        prefs.purgeOrder(keeping: WindowTitle.isPersistableName)

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
                    guard let self else { return }
                    if activated, let pid {
                        self.setFrontmost(pid: pid, bundleID: bundleID)
                    } else {
                        // Une désactivation ne dit pas qui prend la relève : là,
                        // `frontmostApplication` est à jour, ou le sera au prochain
                        // tour de timer.
                        self.setFrontmost(NSWorkspace.shared.frontmostApplication)
                    }
                    FloatingBarController.shared.updateVisibility()

                    // Une activation que Synfus a lui-même provoquée n'apprend
                    // rien : la barre est déjà à jour, et l'inventaire peut
                    // attendre la fin de la transition d'espace.
                    if activated, let pid, pid == self.selfActivatedPID {
                        self.selfActivatedPID = nil
                        self.refreshSoon(after: Self.selfActivationSettle)
                    } else {
                        self.refreshSoon()
                    }
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
        //
        // La visibilité est réévaluée à chaque tour ; l'inventaire, lui, est
        // sauté si une notification vient d'en faire un — deux inventaires
        // collés, c'est deux fois le gel pour rien.
        //
        // Sans `force` : le filet ne corrige qu'un état faux, il ne réordonne
        // pas un panneau déjà visible toutes les 2 s. Remonter la barre
        // au-dessus d'un espace fraîchement activé reste l'affaire des
        // notifications, qui gardent le comportement franc.
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                FloatingBarController.shared.updateVisibility(force: false)
                guard let self,
                      Date().timeIntervalSince(self.lastRefresh) >= Self.timerMinimumGap
                else { return }
                self.refresh()
            }
        }
        // Rien ici n'exige la seconde près : laisser le système regrouper ce
        // réveil avec d'autres épargne des réveils.
        timer?.tolerance = 0.3
        refresh()
    }

    /// Mémorise l'application de premier plan et si c'est un client Dofus.
    private func setFrontmost(_ app: NSRunningApplication?) {
        setFrontmost(pid: app?.processIdentifier, bundleID: app?.bundleIdentifier)
    }

    private func setFrontmost(pid: pid_t?, bundleID: String?) {
        setFrontmost(pid: pid, isDofus: DofusProcesses.isDofusBundle(bundleID))
    }

    /// Ne republie que ce qui change : ces deux valeurs sont relues à chaque
    /// tour de timer, et chaque affectation d'un `@Published` réveille toutes
    /// les vues qui l'observent, changement ou pas.
    private func setFrontmost(pid: pid_t?, isDofus: Bool) {
        if frontmostPID != pid { frontmostPID = pid }
        if frontmostIsDofus != isDofus { frontmostIsDofus = isDofus }
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
    ///
    /// `after` impose une attente minimale à partir de maintenant, en plus du
    /// délai entre inventaires. Si un inventaire différé est déjà programmé
    /// plus tôt, il est repoussé : une seule échéance, la plus tardive — c'est
    /// ce qui permet à une bascule faite par Synfus de laisser passer la
    /// transition d'espace avant d'interroger l'Accessibilité.
    func refreshSoon(after delay: TimeInterval = 0) {
        let elapsed = Date().timeIntervalSince(lastRefresh)
        let wait = max(delay, Self.refreshInterval - elapsed)
        guard wait > 0 else {
            refresh()
            return
        }

        let deadline = Date().addingTimeInterval(wait)
        if let pendingRefresh, !pendingRefresh.isCancelled {
            guard deadline > pendingDeadline else { return }
            pendingRefresh.cancel()
        }
        let item = DispatchWorkItem {
            MainActor.assumeIsolated {
                self.pendingRefresh = nil
                self.refresh()
            }
        }
        pendingRefresh = item
        pendingDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: item)
    }

    func refresh() {
        lastRefresh = Date()
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted { accessibilityGranted = granted }
        setFrontmost(NSWorkspace.shared.frontmostApplication)

        guard granted else {
            if !clients.isEmpty {
                clients = []
                PreviewPanelController.shared.reconcile(with: clients)
            }
            return
        }

        var found: [DofusClient] = []
        var usedNames: [String: Int] = [:]
        var livePIDs: Set<pid_t> = []
        var talkativePIDs: Set<pid_t> = []
        /// Clients qui ont laissé expirer la question `kAXWindows` : l'inventaire
        /// est la seule sonde du veilleur de gel, c'est ici que le mutisme se
        /// constate.
        var mutePIDs: Set<pid_t> = []
        let freezes = FreezeWatcher.shared

        for app in DofusProcesses.running() {
            let pid = app.processIdentifier
            livePIDs.insert(pid)
            // Un client en cours de fermeture n'est plus interrogé : sa mémoire
            // le maintient dans la barre, avec l'indicateur, jusqu'à sa mort.
            guard !closingPIDs.contains(pid) else { continue }
            let axApp = AXHandle.application(pid)

            // Un client déjà pris en défaut n'est réinterrogé qu'à l'échéance
            // de la sonde, mais avec la **même** borne d'une seconde que les
            // autres : une borne plus courte lui ôterait tout moyen de se
            // blanchir, et un client vivant mais lent — chargement, combat
            // chargé — finirait abattu. Entre deux échéances, il reste dans
            // `livePIDs` sans être bavard : la mémoire l'affiche atténué.
            if freezes.suspects.contains(pid), !freezes.shouldProbe(pid) { continue }

            let windows: [AXHandle]
            switch AccessibilityReader.windows(of: axApp) {
            case .windows(let list): windows = list
            case .mute: mutePIDs.insert(pid); continue
            case .failed: continue
            }

            // Un client qui rend au moins une fenêtre est joignable : s'il n'en
            // ressort aucun perso, c'est qu'il est retourné à l'écran de
            // connexion, et non qu'il se cache sur un autre bureau.
            if !windows.isEmpty { talkativePIDs.insert(pid) }

            for (index, window) in windows.enumerated() {
                // Un seul aller-retour par fenêtre pour les trois attributs :
                // chaque appel AX est un IPC, et l'inventaire passe toutes les 2 s.
                let facts = AccessibilityReader.windowFacts(window)
                guard AccessibilityReader.isGameWindow(subrole: facts.subrole, size: facts.size) else { continue }

                let rawTitle = facts.title ?? ""
                guard WindowTitle.isCharacterWindow(title: rawTitle) else { continue }

                var name = WindowTitle.characterName(fromTitle: rawTitle)

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
                    characterClass: WindowTitle.characterClass(fromTitle: rawTitle),
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
        if liveDofusPIDs != livePIDs { liveDofusPIDs = livePIDs }
        let stillClosing = closingPIDs.intersection(livePIDs)
        if stillClosing != closingPIDs { closingPIDs = stillClosing }
        let silentPIDs = livePIDs.subtracting(talkativePIDs)
        found = ClientMemory.withRemembered(
            found: found,
            remembered: rememberedClients,
            silentPIDs: silentPIDs
        )

        // Un client déjà sur un espace inactif au démarrage de Synfus n'a
        // jamais livré son titre à l'Accessibilité. Quand l'enregistrement de
        // l'écran est accordé (celui des aperçus), CGWindowList voit à travers
        // les espaces et lève cette limite ; la lecture n'a lieu que pour les
        // pids sans aucune mémoire, puis la mémoire prend le relais — le tour
        // de toutes les fenêtres du système n'est pas payé à chaque inventaire.
        // Un pid qui n'a rien livré — client au login sur un autre bureau — le
        // resterait à chaque tour : on ne le relit qu'à l'échéance.
        let now = Date()
        let unknownPIDs = silentPIDs.subtracting(Set(found.map(\.pid))).filter { pid in
            guard let checked = crossSpaceChecked[pid] else { return true }
            return now.timeIntervalSince(checked) >= Self.crossSpaceInterval
        }
        if !unknownPIDs.isEmpty {
            for pid in unknownPIDs { crossSpaceChecked[pid] = now }
            let discovered = ClientMemory.discoveredAcrossSpaces(
                titles: CrossSpaceTitles.read(pids: unknownPIDs),
                existingNames: Set(found.map(\.name)),
                appElement: AXHandle.application
            )
            found += discovered
            remember(discovered)
        }

        // Un processus vivant, sans fenêtre et muet à l'Accessibilité est un
        // client gelé à la fermeture : le veilleur l'achève, que la fermeture
        // soit passée par Synfus ou par le jeu lui-même. Il est nourri à
        // chaque tour, réglage ou non : les strikes épargnent à l'inventaire
        // la borne pleine, seul le coup de grâce dépend du réglage.
        let names = Dictionary(uniqueKeysWithValues: rememberedClients.compactMap {
            pid, list in list.first.map { (pid, $0.name) }
        })
        // Les fermetures en cours ont déjà leur escalade.
        freezes.inspect(silentPIDs: silentPIDs.subtracting(closingPIDs),
                        mutePIDs: mutePIDs,
                        names: names,
                        achever: prefs.killFrozenClients)

        // Seuls les vrais noms de persos entrent dans la liste ; les clients au
        // login et les homonymes suffixés restent dans la barre sans s'y inscrire.
        prefs.registerIfNeeded(names: found.map(\.name).filter(WindowTitle.isPersistableName))

        found = ClientMemory.sorted(found, by: prefs.characterOrder)

        if found != clients {
            clients = found
            // Les vignettes des persos déconnectés n'ont plus de sens, et leur
            // `slotKey` sera repris par un autre client au prochain lancement.
            WindowPreviewService.shared.prune(keeping: found)
            // Et l'aperçu ouvert sur l'un d'eux n'a plus rien à montrer.
            PreviewPanelController.shared.reconcile(with: found)
        }
    }

    /// Retrie les persos déjà connus selon l'ordre de préférence, sans
    /// inventaire. Réordonner dans la barre ou les réglages ne change rien à ce
    /// qui est connecté : refaire le tour de l'Accessibilité à chaque
    /// permutation, c'était payer un inventaire complet pour un tri.
    func resort() {
        let sorted = ClientMemory.sorted(clients, by: prefs.characterOrder)
        if sorted != clients { clients = sorted }
    }

    /// Retient les persos effectivement vus, par processus. Un pid dont on ne
    /// voit plus rien garde sa dernière mémoire ; il ne sera oublié qu'à la
    /// fermeture du client (voir `withRemembered`).
    private func remember(_ found: [DofusClient]) {
        for (pid, clients) in Dictionary(grouping: found, by: \.pid) {
            rememberedClients[pid] = clients
        }
    }

    /// Oublie les clients fermés — leur pid ne reviendra pas.
    private func forgetDeadProcesses(livePIDs: Set<pid_t>) {
        rememberedClients = rememberedClients.filter { livePIDs.contains($0.key) }
        crossSpaceChecked = crossSpaceChecked.filter { livePIDs.contains($0.key) }
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
        let reachable = isReachable(client)
        if reachable,
           AccessibilityReader.boolAttribute(client.axWindow, kAXMinimizedAttribute) == true {
            AccessibilityReader.set(client.axWindow, kAXMinimizedAttribute, kCFBooleanFalse)
        }

        // L'activation vient en premier : c'est elle, et non `AXRaise`, qui fait
        // basculer macOS vers l'espace où vit la fenêtre quand le client est en
        // plein écran. Dans l'ordre inverse, le raise s'appliquait à une fenêtre
        // d'un autre espace et ne menait nulle part.
        NSRunningApplication(processIdentifier: client.pid)?.activate()

        // Les attributs AX ne servent qu'à départager plusieurs fenêtres d'un même
        // processus ; on les pose une fois la transition d'espace engagée — et
        // seulement s'il y a quelque chose à départager : pour un client à
        // fenêtre unique, l'activation fait tout, et deux appels AX de plus
        // n'ajoutent que de la latence à la bascule. Sur un perso seulement
        // mémorisé, la référence de fenêtre est périmée — il n'y a rien à y poser.
        let siblings = clients.filter { $0.pid == client.pid && !$0.dormant }.count
        if reachable, siblings > 1 {
            let window = client.axWindow
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                MainActor.assumeIsolated {
                    AccessibilityReader.set(window, kAXMainAttribute, kCFBooleanTrue)
                    AccessibilityReader.perform(window, action: kAXRaiseAction)
                }
            }
        }

        // La notification d'activation qui va suivre est la nôtre : elle n'aura
        // pas à déclencher un inventaire à chaud. Si le client est déjà devant,
        // aucune ne viendra, et le drapeau resterait collé jusqu'à une
        // activation extérieure qu'il ferait passer pour la nôtre.
        selfActivatedPID = frontmostPID == client.pid ? nil : client.pid
        setFrontmost(pid: client.pid, isDofus: true)
        AttentionWatcher.shared.clear(client)
    }

    /// Ferme un client — l'escalade de `ClientTerminator`.
    ///
    /// Le client gèle systématiquement à la fermeture chez certains joueurs, et
    /// il faut alors passer par « Forcer à quitter » : on automatise ce geste.
    func close(_ client: DofusClient) {
        let pid = client.pid
        guard NSRunningApplication(processIdentifier: pid) != nil else { return }
        closingPIDs.insert(pid)
        // La pastille reste affichée le temps de la fermeture (cf. la mémoire),
        // mais son aperçu, lui, n'a plus lieu d'être : on le retire tout de
        // suite plutôt que d'attendre un `mouseExited` que le menu contextuel a
        // déjà consommé.
        PreviewPanelController.shared.reconcile(with: clients.filter { $0.pid != pid })

        ClientTerminator.close(pid) { WindowManager.shared.refreshSoon() }
        refreshSoon()
    }

    /// Ferme tous les clients, chacun avec la même escalade. Le geste de fin
    /// de session — sans lui, c'est autant de « Forcer à quitter » que de persos.
    func closeAll() {
        clients.forEach(close)
    }

    /// Le geste « lancer la session » : ranger les fenêtres selon la dernière
    /// disposition, basculer sur le premier perso, et armer l'enchaînement si
    /// le mode est disponible. Rien que des gestes existants, enchaînés — et
    /// toujours aucun évènement émis.
    func lancerSession() {
        WindowArranger.shared.appliquerDerniere()
        if !clients.isEmpty { focus(slot: 0) }
        if prefs.advanceOnClick, !ClickAdvanceWatcher.shared.armed {
            ClickAdvanceWatcher.shared.toggleArmed()
        }
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
