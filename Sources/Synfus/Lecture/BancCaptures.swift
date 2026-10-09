import AppKit
import Darwin
import ScreenCaptureKit

/// Mode diagnostic : `Synfus --banc-captures <nom d'app ou pid> [tours]`. Mesure
/// ce que coûtent k zones lues d'une fenêtre, capturées une à une ou d'une
/// seule capture du contenu découpée — de quoi fixer `PlanCapture.seuilCaptureUnique`.
///
/// Même géométrie que la lecture (`GeometrieCapture`, `ZoneEcran.pixels`),
/// même `SCWindow` gardé d'une capture à l'autre (`inventaireGarde`), et
/// chaque zone ramenée en gris (`LumaBitmap`) comme le fait `MoteurOCR` avant
/// tout : une découpe ne coûte qu'à ce moment-là. Rien n'est demandé — sans
/// l'enregistrement de l'écran, il le dit et sort — ; le relevé est aussi
/// écrit dans `$TMPDIR` (`logURL`), lancé par `open` la sortie standard est perdue.
@MainActor
enum BancCaptures {
    enum Mode: String, CaseIterable, Sendable {
        case parZone = "une par zone"
        case entiere = "entière + découpes"
    }

    struct Mesure: Sendable {
        var mur: [Double] = []
        var cpu: [Double] = []
        /// CPU des processus du système qui font la capture, quand ils se laissent lire.
        var cpuSysteme: [Double] = []
        var octetsImage: [Double] = []
        var empreinteMax: UInt64 = 0
        /// Tours dont une capture a été refusée, hors des séries.
        var refus = 0
    }

    /// Une capture refusée : où, et ce que ScreenCaptureKit en dit (`nil` :
    /// l'image n'a pas pu être lue en gris).
    struct Refus: Error, CustomStringConvertible {
        let geometrie: GeometrieCapture
        let erreur: NSError?

        var description: String {
            let ou = "source \(geometrie.source.map { "\($0)" } ?? "fenêtre") pt → \(geometrie.largeur) × \(geometrie.hauteur) px"
            guard let erreur else { return "\(ou) : image illisible" }
            return "\(ou) : \(erreur.domain) \(erreur.code), \(erreur.localizedDescription)"
        }
    }

    static let nombresDeZones = [2, 3, 5, 8]
    /// Entre deux mesures : la machine respire, et la lecture réelle ne
    /// capture pas en rafale.
    private static let pauseMs = 250
    /// Au-delà, la fenêtre n'est plus là (fermée, autre espace) : la suite ne mesurerait que des refus.
    private static let refusAvantAbandon = 16
    /// Les processus où ScreenCaptureKit travaille pour nous.
    private static let processusSysteme = ["WindowServer", "replayd"]

    static let logURL = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "synfus-banc-captures.txt")
    private static var lignes: [String] = []

    private static func dire(_ ligne: String) {
        print(ligne)
        fflush(stdout)
        lignes.append(ligne)
        try? lignes.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)
    }

    /// Huit zones à la façon de `GenreLecture` : ses quatre défauts, puis
    /// quatre petites aux coins et au bord qu'il ne couvre pas.
    nonisolated static func zones(_ k: Int) -> [ZoneEcran] {
        let toutes: [ZoneEcran] = [
            .positionParDefaut, .combatParDefaut, .quetesParDefaut, .chasseParDefaut,
            ZoneEcran(x: 0.70, y: 0.03, largeur: 0.30, hauteur: 0.065),
            ZoneEcran(x: 0.35, y: 0.88, largeur: 0.30, hauteur: 0.08),
            ZoneEcran(x: 0.40, y: 0.02, largeur: 0.20, hauteur: 0.05),
            ZoneEcran(x: 0.80, y: 0.30, largeur: 0.18, hauteur: 0.25),
        ]
        return Array(toutes.prefix(max(0, k)))
    }

    /// Quantile au rang le plus proche ; 0 pour une série vide.
    nonisolated static func quantile(_ valeurs: [Double], _ q: Double) -> Double {
        guard !valeurs.isEmpty else { return 0 }
        let triees = valeurs.sorted()
        let rang = Int((q * Double(triees.count)).rounded(.up)) - 1
        return triees[min(max(rang, 0), triees.count - 1)]
    }

    /// Le plus petit k à partir duquel une capture entière ne coûte, en
    /// médiane, ni plus de temps mur ni plus de CPU (le nôtre et celui du
    /// système, s'il se lit) qu'une capture par zone ; `nil` : jamais.
    nonisolated static func seuilSuggere(_ mesures: [Int: [Mode: Mesure]]) -> Int? {
        func cout(_ m: Mesure) -> (Double, Double) {
            (quantile(m.mur, 0.5), quantile(m.cpu, 0.5) + quantile(m.cpuSysteme, 0.5))
        }
        var seuil: Int?
        for k in mesures.keys.sorted(by: >) {
            guard let parZone = mesures[k]?[.parZone], let entiere = mesures[k]?[.entiere] else { break }
            let (a, b) = (cout(parZone), cout(entiere))
            guard b.0 <= a.0, b.1 <= a.1 else { break }
            seuil = k
        }
        return seuil
    }

    static func runCommandLine(cible: String, tours: Int) -> Never {
        _ = NSApplication.shared
        Task {
            await executer(cible: cible, tours: max(1, tours))
            exit(0)
        }
        dispatchMain()
    }

    private static func executer(cible: String, tours: Int) async {
        guard CGPreflightScreenCaptureAccess() else {
            dire("NON_AUTORISE — l'enregistrement de l'écran n'est pas accordé au processus responsable"
                 + " (le terminal, s'il lance ce binaire). Rien n'est demandé.")
            exit(2)
        }
        let pids = Set(processus(cible))
        guard !pids.isEmpty else { dire("Aucune app « \(cible) » en cours."); exit(1) }
        guard let contenu = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
              var fenetre = contenu.windows
                .filter({ pids.contains($0.owningApplication?.processID ?? -1) && $0.windowLayer == 0 })
                .max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
        else { dire("Aucune fenêtre à l'écran pour « \(cible) »."); exit(1) }

        let taille = fenetre.frame.size
        let natif = GeometrieCapture.natif, barre = GeometrieCapture.barreTitre
        let reglage = CaptureContenu(pleinEcran: false, normaliser: true)
        func geometrie(_ zone: ZoneEcran) -> GeometrieCapture {
            GeometrieCapture(fenetre: taille, region: zone.rect, contenu: reglage, maxWidth: nil,
                             natif: natif, barreTitre: barre)
        }
        let entiere = geometrie(.entiere)
        let systeme = processusSysteme.flatMap { nom in pidsNommes(nom).map { (nom, $0) } }
        let lisibles = systeme.filter { utilisation($0.1) != nil }
        dire("Fenêtre : \(fenetre.owningApplication?.applicationName ?? cible) « \(fenetre.title ?? "") »,"
             + " \(Int(taille.width)) × \(Int(taille.height)) pt ; contenu capturé \(entiere.largeur) × \(entiere.hauteur) px")
        dire("CPU du système lu : " + (lisibles.isEmpty ? "aucun (\(processusSysteme.joined(separator: ", ")) fermés à ce compte)"
                                       : lisibles.map { "\($0.0) (\($0.1))" }.joined(separator: ", ")))
        dire("\(tours) tours × \(nombresDeZones.map(String.init).joined(separator: ", ")) zones × 2 modes,"
             + " \(pauseMs) ms de pause entre deux mesures…")

        /// Comme `PreviewCaptureEngine.captureOne` : une capture refusée sur
        /// l'inventaire gardé se retente une fois sur un inventaire frais — un
        /// changement d'espace ou de fenêtre devant périme le `SCWindow`.
        func capturer(_ geometrie: GeometrieCapture) async -> Result<CGImage, Refus> {
            func essai() async throws -> CGImage {
                try await SCScreenshotManager.captureImage(
                    contentFilter: SCContentFilter(desktopIndependentWindow: fenetre),
                    configuration: geometrie.configuration)
            }
            do { return .success(try await essai()) } catch {
                dire("  refus sur l'inventaire gardé — \(Refus(geometrie: geometrie, erreur: error as NSError)) ; inventaire refait")
            }
            let identifiant = fenetre.windowID
            if let frais = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
               let retrouvee = frais.windows.first(where: { $0.windowID == identifiant }) {
                fenetre = retrouvee
            }
            do { return .success(try await essai()) } catch {
                return .failure(Refus(geometrie: geometrie, erreur: error as NSError))
            }
        }
        /// Un tour de lecture : les captures, et chaque zone en gris.
        func tour(_ mode: Mode, _ zones: [ZoneEcran]) async -> Result<Int, Refus> {
            var octets = 0
            switch mode {
            case .parZone:
                for zone in zones {
                    let geometrie = geometrie(zone)
                    let image: CGImage
                    switch await capturer(geometrie) {
                    case .success(let capturee): image = capturee
                    case .failure(let refus): return .failure(refus)
                    }
                    guard LumaBitmap(cgImage: image) != nil else { return .failure(Refus(geometrie: geometrie, erreur: nil)) }
                    octets += image.bytesPerRow * image.height
                }
            case .entiere:
                let image: CGImage
                switch await capturer(entiere) {
                case .success(let capturee): image = capturee
                case .failure(let refus): return .failure(refus)
                }
                octets = image.bytesPerRow * image.height
                for zone in zones {
                    guard let coupe = CapturesCalibrage.decouper(zone, dans: image), LumaBitmap(cgImage: coupe) != nil
                    else { return .failure(Refus(geometrie: geometrie(zone), erreur: nil)) }
                }
            }
            return .success(octets)
        }

        for (rang, zone) in zones(nombresDeZones.max() ?? 0).enumerated() {
            let g = geometrie(zone)
            dire("zone \(rang + 1) : source \(g.source.map { "\($0.integral)" } ?? "fenêtre") pt → \(g.largeur) × \(g.hauteur) px")
        }

        // Le premier passage paie l'amorçage de ScreenCaptureKit : hors mesure.
        for mode in Mode.allCases {
            if case .failure(let refus) = await tour(mode, zones(2)) { dire("amorçage, \(mode.rawValue) : \(refus)") }
        }

        let mesures = await mesurer(tours: tours, systeme: lisibles.map(\.1), tour: tour)
        imprimer(mesures)
    }

    /// `tours` passages de chaque mode à chaque nombre de zones, le temps mur,
    /// le CPU et la mémoire de chacun.
    private static func mesurer(tours: Int, systeme: [pid_t],
                                tour: (Mode, [ZoneEcran]) async -> Result<Int, Refus>) async -> [Int: [Mode: Mesure]] {
        var mesures: [Int: [Mode: Mesure]] = [:]
        var refusDeSuite = 0
        for numero in 0..<tours where refusDeSuite < refusAvantAbandon {
            // L'ordre alterne d'un tour à l'autre : aucun mode ne profite d'un cache chaud.
            let modes = numero.isMultiple(of: 2) ? Mode.allCases : Mode.allCases.reversed()
            if numero > 0, numero.isMultiple(of: 5) { dire("… \(numero) tours sur \(tours)") }
            for k in nombresDeZones {
                for mode in modes {
                    let avant = utilisation(getpid()), avantSysteme = systeme.compactMap(utilisation)
                    let debut = ContinuousClock.now
                    let resultat = await tour(mode, zones(k))
                    let duree = ContinuousClock.now - debut
                    let apres = utilisation(getpid()), apresSysteme = systeme.compactMap(utilisation)
                    var mesure = mesures[k]?[mode] ?? Mesure()
                    guard case .success(let octets) = resultat else {
                        if case .failure(let refus) = resultat {
                            mesure.refus += 1
                            refusDeSuite += 1
                            dire("tour \(numero + 1), \(k) zones, \(mode.rawValue) : capture refusée — \(refus)")
                        }
                        mesures[k, default: [:]][mode] = mesure
                        if refusDeSuite == refusAvantAbandon { dire("\(refusAvantAbandon) refus de suite : fenêtre perdue, banc arrêté.") }
                        try? await Task.sleep(for: .milliseconds(pauseMs))
                        continue
                    }
                    refusDeSuite = 0
                    mesure.mur.append(Double(duree.components.attoseconds) / 1e15 + Double(duree.components.seconds) * 1000)
                    if let avant, let apres {
                        mesure.cpu.append((apres.cpu - avant.cpu) * 1000)
                        mesure.empreinteMax = max(mesure.empreinteMax, apres.empreinte)
                    }
                    if avantSysteme.count == apresSysteme.count, !avantSysteme.isEmpty {
                        mesure.cpuSysteme.append(zip(avantSysteme, apresSysteme).reduce(0) { $0 + ($1.1.cpu - $1.0.cpu) * 1000 })
                    }
                    mesure.octetsImage.append(Double(octets))
                    mesures[k, default: [:]][mode] = mesure
                    try? await Task.sleep(for: .milliseconds(pauseMs))
                }
            }
        }
        return mesures
    }

    private static func imprimer(_ mesures: [Int: [Mode: Mesure]]) {
        dire("")
        dire("zones  mode                  mur méd/p90 ms   CPU Synfus méd/p90 ms   CPU système méd/p90 ms   image/tour   empreinte max   refus")
        for k in nombresDeZones {
            for mode in Mode.allCases {
                guard let m = mesures[k]?[mode] else { continue }
                func paire(_ v: [Double]) -> String {
                    v.isEmpty ? "—" : String(format: "%.1f / %.1f", quantile(v, 0.5), quantile(v, 0.9))
                }
                let ligne = "\(k)".padding(toLength: 7, withPad: " ", startingAt: 0)
                    + mode.rawValue.padding(toLength: 22, withPad: " ", startingAt: 0)
                    + paire(m.mur).padding(toLength: 17, withPad: " ", startingAt: 0)
                    + paire(m.cpu).padding(toLength: 24, withPad: " ", startingAt: 0)
                    + paire(m.cpuSysteme).padding(toLength: 25, withPad: " ", startingAt: 0)
                    + String(format: "%.2f Mo", quantile(m.octetsImage, 0.5) / 1_048_576).padding(toLength: 13, withPad: " ", startingAt: 0)
                    + String(format: "%.0f Mo", Double(m.empreinteMax) / 1_048_576).padding(toLength: 16, withPad: " ", startingAt: 0)
                    + "\(m.refus)"
                dire(ligne)
            }
        }
        dire("")
        dire("Seuil suggéré (capture entière dès k zones) : " + (seuilSuggere(mesures).map(String.init) ?? "aucun, jamais moins cher"))
        dire("Relevé écrit dans \(logURL.path)")
    }

    /// Les processus d'une app : un pid, sinon le nom affiché (exact, puis
    /// contenu) ou l'identifiant de bundle.
    private static func processus(_ cible: String) -> [pid_t] {
        if let pid = pid_t(cible) { return [pid] }
        let apps = NSWorkspace.shared.runningApplications
        let cherche = cible.lowercased()
        let exactes = apps.filter { $0.localizedName?.lowercased() == cherche }
        let retenues = exactes.isEmpty
            ? apps.filter { ($0.localizedName?.lowercased().contains(cherche) ?? false)
                || ($0.bundleIdentifier?.lowercased().contains(cherche) ?? false) }
            : exactes
        return retenues.map(\.processIdentifier)
    }

    private static func pidsNommes(_ nom: String) -> [pid_t] {
        let nombre = proc_listallpids(nil, 0)
        guard nombre > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(nombre) * 2)
        let lus = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        return pids.prefix(Int(max(lus, 0))).filter { pid in
            var tampon = [CChar](repeating: 0, count: 256)
            return proc_name(pid, &tampon, UInt32(tampon.count)) > 0 && String(utf8String: tampon) == nom
        }
    }

    /// CPU consommé (secondes, utilisateur + système) et empreinte mémoire
    /// d'un processus ; `nil` s'il ne se laisse pas lire.
    private static func utilisation(_ pid: pid_t) -> (cpu: Double, empreinte: UInt64)? {
        var info = rusage_info_v2()
        let ok = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) == 0
            }
        }
        guard ok else { return nil }
        // En unités de `mach_absolute_time`, pas en nanosecondes (Apple Silicon).
        var base = mach_timebase_info_data_t()
        mach_timebase_info(&base)
        let ticks = Double(info.ri_user_time + info.ri_system_time)
        return (ticks * Double(base.numer) / Double(base.denom) / 1e9, info.ri_phys_footprint)
    }
}
