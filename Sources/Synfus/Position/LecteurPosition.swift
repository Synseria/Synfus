import AppKit
import Combine
import ImageIO
import Vision

/// Lit en continu la position du perso au premier plan : les coordonnées de
/// sa carte, affichées par le jeu en haut à gauche de la fenêtre.
///
/// Le coût est tenu par trois choix, mesurés sur de vraies captures :
///
/// - **Une petite zone** (`PositionCarte.region`, ~ 35 % × 16 % de la fenêtre),
///   capturée à **un pixel par point** — pas en Retina : l'OCR lit mieux le
///   texte du jeu à cette échelle (« -16 » là où la pleine résolution lisait
///   « →16 ») et deux fois plus vite, ~ 30 ms.
/// - **L'OCR n'est refait que si le texte a changé** (`EmpreinteTexte`) : la
///   position ne bouge qu'au changement de carte. Entre deux, un relevé coûte
///   une capture de quelques centaines de pixels et une comparaison.
/// - **L'inventaire ScreenCaptureKit gardé** (`inventaireGarde`) : relire
///   toutes les fenêtres du système chaque seconde coûterait plus que le reste.
///
/// Rien ne tourne tant que le réglage est éteint ou que l'enregistrement de
/// l'écran n'est pas accordé. Seul le perso au premier plan est lu en
/// continu ; les autres le sont au survol de leur pastille (relevé de plus de
/// 10 s) et par « Tout lire » dans le Diagnostic — les réglages ouverts,
/// Synfus est devant, et le tour régulier n'a plus rien à lire : c'est ce qui
/// faisait croire la lecture en panne. La reconnaissance est celle de Vision
/// en mode `accurate` : le mode `fast` ne lit rien de la police du jeu.
@MainActor
final class LecteurPosition: ObservableObject {
    static let shared = LecteurPosition()

    struct Releve: Equatable {
        var position: PositionCarte?
        /// Les lignes brutes du dernier OCR — pour le Diagnostic.
        var lignes: [String]
        var date: Date
    }

    /// Dernier relevé de chaque perso, par nom. Ne change qu'au changement de
    /// carte : la barre et l'aperçu peuvent l'observer sans se redessiner à
    /// chaque seconde — les compteurs, eux, vivent dans `DiagnosticPosition`.
    @Published private(set) var releves: [String: Releve] = [:]

    private let moteur = MoteurOCR()
    private let diagnostic = DiagnosticPosition.shared
    private var empreintes: [String: EmpreinteTexte] = [:]
    /// Dernière capture de chaque perso, lue ou sautée — la fraîcheur du
    /// relevé, hors `releves` pour ne rien republier à chaque seconde.
    private var vuLe: [String: Date] = [:]
    private var timer: Timer?
    /// Persos à lire, dans l'ordre des demandes — le tour, un survol, le
    /// bouton du Diagnostic. Une lecture à la fois : l'OCR est séquentiel.
    private var file: [DofusClient] = []
    private var busy = false
    private var subscriptions: Set<AnyCancellable> = []

    private static let intervalle: TimeInterval = 1
    /// Au survol, un relevé plus récent que cela suffit.
    private static let fraicheurSurvol: TimeInterval = 10

    private init() {}

    var actif: Bool { timer != nil }

    func start() {
        Preferences.shared.$lirePosition
            .removeDuplicates()
            .sink { [weak self] actif in
                MainActor.assumeIsolated { actif ? self?.armer() : self?.desarmer() }
            }
            .store(in: &subscriptions)
        // Une bascule : on lit le nouveau perso sans attendre le tour suivant,
        // une fois la transition d'espace passée.
        WindowManager.shared.$frontmostPID
            .removeDuplicates()
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard self?.timer != nil else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        MainActor.assumeIsolated { LecteurPosition.shared.tour() }
                    }
                }
            }
            .store(in: &subscriptions)
    }

    private func armer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.intervalle, repeats: true) { _ in
            MainActor.assumeIsolated { LecteurPosition.shared.tour() }
        }
        timer?.tolerance = 0.3
        // Le premier OCR `accurate` charge le modèle de Vision — mesuré jusqu'à
        // vingt-cinq secondes sur une machine froide. On le paie ici, une
        // fois, plutôt qu'au premier relevé, qui semblait ne jamais venir.
        diagnostic.etat = .preparation
        busy = true
        Task {
            await moteur.prechauffer()
            busy = false
            diagnostic.etat = .attente
            pomper()
        }
    }

    private func desarmer() {
        timer?.invalidate()
        timer = nil
        file = []
        diagnostic.etat = .eteint
    }

    /// Le tour régulier : le perso au premier plan, s'il y en a un.
    private func tour() {
        guard timer != nil else { return }
        let manager = WindowManager.shared
        guard WindowPreviewService.shared.authorized else { diagnostic.etat = .nonAutorise; return }
        guard manager.frontmostIsDofus,
              let client = manager.clients.first(where: { manager.isFrontmost($0) })
        else {
            if !busy, file.isEmpty { diagnostic.etat = .attente }
            return
        }
        demander([client])
    }

    /// Au survol d'une pastille : lit ce perso-là s'il n'a pas de relevé
    /// récent. Le perso devant est lu chaque seconde, les autres ne bougent
    /// pas tant qu'on ne les joue pas — un relevé de moins de dix secondes
    /// est donc le bon.
    func lireAuSurvol(_ client: DofusClient) {
        guard timer != nil else { return }
        if let vu = vuLe[client.name], Date().timeIntervalSince(vu) < Self.fraicheurSurvol { return }
        demander([client])
    }

    /// Le bouton du Diagnostic : tous les persos, une fois. C'est ce qui
    /// permet de vérifier la lecture depuis les réglages — Synfus est alors
    /// devant, le tour régulier n'a plus de perso à lire.
    func toutLire() {
        guard timer != nil else { return }
        demander(WindowManager.shared.clients)
    }

    private func demander(_ clients: [DofusClient]) {
        let injoignables = WindowManager.shared.unreachablePIDs
        for client in clients where WindowTitle.isPersistableName(client.name)
            && !injoignables.contains(client.pid)
            && !file.contains(where: { $0.slotKey == client.slotKey }) {
            file.append(client)
        }
        pomper()
    }

    private func pomper() {
        guard !busy, timer != nil, !file.isEmpty else { return }
        let client = file.removeFirst()
        let previews = WindowPreviewService.shared
        guard previews.authorized else { file = []; diagnostic.etat = .nonAutorise; return }

        busy = true
        let nom = client.name
        let precedente = empreintes[nom]
        Task {
            defer {
                busy = false
                pomper()
            }
            // Largeur plafonnée bien au-delà de la zone : l'échelle retombe à
            // un pixel par point, celle où l'OCR lit le mieux.
            guard let png = await previews.captureData(client, region: PositionCarte.region,
                                                      maxWidth: 4096, inventaireGarde: true)
            else {
                diagnostic.etat = .echecCapture(previews.lastCaptureError ?? "?")
                return
            }
            diagnostic.derniereCapture = NSImage(data: png)
            diagnostic.dernierPerso = nom
            switch await moteur.lire(png: png, precedente: precedente) {
            case .illisible:
                diagnostic.etat = .echecCapture("PNG illisible")
            case .inchangee:
                // Rien de neuf, mais le relevé reste vrai à cet instant.
                vuLe[nom] = Date()
                diagnostic.sautes += 1
                diagnostic.etat = releves[nom]?.position == nil ? .sansCoordonnees : .actif
            case .lue(let empreinte, let lignes, let duree):
                empreintes[nom] = empreinte
                vuLe[nom] = Date()
                diagnostic.lectures += 1
                diagnostic.derniereDuree = duree
                let lue = PositionCarte.lire(lignes)
                diagnostic.etat = lue == nil ? .sansCoordonnees : .actif
                // Une lecture sans coordonnées — écran de chargement, fenêtre
                // du jeu posée sur le coin — garde la dernière position connue.
                let releve = Releve(position: lue ?? releves[nom]?.position, lignes: lignes, date: Date())
                releves[nom] = releve
            }
        }
    }
}

/// Ce que la lecture fait et coûte, pour le seul Diagnostic. Séparé de
/// `LecteurPosition` pour que la barre, qui observe les relevés, ne se
/// redessine pas à chaque compteur — même partage que `AttentionDiagnostics`.
@MainActor
final class DiagnosticPosition: ObservableObject {
    static let shared = DiagnosticPosition()

    enum Etat: Equatable {
        case eteint
        case nonAutorise
        case preparation
        /// Aucun client Dofus au premier plan : rien à lire.
        case attente
        case actif
        case sansCoordonnees
        case echecCapture(String)
    }

    @Published var etat: Etat = .eteint
    @Published var lectures = 0
    @Published var sautes = 0
    @Published var derniereDuree: TimeInterval = 0
    /// La zone telle que l'OCR l'a vue — c'est la première chose à regarder
    /// quand rien n'est lu : la zone est-elle bien le coin du jeu ?
    @Published var derniereCapture: NSImage?
    @Published var dernierPerso: String?

    private init() {}
}

/// L'OCR, hors du main actor. Sans état : il reçoit un PNG et l'empreinte
/// précédente, rend l'empreinte et — seulement si elle a changé — les lignes
/// lues. Il n'en entre et n'en sort que des valeurs `Sendable`.
actor MoteurOCR {
    enum Resultat: Sendable {
        case illisible
        case inchangee
        case lue(EmpreinteTexte, [String], TimeInterval)
    }

    /// Charge le modèle de reconnaissance sur une image vide : le premier
    /// passage `accurate` est le seul lent.
    func prechauffer() {
        guard let contexte = CGContext(data: nil, width: 64, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
                                       space: CGColorSpaceCreateDeviceGray(),
                                       bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let image = contexte.makeImage()
        else { return }
        try? VNImageRequestHandler(cgImage: image).perform([Self.requete()])
    }

    private static func requete() -> VNRecognizeTextRequest {
        let requete = VNRecognizeTextRequest()
        requete.recognitionLevel = .accurate
        // Des noms propres et des nombres : la correction linguistique ne
        // ferait que « corriger » les coordonnées.
        requete.usesLanguageCorrection = false
        return requete
    }

    func lire(png: Data, precedente: EmpreinteTexte?) -> Resultat {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let luma = LumaBitmap(cgImage: image)
        else { return .illisible }
        let empreinte = EmpreinteTexte(luma)
        if let precedente, empreinte.semblable(a: precedente) { return .inchangee }

        let debut = Date()
        let requete = Self.requete()
        do {
            try VNImageRequestHandler(cgImage: image).perform([requete])
        } catch {
            return .illisible
        }
        // De haut en bas : le nom de la zone précède les coordonnées. Le repère
        // de Vision a son origine en bas.
        let lignes = (requete.results ?? [])
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { $0.topCandidates(1).first?.string }
        return .lue(empreinte, lignes, Date().timeIntervalSince(debut))
    }
}
