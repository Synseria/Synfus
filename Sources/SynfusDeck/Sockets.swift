import Foundation
import Network

/// Le WebSocket vers le logiciel Stream Deck — client, sur le port qu'il nous
/// donne au lancement.
@MainActor
final class ElgatoSocket {
    private let task: URLSessionWebSocketTask
    private let onEvent: @MainActor (StreamDeckEvent) -> Void
    private var uuid = ""

    init(port: Int, onEvent: @escaping @MainActor (StreamDeckEvent) -> Void) {
        task = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)
        self.onEvent = onEvent
    }

    func connect(registerEvent: String, uuid: String) async {
        self.uuid = uuid
        task.resume()
        send(["event": registerEvent, "uuid": uuid])
        Task { await listen() }
    }

    private func listen() async {
        while true {
            guard let message = try? await task.receive() else { return }
            guard case .string(let text) = message,
                  let event = try? JSONDecoder().decode(StreamDeckEvent.self, from: Data(text.utf8))
            else { continue }
            onEvent(event)
        }
    }

    func setImage(_ context: String, base64PNG: String?) {
        send(["event": "setImage", "context": context,
              "payload": ["image": base64PNG.map { "data:image/png;base64," + $0 } ?? "", "target": 0]])
    }

    func setTitle(_ context: String, _ title: String) {
        send(["event": "setTitle", "context": context, "payload": ["title": title, "target": 0]])
    }

    func setState(_ context: String, _ state: Int) {
        send(["event": "setState", "context": context, "payload": ["state": state]])
    }

    func showAlert(_ context: String) {
        send(["event": "showAlert", "context": context])
    }

    /// Bascule vers un profil livré avec le plugin ; `nil` rend le profil
    /// précédent.
    func switchToProfile(device: String, profile: String?) {
        var payload: [String: Any] = [:]
        if let profile { payload["profile"] = profile }
        send(["event": "switchToProfile", "context": uuid, "device": device, "payload": payload])
    }

    private func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8)
        else { return }
        task.send(.string(text)) { _ in }
    }
}

/// Le socket Unix de Synfus. Reconnexion à délai croissant tant que Synfus
/// n'est pas là — le plugin peut être lancé avant lui.
@MainActor
final class SynfusSocket {
    private let path: String
    private let onState: @MainActor (DeckState) -> Void
    private let onDisconnect: @MainActor () -> Void
    private var connection: NWConnection?
    private var buffer = Data()
    private var retryDelay: TimeInterval = 1
    private(set) var isConnected = false

    init(path: String, onState: @escaping @MainActor (DeckState) -> Void,
         onDisconnect: @escaping @MainActor () -> Void) {
        self.path = path
        self.onState = onState
        self.onDisconnect = onDisconnect
    }

    func connect() {
        let connection = NWConnection(to: .unix(path: path), using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .ready:
                    self.isConnected = true
                    self.retryDelay = 1
                    self.receive(on: connection)
                case .failed, .cancelled:
                    self.dropped()
                case .waiting:
                    // Le socket n'existe pas encore : Synfus n'est pas lancé, ou
                    // la liaison n'est pas activée. On réessaie.
                    connection.cancel()
                default: break
                }
            }
        }
        connection.start(queue: .main)
    }

    private func dropped() {
        guard connection != nil else { return }
        connection = nil
        let wasConnected = isConnected
        isConnected = false
        buffer.removeAll()
        if wasConnected { onDisconnect() }
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 15)
        Task {
            try? await Task.sleep(for: .seconds(delay))
            self.connect()
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let data { self.consume(data) }
                if isComplete || error != nil { connection.cancel(); return }
                self.receive(on: connection)
            }
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[buffer.startIndex..<newline])
            buffer = Data(buffer[buffer.index(after: newline)...])
            if let state = try? JSONDecoder().decode(DeckState.self, from: line), state.type == "etat" {
                onState(state)
            }
        }
    }

    func send(_ command: DeckCommand) {
        guard let connection, isConnected, let data = try? JSONEncoder().encode(command) else { return }
        connection.send(content: data + Data([0x0A]), completion: .contentProcessed { _ in })
    }
}
