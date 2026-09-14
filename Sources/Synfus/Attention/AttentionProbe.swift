import AppKit
import ApplicationServices

/// Sonde d'« appel d'attention ».
///
/// Quand Dofus veut être remarqué, son icône du Dock tressaute. Ce rebond n'est
/// exposé par aucune API publique : rien ne permet à une app de savoir qu'une
/// *autre* app réclame l'attention. La seule voie praticable est donc empirique
/// — relever tout ce que le Dock expose via l'API Accessibilité, et repérer ce
/// qui change au moment précis du rebond.
///
/// La sonde ne lit que des métadonnées de fenêtres et d'icônes. Elle n'inspecte
/// ni la mémoire du jeu, ni ce qu'il affiche à l'écran.
@MainActor
final class AttentionProbe: ObservableObject {
    static let shared = AttentionProbe()

    struct Sample: Identifiable {
        let id = UUID()
        let time: Date
        let label: String
        let detail: String
    }

    @Published private(set) var events: [Sample] = []
    @Published private(set) var running = false
    @Published private(set) var watchedItems: [String] = []

    private var timer: Timer?
    private var lastAttributes: [String: [String: String]] = [:]
    private var lastTitles: [String: String] = [:]
    private var handle: FileHandle?

    static let logURL: URL = {
        let directory = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Synfus", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("attention.log")
    }()

    private init() {}

    func toggle() { running ? stop() : start() }

    func start() {
        guard !running else { return }
        running = true
        events.removeAll()
        lastAttributes.removeAll()
        lastTitles.removeAll()
        openLog()

        let snapshots = DockInspector.snapshots(matching: "dofus")
        watchedItems = snapshots.map(\.title)

        write("=== Relevé Synfus démarré le \(Date().formatted()) ===")
        write("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        if snapshots.isEmpty {
            write("AUCUN élément « dofus » dans le Dock — le jeu est-il lancé ?")
            note("Aucune icône Dofus dans le Dock", "Lance le jeu puis redémarre la sonde.")
        }
        for snapshot in snapshots {
            write("--- état initial : \(snapshot.title) ---")
            for (key, value) in snapshot.attributes.sorted(by: { $0.key < $1.key }) {
                write("    \(key) = \(value)")
            }
            lastAttributes[snapshot.title] = snapshot.attributes
        }
        for client in WindowManager.shared.clients {
            write("--- fenêtre : \(client.name) | titre brut = \"\(client.rawTitle)\"")
            lastTitles[client.slotKey] = client.rawTitle
        }
        write("=== en écoute — joue un combat et attends ton tour ===")
        note("Sonde démarrée", "\(snapshots.count) icône(s) Dofus surveillée(s).")

        // 4 relevés par seconde : un rebond du Dock dure environ une seconde,
        // impossible de le manquer à cette cadence.
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        running = false
        write("=== relevé arrêté le \(Date().formatted()) ===\n")
        handle?.closeFile()
        handle = nil
        note("Sonde arrêtée", "\(events.count) évènement(s). Journal enregistré.")
    }

    private func sample() {
        for snapshot in DockInspector.snapshots(matching: "dofus") {
            guard let previous = lastAttributes[snapshot.title] else {
                lastAttributes[snapshot.title] = snapshot.attributes
                continue
            }
            for (key, value) in snapshot.attributes.sorted(by: { $0.key < $1.key })
            where previous[key] != value {
                record("Dock · \(snapshot.title) · \(key)",
                       "\(previous[key] ?? "∅")  →  \(value)")
            }
            for key in previous.keys where snapshot.attributes[key] == nil {
                record("Dock · \(snapshot.title) · \(key)", "attribut disparu")
            }
            lastAttributes[snapshot.title] = snapshot.attributes
        }

        for client in WindowManager.shared.clients {
            let previous = lastTitles[client.slotKey]
            if let previous, previous != client.rawTitle {
                record("Titre · \(client.name)", "\"\(previous)\"  →  \"\(client.rawTitle)\"")
            }
            lastTitles[client.slotKey] = client.rawTitle
        }
    }

    private func record(_ label: String, _ detail: String) {
        note(label, detail)
        write("[\(Date().formatted(date: .omitted, time: .standard))] \(label) : \(detail)")
    }

    private func note(_ label: String, _ detail: String) {
        events.insert(Sample(time: Date(), label: label, detail: detail), at: 0)
        if events.count > 80 { events.removeLast() }
    }

    // MARK: - Journal

    private func openLog() {
        let path = Self.logURL.path
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        handle = FileHandle(forWritingAtPath: path)
        handle?.seekToEndOfFile()
    }

    private func write(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        handle?.write(data)
    }

    func revealLog() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.logURL])
    }
}
