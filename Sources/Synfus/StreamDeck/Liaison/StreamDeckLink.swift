import AppKit
import Combine
import Network

/// La liaison Synfus ↔ plugin Stream Deck : un socket Unix dans le dossier
/// de l'utilisateur, en `0600` — joignable par ses seuls processus, jamais
/// par le réseau ni un autre compte. Il n'existe que si le réglage est actif.
///
/// Synfus y pousse `DeckState` à chaque changement de perso, de profil ou de
/// barre ; le plugin y écrit des `DeckCommand`, toutes connues de la barre
/// flottante. Une commande inconnue est ignorée et journalisée.
@MainActor
final class StreamDeckLink: ObservableObject {
    static let shared = StreamDeckLink()

    static let socketURL: URL = AnkamaAssets.supportDirectory.appending(path: "streamdeck.sock")

    @Published private(set) var status = "inactive"
    /// La page affichée — barre active ou fenêtre selon le mode —, le menu et
    /// sa page : des états de session, comme le perso au premier plan, pas des
    /// préférences.
    @Published private(set) var page = 0
    @Published private(set) var menuOuvert = false
    @Published private(set) var pageMenu = 0
    /// Verdict de la détection de combat, posé par `CombatWatcher`.
    @Published var enCombat: Bool?
    /// Les grilles annoncées par les plugins connectés ; celle de l'utilisateur
    /// à défaut, pour le miroir des réglages.
    @Published private(set) var grilles: Set<Grille> = [.defaut]

    struct Grille: Hashable, Sendable {
        let colonnes: Int
        let lignes: Int
        static let defaut = Grille(colonnes: DeckLayout.defaultColumns, lignes: DeckLayout.defaultRows)
    }

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var buffers: [ObjectIdentifier: Data] = [:]
    /// Ce qui a été envoyé, par grille — rien n'est renvoyé à l'identique.
    private var lastPayloads: [Grille: Data] = [:]
    private var iconCache: [Int: String] = [:]
    private var subscriptions: Set<AnyCancellable> = []

    private init() {}

    func start() {
        let prefs = Preferences.shared
        prefs.$streamDeckEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in enabled ? self?.open() : self?.close() }
            .store(in: &subscriptions)

        // Tout ce qui change l'état publié. Un seul chemin de publication, qui
        // n'envoie que si le JSON diffère du précédent.
        let manager = WindowManager.shared
        let triggers: [AnyPublisher<Void, Never>] = [
            manager.$clients.map { _ in () }.eraseToAnyPublisher(),
            manager.$frontmostPID.map { _ in () }.eraseToAnyPublisher(),
            manager.$frontmostIsDofus.map { _ in () }.eraseToAnyPublisher(),
            SpellProfileStore.shared.$profiles.map { _ in () }.eraseToAnyPublisher(),
            prefs.$spellKeyMap.map { _ in () }.eraseToAnyPublisher(),
            prefs.$gameCommands.map { _ in () }.eraseToAnyPublisher(),
            prefs.$deck.map { _ in () }.eraseToAnyPublisher(),
            prefs.$appuiLongMs.map { _ in () }.eraseToAnyPublisher(),
            prefs.$appuiTresLongMs.map { _ in () }.eraseToAnyPublisher(),
            prefs.$appuiProgressif.map { _ in () }.eraseToAnyPublisher(),
            prefs.$deckTitres.map { _ in () }.eraseToAnyPublisher(),
            $page.map { _ in () }.eraseToAnyPublisher(),
            $menuOuvert.map { _ in () }.eraseToAnyPublisher(),
            $pageMenu.map { _ in () }.eraseToAnyPublisher(),
            $enCombat.map { _ in () }.eraseToAnyPublisher(),
            $grilles.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(triggers)
        .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
        .sink { [weak self] in self?.publish() }
        .store(in: &subscriptions)
    }

    /// À la fermeture : le fichier socket ne doit pas survivre au processus.
    func stop() { close() }

    // MARK: - Socket

    private func open() {
        guard listener == nil else { return }
        let path = Self.socketURL.path
        try? FileManager.default.createDirectory(at: Self.socketURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? FileManager.default.removeItem(atPath: path)

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: path)
        guard let listener = try? NWListener(using: parameters) else {
            status = "socket impossible à ouvrir"
            return
        }
        listener.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .ready:
                    // Le fichier existe maintenant : on le ferme aux autres comptes.
                    chmod(path, 0o600)
                    self.status = "en écoute — 0 plugin connecté"
                case .failed(let error): self.status = "échec : \(error)"
                case .cancelled: self.status = "inactive"
                default: break
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    private func close() {
        for connection in connections.values { connection.cancel() }
        connections.removeAll()
        buffers.removeAll()
        listener?.cancel()
        listener = nil
        lastPayloads.removeAll()
        try? FileManager.default.removeItem(at: Self.socketURL)
        status = "inactive"
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        buffers[id] = Data()
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .ready:
                    self.updateStatus()
                    // Un nouveau venu reçoit les pages tout de suite.
                    for grille in self.grilles { if let payload = self.encodedPage(grille) { self.send(payload, to: connection) } }
                case .failed, .cancelled:
                    self.connections[id] = nil
                    self.buffers[id] = nil
                    self.updateStatus()
                default: break
                }
            }
        }
        connection.start(queue: .main)
        receive(on: connection)
    }

    private func updateStatus() {
        status = "en écoute — \(connections.count) plugin\(connections.count > 1 ? "s" : "") connecté\(connections.count > 1 ? "s" : "")"
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                let id = ObjectIdentifier(connection)
                if let data { self.consume(data, from: id) }
                if isComplete || error != nil {
                    connection.cancel()
                    return
                }
                self.receive(on: connection)
            }
        }
    }

    /// Découpe le flux en lignes ; chaque ligne est une commande.
    private func consume(_ data: Data, from id: ObjectIdentifier) {
        var buffer = buffers[id, default: Data()]
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer = buffer[buffer.index(after: newline)...]
            handle(Data(line))
        }
        // Une ligne sans fin qui enfle est un client qui ne parle pas notre langue.
        buffers[id] = buffer.count > 65_536 ? Data() : Data(buffer)
    }

    private func handle(_ line: Data) {
        guard let command = try? JSONDecoder().decode(DeckCommand.self, from: line) else {
            NSLog("Synfus: commande Stream Deck ignorée — %@", String(decoding: line.prefix(200), as: UTF8.self))
            return
        }
        execute(command)
    }

    /// Ce que le plugin demande — et ce que le miroir des réglages demande
    /// aussi, par les mêmes commandes : un seul chemin.
    func execute(_ command: DeckCommand) {
        let manager = WindowManager.shared
        let grille = grilles.first ?? .defaut
        let pageCount = mode.pageCount(colonnes: grille.colonnes, lignes: grille.lignes)
        switch command.type {
        case .persoSuivant: manager.cycle(by: 1)
        case .persoPrecedent: manager.cycle(by: -1)
        case .perso: if let slot = command.slot { manager.focus(slot: slot) }
        case .barreSuivante: page = (page + 1) % pageCount
        case .barrePrecedente: page = (page + pageCount - 1) % pageCount
        case .barrePremiere: page = 0
        case .menu: menuOuvert.toggle(); pageMenu = 0
        case .pageMenuSuivante: pageMenu += 1
        case .reconnaitre:
            guard let client = manager.clients.first(where: { manager.isFrontmost($0) }) else { return }
            Task { status = await SpellProfileStore.shared.recognize(client) }
        case .activer:
            if let current = manager.clients.first(where: { manager.isFrontmost($0) }) ?? manager.clients.first {
                manager.focus(current)
            }
        case .appareil:
            if let colonnes = command.colonnes, let lignes = command.lignes, colonnes > 0, lignes > 0 {
                grilles.insert(Grille(colonnes: colonnes, lignes: lignes))
            }
        }
    }

    // MARK: - Pages

    /// Le mode d'affichage en vigueur : celui du profil du perso devant s'il
    /// en a un, le générique sinon.
    var mode: DeckSettings {
        let manager = WindowManager.shared
        let client = manager.clients.first { manager.isFrontmost($0) }
        return client.flatMap { SpellProfileStore.shared.profiles[$0.name]?.deck } ?? Preferences.shared.deck
    }

    /// Une page par grille, envoyée seulement si elle diffère de la précédente.
    private func publish() {
        guard listener != nil else { return }
        for grille in grilles {
            guard let payload = encodedPage(grille), payload != lastPayloads[grille] else { continue }
            lastPayloads[grille] = payload
            for connection in connections.values { send(payload, to: connection) }
        }
    }

    private func send(_ payload: Data, to connection: NWConnection) {
        connection.send(content: payload + Data([0x0A]), completion: .contentProcessed { _ in })
    }

    private func encodedPage(_ grille: Grille) -> Data? {
        try? JSONEncoder().encode(currentPage(grille))
    }

    /// La page pour une grille, composée de l'état courant — le miroir des
    /// réglages l'appelle aussi : même code, même image que l'appareil.
    func currentPage(_ grille: Grille) -> DeckPage {
        let manager = WindowManager.shared
        let clients = manager.clients
        let index = clients.firstIndex { manager.isFrontmost($0) }
        let client = index.map { clients[$0] }
        // Plus aucun client ? On garde le dernier perso vu, atténué : mieux
        // vaut ses sorts qu'un deck vide.
        if let client { lastPerso = (client.name, client.characterClass) }
        let shown = client.map { ($0.name, $0.characterClass) } ?? (clients.isEmpty ? lastPerso : nil)
        var input = makeInput(grille: grille, mode: mode, perso: shown?.0, classe: shown?.1)
        // Les voisins dans l'ordre de la barre, en boucle — ce que « suivant »
        // et « précédent » feront.
        input.suivant = index.flatMap { clients.count > 1 ? deckPerso(clients[($0 + 1) % clients.count]) : nil }
        input.precedent = index.flatMap { clients.count > 1 ? deckPerso(clients[($0 + clients.count - 1) % clients.count]) : nil }
        input.dofusDevant = manager.frontmostIsDofus
        return DeckComposer.compose(input) { [weak self] slot in self?.icon(of: slot, perso: shown?.0) }
    }

    /// Le dernier perso au premier plan — affiché quand il n'y a plus personne.
    private var lastPerso: (String, String?)?

    /// La page telle que l'éditeur la montre : un perso et un mode choisis,
    /// Dofus supposé devant — pour voir ce qu'on règle, pas ce qui est affiché.
    func previewPage(grille: Grille, mode: DeckSettings, perso: String?, classe: String?) -> DeckPage {
        var input = makeInput(grille: grille, mode: mode, perso: perso, classe: classe)
        input.dofusDevant = true
        return DeckComposer.compose(input) { [weak self] slot in self?.icon(of: slot, perso: perso) }
    }

    private func deckPerso(_ client: DofusClient) -> DeckPerso {
        DeckPerso(nom: client.name, classe: client.characterClass, icone: classIcon(client.characterClass))
    }

    private func makeInput(grille: Grille, mode: DeckSettings, perso: String?, classe: String?) -> DeckComposer.Input {
        let prefs = Preferences.shared
        var input = DeckComposer.Input(colonnes: grille.colonnes, lignes: grille.lignes, mode: mode)
        input.page = page
        input.menuOuvert = menuOuvert
        input.pageMenu = pageMenu
        if let perso {
            let profile = SpellProfileStore.shared.profile(for: perso, classe: classe)
            input.perso = DeckPerso(nom: perso, classe: classe ?? profile.classe, icone: classIcon(classe ?? profile.classe))
            input.profile = profile
        }
        input.keyMap = prefs.spellKeyMap
        input.commandes = prefs.gameCommands
        input.enCombat = enCombat
        input.appuiLongMs = prefs.appuiLongMs
        input.appuiTresLongMs = prefs.appuiTresLongMs
        input.progressif = prefs.appuiProgressif
        input.titresSorts = prefs.deckTitres
        return input
    }

    /// L'icône d'une case : celle du sort connu, sinon la vignette lue à
    /// l'écran, rangée avec le profil.
    private func icon(of slot: SpellSlot, perso: String?) -> String? {
        if let id = slot.sortId, let cached = iconCache[id] { return cached }
        let url: URL?
        if let id = slot.sortId, let known = SpellIndex.shared?.iconURL(id: id) {
            url = known
        } else if let vignette = slot.vignette, let perso {
            url = SpellProfileStore.shared.thumbnailURL(perso: perso, name: vignette)
        } else {
            url = nil
        }
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let encoded = data.base64EncodedString()
        if let id = slot.sortId { iconCache[id] = encoded }
        return encoded
    }

    private var classIconCache: [String: String] = [:]

    private func classIcon(_ classe: String?) -> String? {
        guard let key = DofusClass.key(for: classe) else { return nil }
        if let cached = classIconCache[key] { return cached }
        guard let url = AnkamaAssets.classIconURL(key: key), let data = try? Data(contentsOf: url) else { return nil }
        let encoded = data.base64EncodedString()
        classIconCache[key] = encoded
        return encoded
    }

}
