import AppKit
import Combine
import Vision

/// Ce qu'on lit dans la fenêtre du jeu, et où. Chaque genre a sa zone, son
/// défaut et son réglage : la table est ici, nulle part ailleurs.
enum GenreLecture: String, CaseIterable, Sendable {
    /// Le nom de la zone et les coordonnées, en haut à gauche.
    case position
    /// Le bouton « Fin de tour » et son décompte, en bas à droite par défaut.
    case combat
    /// Le suivi de chasse au trésor, à gauche par défaut.
    case chasse
    /// Le suivi de quêtes du jeu, à gauche par défaut : au tour tant que le
    /// panneau des quêtes est montré (`suivreQuetes`), à un rythme plus lent
    /// — un objectif qui se termine le change, mais sa zone est grande. La
    /// chasse n'est lue qu'à la demande (`lireUneFois`).
    case quetes
    /// Le cœur de vie, au centre de la barre du bas : en combat, tant que le
    /// panneau d'aide aux boss est montré (`suivreBoss`).
    case vie
    /// Le tchat, en bas à gauche, où le canal combat annonce les effets : comme
    /// la vie, en combat et panneau d'aide montré.
    case tchat

    var parDefaut: ZoneEcran {
        switch self {
        case .position: return .positionParDefaut
        case .combat: return .combatParDefaut
        case .chasse: return .chasseParDefaut
        case .quetes: return .quetesParDefaut
        case .vie: return .vieParDefaut
        case .tchat: return .tchatParDefaut
        }
    }

    /// Le réglage de la zone calibrée ; `nil` y vaut le défaut.
    @MainActor var reglage: ReferenceWritableKeyPath<Preferences, ZoneEcran?> {
        switch self {
        case .position: return \.zonePosition
        case .combat: return \.zoneCombat
        case .chasse: return \.zoneChasse
        case .quetes: return \.zoneQuetes
        case .vie: return \.zoneVie
        case .tchat: return \.zoneTchat
        }
    }

    @MainActor var zone: ZoneEcran { Preferences.shared[keyPath: reglage] ?? parDefaut }

    /// Au tour, une capture du même perso au plus toutes les tant de secondes.
    /// Le combat, hors combat, toutes les trois : on n'y entre que par un
    /// placement, qui dure bien plus ; vu en cours (`enCombat`), chaque
    /// seconde jusqu'à ce que la lecture le dise fini — son tour en dépend.
    func intervalle(combat: EtatCombat?) -> TimeInterval {
        switch self {
        case .position, .chasse, .vie, .tchat: return 1
        case .quetes: return 3
        case .combat: return combat?.enCombat == true ? 1 : 3
        }
    }

    /// Ce que la signature regarde pour relancer l'OCR.
    var mesure: MesureSignature {
        switch self {
        case .position, .vie: return .zone
        case .combat: return .bouton
        case .chasse, .quetes, .tchat: return .lignes
        }
    }
}

/// Comment capturer les zones dues au même tour chez un perso. Une capture
/// ScreenCaptureKit a un coût fixe (aller-retour avec le serveur de fenêtres)
/// et un coût qui suit les pixels : au-delà d'un nombre de zones, une seule
/// capture du contenu entier, découpée, revient moins cher que plusieurs.
enum PlanCapture: Equatable {
    /// Une capture par zone, de la zone seule.
    case parZone
    /// Une capture du contenu entier à l'échelle de référence, puis une
    /// découpe par zone (`CGImage.cropping`, sans copie des pixels).
    case entiere

    /// Mesuré par `Synfus --banc-captures` (fenêtre de 1728 × 1084 pt) : dès
    /// deux zones, l'entière coûte moins — 43 ms de mur et 11 ms de CPU
    /// (Synfus + replayd) contre 67 et 18, l'écart grandissant avec les zones
    /// (54 contre 166 ms à huit) —, pour 7,4 Mo d'image le temps du tour. Une
    /// zone seule reste capturée seule : le cas le plus fréquent, et le plus
    /// léger.
    static let seuilCaptureUnique = 2

    static func pour(_ genres: [GenreLecture], seuil: Int = seuilCaptureUnique) -> PlanCapture {
        Set(genres).count >= seuil ? .entiere : .parZone
    }
}

/// La file des lectures : la première demande et toutes celles du même perso
/// partent ensemble, dans l'ordre de la file. Pur.
enum FileLecture {
    static func extraire<Demande>(_ file: [Demande],
                                  memePerso: (Demande, Demande) -> Bool) -> (lot: [Demande], reste: [Demande]) {
        guard let premiere = file.first else { return ([], []) }
        var lot: [Demande] = [], reste: [Demande] = []
        for demande in file { if memePerso(premiere, demande) { lot.append(demande) } else { reste.append(demande) } }
        return (lot, reste)
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
/// - **L'OCR ne repasse que si le texte a changé** (`SignatureZone` : pixels
///   clairs réduits à une grille, là où le texte a été lu — les lignes d'un
///   suivi, le corps du bouton de combat — et pour le combat, bouton coloré
///   ou non). Entre deux cartes, entre deux tours, un relevé ne coûte qu'une
///   capture.
/// - **L'inventaire ScreenCaptureKit gardé** (`inventaireGarde`).
///
/// Seul le perso au premier plan est lu en continu, une fois par seconde (le
/// combat toutes les trois hors combat, le suivi de quêtes toutes les trois,
/// cf. `GenreLecture.intervalle`) : en plein écran, macOS ne redessine pas
/// les autres fenêtres. Les autres le sont
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
    }

    /// Dernière position de chaque perso, par nom. Ne change qu'au
    /// changement de carte : la barre peut l'observer sans se redessiner à
    /// chaque seconde — les compteurs vivent dans `DiagnosticLecture`.
    @Published private(set) var releves: [String: Releve] = [:]
    /// Dernier état de combat connu de chaque perso, par nom. Celui d'un perso
    /// qui n'est pas devant date de la dernière fois qu'il l'a été.
    @Published private(set) var combats: [String: EtatCombat] = [:]
    /// Les persos dont un combat vient de finir là où ils sont encore.
    @Published private(set) var finsDeCombat = FinsDeCombat()

    private let moteur = MoteurOCR()
    private let diagnostic = DiagnosticLecture.shared
    private var signatures: [String: SignatureZone] = [:]
    /// Dernière capture de chaque perso et de chaque genre, lue ou sautée —
    /// la fraîcheur, hors des `@Published`.
    private var vuLe: [String: Date] = [:]
    private var timer: Timer?
    /// Le dernier perso lu au premier plan : ne change qu'à la bascule.
    @Published private(set) var persoDevant: String?
    /// Lire la position ou le combat, d'après les réglages.
    private var lectureReglee = false
    /// Le panneau des quêtes est à l'écran : son suivi est lu au tour.
    private var suiviMontre = false
    /// Le panneau d'aide aux boss est à l'écran : le combat est lu au tour,
    /// la vie et le tchat aussi pendant un combat.
    private var bossMontre = false
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
            case .combat: return prefs.lireCombat || bossMontre
            case .chasse, .quetes, .vie, .tchat: return false
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
                MainActor.assumeIsolated {
                    self?.lectureReglee = actif
                    self?.revoirArmement()
                }
            }
            .store(in: &subscriptions)
        // Une zone recalibrée : l'ancienne signature ne dit plus rien.
        let prefs = Preferences.shared
        let zones = [prefs.$zonePosition, prefs.$zoneCombat, prefs.$zoneQuetes, prefs.$zoneVie, prefs.$zoneTchat]
        Publishers.MergeMany(zones)
            .dropFirst(zones.count)
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

    /// Le panneau des quêtes paraît ou disparaît (`QuetePanel`) : son suivi
    /// entre au tour ou en sort. Jamais l'enregistrement de l'écran demandé.
    func suivreQuetes(_ montre: Bool) {
        guard montre != suiviMontre else { return }
        suiviMontre = montre
        revoirArmement()
    }

    /// Le panneau d'aide aux boss paraît ou disparaît (`BossPanel`) : combat,
    /// vie et tchat entrent au tour ou en sortent. Jamais l'enregistrement de
    /// l'écran demandé.
    func suivreBoss(_ montre: Bool) {
        guard montre != bossMontre else { return }
        bossMontre = montre
        revoirArmement()
    }

    private func revoirArmement() {
        lectureReglee || suiviMontre || bossMontre ? armer() : desarmer()
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
        if persoDevant != client.name { persoDevant = client.name }
        for genre in genresActifs where perime(genre, client.name) { demander(client, genre) }
        if suiviMontre, QuetesStore.shared.quetes != nil, perime(.quetes, client.name) { demander(client, .quetes) }
        if bossMontre, combats[client.name]?.enCombat == true {
            for genre in [GenreLecture.vie, .tchat] where perime(genre, client.name) { demander(client, genre) }
        }
        pomper()
    }

    /// La dernière capture de ce genre chez ce perso a son intervalle, à la
    /// tolérance du minuteur près.
    private func perime(_ genre: GenreLecture, _ nom: String) -> Bool {
        let intervalle = genre.intervalle(combat: combats[nom])
        return vuLe[cle(genre, nom)].map { Date().timeIntervalSince($0) >= intervalle - Self.intervalle / 2 } ?? true
    }

    /// La position du dernier perso lu au premier plan — celui dont le tchat
    /// reçoit le prochain collage, même si l'on vient de copier ailleurs.
    var positionDuPersoDevant: PositionCarte? {
        persoDevant.flatMap { releves[$0]?.position }
    }

    /// Le perso devant vient de finir un combat sur la carte où il se tient.
    var combatFiniDevant: Bool {
        persoDevant.map { finsDeCombat.fini($0, en: releves[$0]?.position) } ?? false
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

    /// La première demande de la file et toutes celles du même perso, en une
    /// capture (`PlanCapture`) ; puis l'OCR de chaque genre, l'un après l'autre.
    private func pomper() {
        guard !busy, timer != nil, !file.isEmpty else { return }
        let (lot, reste) = FileLecture.extraire(file) { $0.client.slotKey == $1.client.slotKey }
        file = reste
        let client = lot[0].client, genres = lot.map(\.genre)
        let previews = WindowPreviewService.shared
        guard previews.authorized else { file = []; diagnostic.etat = .nonAutorise; return }

        busy = true
        Task {
            defer {
                busy = false
                pomper()
            }
            // L'image entière, s'il y en a une, ne vit que le temps de ce lot :
            // les découpes la retiennent, le Diagnostic en garde des copies.
            let images = await capturer(client, genres)
            for genre in genres {
                guard let image = images[genre] else {
                    diagnostic.etat = .echecCapture(previews.lastCaptureError ?? "?")
                    continue
                }
                await lire(image, genre, nom: client.name)
            }
        }
    }

    private func lire(_ image: CGImage, _ genre: GenreLecture, nom: String) async {
        let cle = cle(genre, nom)
        switch await moteur.lire(image: image, precedente: signatures[cle], mesure: genre.mesure) {
        case .illisible:
            diagnostic.etat = .echecCapture("image illisible")
        case .inchangee:
            // Rien de neuf, mais le relevé reste vrai à cet instant.
            vuLe[cle] = Date()
            diagnostic.sautes += 1
            diagnostic.etat = .actif
            if genre == .quetes { LectureSuivi.shared.confirmer(nom) }
        case .lue(let signature, let lignes, let duree, let couleurBouton):
            signatures[cle] = signature
            vuLe[cle] = Date()
            diagnostic.lectures += 1
            diagnostic.derniereDuree = duree
            diagnostic.lignes[genre] = lignes
            switch genre {
            case .position: appliquerPosition(lignes, nom: nom)
            case .combat: appliquerCombat(lignes, couleur: couleurBouton ?? signature.couleur ?? 0, nom: nom)
            case .quetes: LectureSuivi.shared.recevoir(lignes, coupe: signature.auBord, perso: nom)
            case .vie: AideBoss.shared.recevoirVie(lignes, perso: nom)
            case .tchat: AideBoss.shared.recevoirTchat(lignes, perso: nom)
            case .chasse: break
            }
        }
    }

    /// Le seul chemin de capture des zones d'un perso : à l'échelle de
    /// référence, selon `PlanCapture`, et montrées au Diagnostic telles que
    /// l'OCR les reçoit. Une zone manquante n'a pas pu être capturée
    /// (`lastCaptureError`).
    private func capturer(_ client: DofusClient, _ genres: [GenreLecture]) async -> [GenreLecture: CGImage] {
        let service = WindowPreviewService.shared
        let contenu = CaptureContenu(pleinEcran: client.pleinEcran, normaliser: true)
        var images: [GenreLecture: CGImage] = [:]
        let plan = PlanCapture.pour(genres)
        switch plan {
        case .parZone:
            for genre in genres {
                images[genre] = await service.captureImage(client, region: genre.zone.rect, maxWidth: nil,
                                                           inventaireGarde: true, contenu: contenu)
            }
        case .entiere:
            guard let entiere = await service.captureImage(client, region: ZoneEcran.entiere.rect, maxWidth: nil,
                                                           inventaireGarde: true, contenu: contenu)
            else { return [:] }
            for genre in genres { images[genre] = CapturesCalibrage.decouper(genre.zone, dans: entiere) }
        }
        guard !images.isEmpty else { return [:] }
        for (genre, image) in images {
            // Une découpe retient toute l'image entière : le Diagnostic, qui la
            // garde jusqu'au prochain tour, n'en reçoit qu'une copie.
            guard let vignette = plan == .entiere ? CapturesCalibrage.copie(image) : image else { continue }
            diagnostic.captures[genre] = NSImage(cgImage: vignette, size: .zero)
        }
        diagnostic.dernierPerso = client.name
        return images
    }

    /// Une lecture à la demande, hors du tour et sans signature précédente :
    /// les lignes de la zone `genre` chez le perso devant — ou le dernier lu
    /// devant, si Synfus vient de passer au premier plan —, le nom de ce
    /// perso, et si le texte touche le bas de la zone (`SignatureZone.auBord`).
    /// `nil` : rien à lire (aucun perso, pas d'autorisation, capture manquée).
    /// Sa signature est gardée : le tour suivant n'y repasse pas pour rien. Le
    /// moteur est un acteur : une lecture du tour en cours passe avant, sans
    /// se mélanger.
    func lireUneFois(_ genre: GenreLecture) async -> (perso: String, lignes: [String], coupe: Bool)? {
        let manager = WindowManager.shared
        let devant = manager.clients.first(where: { manager.isFrontmost($0) })
        guard WindowPreviewService.shared.authorized,
              let client = devant ?? manager.clients.first(where: { $0.name == persoDevant }),
              let image = await capturer(client, [genre])[genre],
              case .lue(let signature, let lignes, _, _) = await moteur.lire(image: image, precedente: nil,
                                                                             mesure: genre.mesure)
        else { return nil }
        if devant != nil, persoDevant != client.name { persoDevant = client.name }
        signatures[cle(genre, client.name)] = signature
        vuLe[cle(genre, client.name)] = Date()
        diagnostic.lignes[genre] = lignes
        return (client.name, lignes, signature.auBord)
    }

    /// L'OCR d'une zone déjà découpée — l'essai du calibrage, sur la capture
    /// gardée : même moteur, même encadrement que le tour. La couleur est
    /// celle du bouton de combat, sinon de la zone (cf. `pomper`).
    func lire(image: CGImage, genre: GenreLecture) async -> (lignes: [String], couleur: Double)? {
        guard case .lue(let signature, let lignes, _, let bouton)
                = await moteur.lire(image: image, precedente: nil, mesure: genre.mesure)
        else { return nil }
        return (lignes, bouton ?? signature.couleur ?? 0)
    }

    private func appliquerPosition(_ lignes: [String], nom: String) {
        let lue = PositionCarte.lire(lignes)
        diagnostic.etat = lue == nil ? .sansCoordonnees : .actif
        // Une lecture sans coordonnées — écran de chargement, fenêtre du jeu
        // posée sur le coin — garde la dernière position connue.
        let releve = Releve(position: lue ?? releves[nom]?.position, lignes: lignes)
        if releves[nom] != releve { releves[nom] = releve }
        var fins = finsDeCombat
        fins.position(nom, lue)
        if fins != finsDeCombat { finsDeCombat = fins }
    }

    private func appliquerCombat(_ lignes: [String], couleur: Double, nom: String) {
        diagnostic.couleur = couleur
        diagnostic.etat = .actif
        let constat = LectureCombat.classer(lignes: lignes, couleur: couleur)
        let etat = EtatCombat.depuis(constat, avant: combats[nom], maintenant: Date())
        var fins = finsDeCombat
        fins.combat(nom, avant: combats[nom], apres: etat, ici: releves[nom]?.position)
        if fins != finsDeCombat { finsDeCombat = fins }
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

/// L'OCR, hors du main actor. Sans état : il reçoit l'image capturée et la
/// signature précédente, rend la signature et — seulement si elle a changé —
/// les lignes lues. Il n'en entre et n'en sort que des valeurs `Sendable`.
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

    func lire(image: CGImage, precedente: SignatureZone?, mesure: MesureSignature) -> Resultat {
        guard let luma = LumaBitmap(cgImage: image) else { return .illisible }
        let rgba = mesure == .bouton ? Self.rgba(image) : nil
        let couleur = rgba.map { LectureCombat.ratioColore(rgba: $0, largeur: image.width) }
        let signature = SignatureZone(luma, mesure: mesure, cadre: precedente?.cadre, couleur: couleur,
                                      auBord: precedente?.auBord ?? false)
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

        // Les boîtes de Vision, normalisées, origine en bas, dans l'image
        // encadrée de sa marge → pixels de l'image d'origine, origine en haut.
        let taille = CGSize(width: image.width, height: image.height)
        let marge = encadree == nil ? 0 : CGFloat(Self.marge)
        let (lp, hp) = (taille.width + 2 * marge, taille.height + 2 * marge)
        func pixels(_ boite: CGRect) -> CGRect {
            CGRect(x: boite.minX * lp - marge, y: (1 - boite.maxY) * hp - marge,
                   width: boite.width * lp, height: boite.height * hp)
        }
        var couleurBouton: Double?, cadre: CGRect?, auBord = false
        switch mesure {
        case .zone:
            break
        case .bouton:
            // La couleur du bouton se mesure autour de son texte, et c'est là
            // que la prochaine capture cherchera un changement.
            if let bouton = observations.first(where: { LectureCombat.estBouton($0.topCandidates(1).first?.string ?? "") }) {
                let corps = LectureCombat.corpsDuBouton(texte: pixels(bouton.boundingBox), image: taille)
                cadre = corps
                couleurBouton = rgba.map { LectureCombat.ratioColore(rgba: $0, largeur: image.width, dans: corps) }
            }
        case .lignes:
            if let lu = SignatureZone.cadre(lignes: observations.map { pixels($0.boundingBox) }, image: taille) {
                (cadre, auBord) = lu
            }
        }
        let lue = SignatureZone(luma, mesure: mesure, cadre: cadre, couleur: couleur, auBord: auBord)
        return .lue(lue, lignes, Date().timeIntervalSince(debut), couleurBouton: couleurBouton)
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
