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
    /// Barre affichée sur le Stream Deck, 0-based. Vit ici, pas dans les
    /// préférences : c'est un état de session, comme le perso au premier plan.
    @Published private(set) var barreActive = 0
    /// Verdict de la détection de combat, posé par `CombatWatcher`.
    @Published var enCombat: Bool?

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var buffers: [ObjectIdentifier: Data] = [:]
    private var lastPayload: Data?
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
        Publishers.Merge4(
            manager.$clients.map { _ in () },
            manager.$frontmostPID.map { _ in () },
            manager.$frontmostIsDofus.map { _ in () },
            SpellProfileStore.shared.$profiles.map { _ in () }
        )
        .merge(with: prefs.$spellKeyMap.map { _ in () }, $barreActive.map { _ in () }, $enCombat.map { _ in () })
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
        lastPayload = nil
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
                    // Un nouveau venu reçoit l'état tout de suite.
                    if let payload = self.lastPayload ?? self.encodedState() { self.send(payload, to: connection) }
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
        let manager = WindowManager.shared
        switch command.type {
        case .persoSuivant: manager.cycle(by: 1)
        case .persoPrecedent: manager.cycle(by: -1)
        case .perso: if let slot = command.slot { manager.focus(slot: slot) }
        case .barreSuivante: barreActive = (barreActive + 1) % SpellProfile.barCount
        case .barrePrecedente: barreActive = (barreActive + SpellProfile.barCount - 1) % SpellProfile.barCount
        }
    }

    // MARK: - État

    /// L'état courant, encodé — `nil` si rien ne le distingue du précédent.
    private func publish() {
        guard listener != nil, let payload = encodedState(), payload != lastPayload else { return }
        lastPayload = payload
        for connection in connections.values { send(payload, to: connection) }
    }

    private func send(_ payload: Data, to connection: NWConnection) {
        connection.send(content: payload + Data([0x0A]), completion: .contentProcessed { _ in })
    }

    private func encodedState() -> Data? {
        try? JSONEncoder().encode(currentState())
    }

    /// Le perso au premier plan, ses sorts sur la barre active, les touches.
    /// Pure quant à ses entrées : `state(for:)` est ce que l'on teste.
    func currentState() -> DeckState {
        let manager = WindowManager.shared
        let client = manager.clients.first { manager.isFrontmost($0) }
        let profile = client.map { SpellProfileStore.shared.profile(for: $0.name, classe: $0.characterClass) }
        return Self.state(client: client, profile: profile, dofusDevant: manager.frontmostIsDofus,
                          barre: barreActive, keyMap: Preferences.shared.spellKeyMap, enCombat: enCombat,
                          icon: { [weak self] id in self?.icon(id) })
    }

    static func state(client: DofusClient?, profile: SpellProfile?, dofusDevant: Bool, barre: Int,
                      keyMap: SpellKeyMap, enCombat: Bool?, icon: (Int) -> String?) -> DeckState {
        let bar = profile.flatMap { $0.barres.indices.contains(barre) ? $0.barres[barre] : nil }
        let cases = (0..<SpellProfile.slotsPerBar).map { position -> DeckCell in
            let slot = bar?.cases[position]
            return DeckCell(position: position + 1,
                            sortId: slot?.sortId,
                            nom: slot?.nom,
                            icone: slot.flatMap { icon($0.sortId) },
                            touche: keyMap.key(bar: barre, position: position).map(DeckKey.init))
        }
        return DeckState(dofusDevant: dofusDevant, perso: client?.name, classe: client?.characterClass,
                         barre: barre + 1, barres: SpellProfile.barCount, enCombat: enCombat,
                         finDeTour: keyMap.finDeTour.map(DeckKey.init), cases: cases)
    }

    private func icon(_ id: Int) -> String? {
        if let cached = iconCache[id] { return cached }
        guard let url = SpellIndex.shared?.iconURL(id: id),
              let data = try? Data(contentsOf: url)
        else { return nil }
        let encoded = data.base64EncodedString()
        iconCache[id] = encoded
        return encoded
    }
}
