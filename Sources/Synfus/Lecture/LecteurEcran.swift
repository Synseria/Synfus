import AppKit
import Combine
import ImageIO
import Vision

/// Ce qu'on lit dans la fenêtre du jeu, et où.
enum GenreLecture: String, CaseIterable, Sendable {
    /// Le nom de la zone et les coordonnées, en haut à gauche.
    case position
    /// Le bouton « Fin de tour » et son décompte, en bas à droite par défaut.
    case combat

    @MainActor var zone: ZoneEcran {
        let prefs = Preferences.shared
        switch self {
        case .position: return prefs.zonePosition ?? .positionParDefaut
        case .combat: return prefs.zoneCombat ?? .combatParDefaut
        }
    }
}

/// Lit l'écran du jeu : la position du perso, et son état de combat.
///
/// Le coût est tenu par quatre choix, mesurés sur de vraies captures :
///
/// - **Des zones serrées** (`ZoneEcran`), en fractions du *contenu* de la
///   fenêtre : l'interface du jeu suit la taille de la fenêtre, la zone aussi.
///   Calibrables d'un tracé dans le Diagnostic.
/// - **Une échelle fixe** : le contenu est ramené à 1080 pixels de haut
///   (`ZoneEcran.hauteurReference`), le texte y a toujours la même taille —
///   celle où Vision lit juste (`.fast` ne lit rien de la police du jeu). Une
///   grande fenêtre ne coûte pas plus qu'une petite.
/// - **L'OCR ne repasse que si la zone a changé** (`SignatureZone` : pixels
///   clairs réduits à une grille, et pour le combat, bouton coloré ou non).
///   Entre deux cartes, entre deux tours, un relevé ne coûte qu'une capture de
///   quelques centaines de pixels.
/// - **L'inventaire ScreenCaptureKit gardé** (`inventaireGarde`).
///
/// Seul le perso au premier plan est lu en continu, une fois par seconde : en
/// plein écran, macOS ne redessine pas les autres fenêtres. Les autres le sont
/// au survol de leur pastille (position, relevé de plus de 10 s) et par
/// « Tout lire » dans le Diagnostic — réglages ouverts, Synfus est devant et
/// le tour régulier n'a plus rien à lire.
@MainActor
final class LecteurEcran: ObservableObject {
    static let shared = LecteurEcran()

    struct Releve: Equatable {
        var position: PositionCarte?
        /// Les lignes brutes du dernier OCR — pour le Diagnostic.
        var lignes: [String]
        var date: Date
    }

    /// Dernière position de chaque perso, par nom. Ne change qu'au
    /// changement de carte : la barre peut l'observer sans se redessiner à
    /// chaque seconde — les compteurs vivent dans `DiagnosticLecture`.
    @Published private(set) var releves: [String: Releve] = [:]
    /// Dernier état de combat connu de chaque perso, par nom. Celui d'un perso
    /// qui n'est pas devant date de la dernière fois qu'il l'a été.
    @Published private(set) var combats: [String: EtatCombat] = [:]

    private let moteur = MoteurOCR()
    private let diagnostic = DiagnosticLecture.shared
    private var signatures: [String: SignatureZone] = [:]
    /// Dernière capture de chaque perso et de chaque genre, lue ou sautée —
    /// la fraîcheur, hors des `@Published`.
    private var vuLe: [String: Date] = [:]
    private var timer: Timer?
    private var persoDevant: String?
    private var prechauffe = false
    /// Lectures demandées, dans l'ordre — le tour, un survol, le bouton du
    /// Diagnostic. Une à la fois : l'OCR est séquentiel.
    private var file: [(client: DofusClient, genre: GenreLecture)] = []
    private var busy = false
    private var subscriptions: Set<AnyCancellable> = []

    private static let intervalle: TimeInterval = 1
    /// Au survol, une position plus récente que cela suffit.
    private static let fraicheurSurvol: TimeInterval = 10

    private init() {}

    private var genresActifs: [GenreLecture] {
        let prefs = Preferences.shared
        return GenreLecture.allCases.filter {
            switch $0 {
            case .position: return prefs.lirePosition
            case .combat: return prefs.lireCombat
            }
        }
    }

    func start() {
        // Les valeurs émises, pas les propriétés : `@Published` publie avant
        // d'affecter.
        Preferences.shared.$lirePosition
            .combineLatest(Preferences.shared.$lireCombat)
            .map { $0 || $1 }
            .removeDuplicates()
            .sink { [weak self] actif in
                MainActor.assumeIsolated { actif ? self?.armer() : self?.desarmer() }
            }
            .store(in: &subscriptions)
        // Une zone recalibrée : l'ancienne signature ne dit plus rien.
        Preferences.shared.$zonePosition.combineLatest(Preferences.shared.$zoneCombat)
            .dropFirst()
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.signatures = [:] } }
            .store(in: &subscriptions)
        // Une bascule : on lit le nouveau perso sans attendre le tour suivant,
        // une fois la transition d'espace passée.
        WindowManager.shared.$frontmostPID
            .removeDuplicates()
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard self?.timer != nil else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        MainActor.assumeIsolated { LecteurEcran.shared.tour() }
                    }
                }
            }
            .store(in: &subscriptions)
    }

    private func armer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.intervalle, repeats: true) { _ in
            MainActor.assumeIsolated { LecteurEcran.shared.tour() }
        }
        timer?.tolerance = 0.3
        guard !prechauffe else { diagnostic.etat = .attente; return }
        // Le premier OCR `accurate` charge le modèle de Vision — mesuré jusqu'à
        // vingt-huit secondes sur une machine froide. On le paie ici, une
        // fois, plutôt qu'au premier relevé, qui semblait ne jamais venir.
        diagnostic.etat = .preparation
        busy = true
        Task {
            await moteur.prechauffer()
            prechauffe = true
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
        persoDevant = client.name
        for genre in genresActifs { demander(client, genre) }
        pomper()
    }

    /// La position du dernier perso lu au premier plan — celui dont le tchat
    /// reçoit le prochain collage, même si l'on vient de copier ailleurs.
    var positionDuPersoDevant: PositionCarte? {
        persoDevant.flatMap { releves[$0]?.position }
    }

    /// Au survol d'une pastille : la position de ce perso-là, si elle n'a pas
    /// été relevée depuis dix secondes. Le perso devant est lu chaque seconde,
    /// les autres ne bougent pas tant qu'on ne les joue pas.
    func lireAuSurvol(_ client: DofusClient) {
        guard timer != nil, Preferences.shared.lirePosition else { return }
        if let vu = vuLe[cle(.position, client.name)], Date().timeIntervalSince(vu) < Self.fraicheurSurvol { return }
        demander(client, .position)
        pomper()
    }

    /// Le bouton du Diagnostic : tous les persos, une fois.
    func toutLire() {
        guard timer != nil else { return }
        for client in WindowManager.shared.clients {
            for genre in genresActifs { demander(client, genre) }
        }
        pomper()
    }

    private func cle(_ genre: GenreLecture, _ nom: String) -> String { "\(genre.rawValue)|\(nom)" }

    private func demander(_ client: DofusClient, _ genre: GenreLecture) {
        guard WindowTitle.isPersistableName(client.name),
              !WindowManager.shared.unreachablePIDs.contains(client.pid),
              !file.contains(where: { $0.client.slotKey == client.slotKey && $0.genre == genre })
        else { return }
        file.append((client, genre))
    }

    private func pomper() {
        guard !busy, timer != nil, !file.isEmpty else { return }
        let (client, genre) = file.removeFirst()
        let previews = WindowPreviewService.shared
        guard previews.authorized else { file = []; diagnostic.etat = .nonAutorise; return }

        busy = true
        let nom = client.name
        let cle = cle(genre, nom)
        let precedente = signatures[cle]
        Task {
            defer {
                busy = false
                pomper()
            }
            guard let png = await previews.captureData(
                client, region: genre.zone.rect, maxWidth: nil, inventaireGarde: true,
                contenu: CaptureContenu(pleinEcran: client.pleinEcran, normaliser: true))
            else {
                diagnostic.etat = .echecCapture(previews.lastCaptureError ?? "?")
                return
            }
            diagnostic.captures[genre] = NSImage(data: png)
            diagnostic.dernierPerso = nom
            switch await moteur.lire(png: png, precedente: precedente, couleur: genre == .combat) {
            case .illisible:
                diagnostic.etat = .echecCapture("PNG illisible")
            case .inchangee(let signature):
                // Rien de neuf, mais le relevé reste vrai à cet instant.
                vuLe[cle] = Date()
                diagnostic.sautes += 1
                diagnostic.etat = .actif
            case .lue(let signature, let lignes, let duree, let couleurBouton):
                signatures[cle] = signature
                vuLe[cle] = Date()
                diagnostic.lectures += 1
                diagnostic.derniereDuree = duree
                diagnostic.lignes[genre] = lignes
                switch genre {
                case .position: appliquerPosition(lignes, nom: nom)
                case .combat: appliquerCombat(lignes, couleur: couleurBouton ?? signature.couleur ?? 0, nom: nom)
                }
            }
        }
    }

    private func appliquerPosition(_ lignes: [String], nom: String) {
        let lue = PositionCarte.lire(lignes)
        diagnostic.etat = lue == nil ? .sansCoordonnees : .actif
        // Une lecture sans coordonnées — écran de chargement, fenêtre du jeu
        // posée sur le coin — garde la dernière position connue.
        releves[nom] = Releve(position: lue ?? releves[nom]?.position, lignes: lignes, date: Date())
    }

    private func appliquerCombat(_ lignes: [String], couleur: Double, nom: String) {
        diagnostic.couleur = couleur
        diagnostic.etat = .actif
        let constat = LectureCombat.classer(lignes: lignes, couleur: couleur)
        let etat = EtatCombat.depuis(constat, avant: combats[nom], maintenant: Date())
        if combats[nom] != etat { combats[nom] = etat }
    }
}

/// Ce que la lecture fait et coûte, pour le seul Diagnostic. Séparé de
/// `LecteurEcran` pour que la barre, qui observe relevés et combats, ne se
/// redessine pas à chaque compteur — même partage que `AttentionDiagnostics`.
@MainActor
final class DiagnosticLecture: ObservableObject {
    static let shared = DiagnosticLecture()

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
    /// Chaque zone telle que l'OCR l'a vue — la première chose à regarder
    /// quand rien n'est lu : la zone tombe-t-elle au bon endroit ?
    @Published var captures: [GenreLecture: NSImage] = [:]
    @Published var lignes: [GenreLecture: [String]] = [:]
    /// Part colorée du bouton à la dernière lecture de combat — est-il le mien ?
    @Published var couleur: Double?
    @Published var dernierPerso: String?

    private init() {}
}

/// Ce qui décide de relancer l'OCR : le texte clair, et pour le bouton de
/// combat, sa couleur — le même « Fin de tour » blanc passe du gris à la
/// couleur sans qu'un pixel clair ne bouge.
struct SignatureZone: Equatable, Sendable {
    let empreinte: EmpreinteTexte
    /// Part colorée de la zone entière, pour les zones où la couleur compte.
    let couleur: Double?

    func semblable(a autre: SignatureZone) -> Bool {
        guard empreinte.semblable(a: autre.empreinte) else { return false }
        guard let couleur, let autre = autre.couleur else { return true }
        return (couleur >= LectureCombat.seuilSignature) == (autre >= LectureCombat.seuilSignature)
    }
}

/// L'OCR, hors du main actor. Sans état : il reçoit un PNG et la signature
/// précédente, rend la signature et — seulement si elle a changé — les
/// lignes lues. Il n'en entre et n'en sort que des valeurs `Sendable`.
actor MoteurOCR {
    enum Resultat: Sendable {
        case illisible
        case inchangee(SignatureZone)
        /// Les lignes, la durée de l'OCR, et pour le combat la part colorée
        /// du corps du bouton — `nil` si aucun bouton n'a été lu.
        case lue(SignatureZone, [String], TimeInterval, couleurBouton: Double?)
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

    func lire(png: Data, precedente: SignatureZone?, couleur: Bool) -> Resultat {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let luma = LumaBitmap(cgImage: image)
        else { return .illisible }
        let rgba = couleur ? Self.rgba(image) : nil
        let signature = SignatureZone(
            empreinte: EmpreinteTexte(luma),
            couleur: rgba.map { LectureCombat.ratioColore(rgba: $0, largeur: image.width) })
        if let precedente, signature.semblable(a: precedente) { return .inchangee(signature) }

        let debut = Date()
        let requete = Self.requete()
        let encadree = Self.encadree(image)
        do {
            try VNImageRequestHandler(cgImage: encadree ?? image).perform([requete])
        } catch {
            return .illisible
        }
        // De haut en bas : le nom de la zone précède les coordonnées, le
        // décompte précède le bouton. Le repère de Vision a son origine en bas.
        let observations = (requete.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        let lignes = observations.compactMap { $0.topCandidates(1).first?.string }

        // La couleur du bouton se mesure autour de son texte, en pixels de
        // l'image d'origine : la boîte de Vision est normalisée, origine en
        // bas, dans l'image encadrée de sa marge.
        var couleurBouton: Double?
        if let rgba, let bouton = observations.first(where: {
            LectureCombat.estBouton($0.topCandidates(1).first?.string ?? "")
        }) {
            let marge = encadree == nil ? 0 : CGFloat(Self.marge)
            let (lp, hp) = (CGFloat(image.width) + 2 * marge, CGFloat(image.height) + 2 * marge)
            let boite = bouton.boundingBox
            let texte = CGRect(x: boite.minX * lp - marge, y: (1 - boite.maxY) * hp - marge,
                               width: boite.width * lp, height: boite.height * hp)
            let corps = LectureCombat.corpsDuBouton(texte: texte,
                                                    image: CGSize(width: image.width, height: image.height))
            couleurBouton = LectureCombat.ratioColore(rgba: rgba, largeur: image.width, dans: corps)
        }
        return .lue(signature, lignes, Date().timeIntervalSince(debut), couleurBouton: couleurBouton)
    }

    /// L'image posée sur une marge sombre. Une zone serrée coupe le texte au
    /// ras du bord — le signe moins des coordonnées touche le bord gauche de
    /// la fenêtre —, et Vision lit mal un glyphe collé au cadre : mesuré,
    /// « a16 » pour « -16 » sans marge. Le texte du jeu est clair cerné de
    /// sombre : une marge noire le prolonge sans rien inventer.
    private static let marge = 12

    private static func encadree(_ image: CGImage) -> CGImage? {
        let (w, h) = (image.width + 2 * marge, image.height + 2 * marge)
        guard let contexte = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                       space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        contexte.setFillColor(CGColor(gray: 0, alpha: 1))
        contexte.fill(CGRect(x: 0, y: 0, width: w, height: h))
        contexte.draw(image, in: CGRect(x: marge, y: marge, width: image.width, height: image.height))
        return contexte.makeImage()
    }

    /// L'image rendue en RGBA 8 bits par CoreGraphics.
    private static func rgba(_ image: CGImage) -> [UInt8]? {
        let (w, h) = (image.width, image.height)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let contexte = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                           bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return false }
            contexte.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? pixels : nil
    }
}
