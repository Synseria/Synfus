import AppKit
import ApplicationServices

/// Achève les clients gelés à la fermeture, même quand elle n'est pas passée
/// par Synfus.
///
/// Le scénario : l'utilisateur ferme la fenêtre du client par le jeu lui-même,
/// le processus gèle — systématiquement chez certains joueurs — et il faut
/// « Forcer à quitter » à la main. Vu d'ici, ce client est un processus vivant
/// qui ne rend plus aucune fenêtre… exactement comme un client sain dont
/// l'espace plein écran est inactif. Ce qui les distingue est la **réponse** :
/// un client sain répond à l'Accessibilité (une liste vide est une réponse),
/// un client gelé laisse la question expirer.
///
/// D'où la règle, volontairement stricte pour ne jamais abattre un vivant :
/// un processus est achevé s'il est **sans fenêtre** et **muet à trois sondes
/// consécutives** espacées d'au moins `probeInterval` — soit une quinzaine de
/// secondes de silence complet. Un client occupé qui charge une carte a une
/// fenêtre ; un dormant sain répond en quelques millisecondes.
///
/// Le veilleur ne sonde rien lui-même : **la sonde, c'est l'inventaire.**
/// `WindowManager.refresh` interroge déjà `kAXWindows` sur chaque client, et
/// c'est lui qui constate le mutisme (`.cannotComplete`). Sonder une seconde
/// fois le même pid paierait deux fois l'expiration toutes les 2 s pendant
/// quinze secondes. L'inventaire consulte donc `suspects` et
/// `shouldProbe(_:)` pour ne réinterroger un pid déjà pris en défaut qu'à
/// l'échéance — avec la borne ordinaire d'une seconde, pour qu'un vivant lent
/// puisse toujours se blanchir. Entre deux échéances, le perso reste affiché,
/// atténué, par la mémoire. Un condamné que le réglage interdit d'achever
/// n'est plus resondé qu'à `condemnedInterval` : il ne changera pas d'avis,
/// et chaque sonde est une seconde perdue.
@MainActor
final class FreezeWatcher: ObservableObject {
    static let shared = FreezeWatcher()

    /// Un client achevé — montré dans le Diagnostic : tuer un processus est le
    /// geste le plus lourd de l'app, il doit laisser une trace.
    struct Abattu: Identifiable {
        let date: Date
        let pid: pid_t
        let nom: String
        var id: String { "\(pid)-\(date.timeIntervalSince1970)" }
    }

    @Published private(set) var journal: [Abattu] = []

    /// Espacement minimal entre deux sondes d'un même processus.
    static let probeInterval: TimeInterval = 5
    /// Espacement des sondes d'un condamné qu'on n'achève pas.
    static let condemnedInterval: TimeInterval = 30
    /// Sondes muettes consécutives avant le coup de grâce.
    static let strikesRequired = 3

    private var strikes = FreezeStrikes(probeInterval: probeInterval,
                                        strikesRequired: strikesRequired,
                                        condemnedInterval: condemnedInterval)

    /// Fermetures probables : pids dont la fenêtre vient de quitter l'écran
    /// sans changement d'espace — un ⌘Q, un clic sur la croix. Pour eux, une
    /// seule sonde muette suffit (`requisFermeture`), le temps qu'on les
    /// soupçonne (`dureeFermeture`).
    private var fermetures: [pid_t: Date] = [:]
    private var veille = VeilleFermeture()
    private var dernierChangementEspace = Date.distantPast
    private var timer: Timer?

    /// Sondes muettes qui suffisent à achever une fermeture probable.
    static let requisFermeture = 1
    /// Au-delà, une fermeture probable qui n'a pas été tranchée redevient un
    /// silencieux ordinaire.
    static let dureeFermeture: TimeInterval = 5
    /// Cadence du guet de la disparition des fenêtres.
    static let intervalleGuet: TimeInterval = 0.5

    private init() {}

    /// Guette la disparition des fenêtres de jeu, deux fois par seconde.
    ///
    /// La règle d'abattage ordinaire — muet à trois sondes espacées de 5 s —
    /// laissait un client gelé à la fermeture une quinzaine de secondes à
    /// l'écran : c'est au joueur qui vient de le quitter qu'elle faisait
    /// attendre. Or une fermeture se voit : la fenêtre quitte l'écran alors
    /// que l'espace n'a pas changé. Le guet le lit au serveur de fenêtres
    /// (`CrossSpaceTitles.affiches`, sans Accessibilité, sans permission, un
    /// client gelé ne peut pas le bloquer), demande aussitôt un inventaire, et
    /// une seule sonde muette achève alors le processus — ~1,5 s après le ⌘Q.
    ///
    /// L'abattage exige toujours **sans fenêtre et muet** : une fenêtre
    /// réduite ou un client passé sur un autre espace répondent à la sonde et
    /// sont blanchis. La garde après un changement d'espace n'est qu'une
    /// économie de sondes.
    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { FreezeWatcher.shared.dernierChangementEspace = Date() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.intervalleGuet, repeats: true) { _ in
            MainActor.assumeIsolated { FreezeWatcher.shared.guetter() }
        }
        timer?.tolerance = 0.1
    }

    private func guetter() {
        let manager = WindowManager.shared
        let vivants = manager.liveDofusPIDs
        guard Preferences.shared.killFrozenClients, !vivants.isEmpty else {
            veille = VeilleFermeture()
            return
        }
        let disparus = veille.observer(affiches: CrossSpaceTitles.affiches(parmi: vivants),
                                       vivants: vivants,
                                       dernierChangementEspace: dernierChangementEspace,
                                       maintenant: Date())
            .subtracting(manager.closingPIDs)
        guard !disparus.isEmpty else { return }
        let now = Date()
        for pid in disparus { fermetures[pid] = now }
        manager.refreshSoon()
    }

    /// Processus déjà pris en défaut au moins une fois : l'inventaire ne les
    /// réinterroge qu'à l'échéance, et les gestes ne les questionnent plus.
    var suspects: Set<pid_t> { strikes.suspects }

    /// Une sonde de ce processus est-elle due ?
    func shouldProbe(_ pid: pid_t) -> Bool {
        // Une fermeture probable se sonde tout de suite, échéance ou non.
        fermetures[pid] != nil || strikes.shouldProbe(pid, now: Date())
    }

    /// À appeler après chaque inventaire, avec les processus vivants qui ne
    /// rendent aucune fenêtre, ceux d'entre eux que l'inventaire a trouvés
    /// muets, et un nom à mettre au journal le cas échéant.
    ///
    /// Les strikes sont comptés même quand `achever` est faux : ils ne coûtent
    /// rien et épargnent à l'inventaire la borne pleine sur un client gelé.
    /// Seul le coup de grâce dépend du réglage.
    func inspect(silentPIDs: Set<pid_t>, mutePIDs: Set<pid_t>, probedPIDs: Set<pid_t>,
                 names: [pid_t: String], achever: Bool) {
        let now = Date()
        strikes.prune(keeping: silentPIDs)
        fermetures = fermetures.filter {
            silentPIDs.contains($0.key) && now.timeIntervalSince($0.value) < Self.dureeFermeture
        }

        for pid in silentPIDs {
            let requis = fermetures[pid] == nil ? nil : Self.requisFermeture
            let verdict = strikes.record(pid, mute: mutePIDs.contains(pid),
                                         probed: probedPIDs.contains(pid), now: now, requis: requis)
            if verdict == .blanchi { fermetures[pid] = nil }
            guard case .condamne = verdict, achever else { continue }

            ClientTerminator.kill(pid)
            journal.append(Abattu(date: now, pid: pid, nom: names[pid] ?? "pid \(pid)"))
            strikes.forget(pid)
            fermetures[pid] = nil
        }
    }
}

/// La règle d'abattage, pure : on la nourrit du résultat de chaque inventaire
/// et elle rend un verdict, sans rien lire elle-même — donc testable sans
/// client ni Accessibilité.
struct FreezeStrikes: Equatable {
    enum Verdict: Equatable {
        /// Pas sondé ce tour-ci : rien ne change.
        case ignore
        /// A répondu : l'ardoise est effacée.
        case blanchi
        /// Muet, mais pas encore assez de fois.
        case frappe(Int)
        /// Muet à `strikesRequired` sondes consécutives.
        case condamne
    }

    let probeInterval: TimeInterval
    let strikesRequired: Int
    /// Espacement des sondes une fois le pid condamné : sans coup de grâce, il
    /// resterait sondé — et muet — toutes les `probeInterval` jusqu'à sa mort.
    let condemnedInterval: TimeInterval

    private(set) var strikes: [pid_t: Int] = [:]
    private(set) var lastProbe: [pid_t: Date] = [:]

    init(probeInterval: TimeInterval, strikesRequired: Int,
         condemnedInterval: TimeInterval? = nil) {
        self.probeInterval = probeInterval
        self.strikesRequired = strikesRequired
        self.condemnedInterval = condemnedInterval ?? probeInterval
    }

    var suspects: Set<pid_t> {
        Set(strikes.filter { $0.value > 0 }.keys)
    }

    /// Une sonde est due si le pid n'a jamais été sondé ou si `probeInterval`
    /// s'est écoulé depuis la dernière.
    func shouldProbe(_ pid: pid_t, now: Date) -> Bool {
        guard let derniere = lastProbe[pid] else { return true }
        let interval = strikes[pid, default: 0] >= strikesRequired ? condemnedInterval : probeInterval
        return now.timeIntervalSince(derniere) >= interval
    }

    /// Un processus redevenu bavard ou disparu repart de zéro.
    mutating func prune(keeping silentPIDs: Set<pid_t>) {
        strikes = strikes.filter { silentPIDs.contains($0.key) }
        lastProbe = lastProbe.filter { silentPIDs.contains($0.key) }
    }

    /// Consigne ce que l'inventaire a vu d'un processus silencieux.
    ///
    /// Un pid muet a forcément été sondé : le strike est compté. Un pid
    /// silencieux mais non muet n'est blanchi que s'il a **réellement** été
    /// sondé — `probed` est un fait rapporté par l'inventaire, pas déduit de
    /// l'échéance : entre le départ de l'inventaire et son retour, une
    /// échéance a pu passer, et un suspect sauté au départ serait sinon
    /// blanchi sur une réponse qui n'a jamais été demandée.
    /// `requis` remplace `strikesRequired` pour ce pid — une fermeture
    /// probable n'attend pas trois sondes.
    mutating func record(_ pid: pid_t, mute: Bool, probed: Bool, now: Date, requis: Int? = nil) -> Verdict {
        if mute {
            lastProbe[pid] = now
            let compte = strikes[pid, default: 0] + 1
            strikes[pid] = compte
            return compte >= (requis ?? strikesRequired) ? .condamne : .frappe(compte)
        }
        guard probed else { return .ignore }
        lastProbe[pid] = now
        strikes[pid] = nil
        return .blanchi
    }

    mutating func forget(_ pid: pid_t) {
        strikes[pid] = nil
        lastProbe[pid] = nil
    }
}

/// Le guet des fenêtres qui quittent l'écran, pur : on lui donne les pids qui
/// ont une fenêtre à l'écran à chaque tour, il rend ceux qui viennent de la
/// perdre — sauf juste après un changement d'espace, où toutes les fenêtres
/// d'un espace plein écran quittent l'écran d'un coup sans que personne ne
/// ferme rien.
struct VeilleFermeture: Equatable {
    private(set) var affiches: Set<pid_t> = []
    /// Après un changement d'espace, les disparitions ne disent rien.
    static let garde: TimeInterval = 1.5

    mutating func observer(affiches nouveaux: Set<pid_t>, vivants: Set<pid_t>,
                           dernierChangementEspace: Date, maintenant: Date) -> Set<pid_t> {
        defer { affiches = nouveaux }
        guard maintenant.timeIntervalSince(dernierChangementEspace) >= Self.garde else { return [] }
        return affiches.subtracting(nouveaux).intersection(vivants)
    }
}
