import AppKit
import Combine

/// Passe un `/travel` copié par le zaap le plus proche de sa cible : au
/// raccourci, au bouton de la barre, ou de lui-même à chaque copie
/// (`zaapAuto`). La décision est dans `ItineraireZaap` ; ici, le presse-papiers
/// et le retour visuel.
@MainActor
final class ZaapClipboard: ObservableObject {
    static let shared = ZaapClipboard()

    /// Le bouton de la barre s'allume le temps de `dureeSignal` après une
    /// réécriture.
    @Published private(set) var reecritRecemment = false

    private var veille: Timer?
    /// La génération du presse-papiers déjà examinée — dont la nôtre, pour ne
    /// pas relire ce qu'on vient d'écrire.
    private var generationVue = 0
    private var effacement: Task<Void, Never>?
    private var subscriptions: Set<AnyCancellable> = []
    private static let dureeSignal: Duration = .seconds(1.2)
    private static let intervalleVeille: TimeInterval = 0.5

    private init() {}

    func start() {
        // Les valeurs émises, pas les propriétés : `@Published` publie avant
        // d'affecter. Sans position lue, la veille n'aurait rien à décider.
        Preferences.shared.$zaapAuto
            .combineLatest(Preferences.shared.$lirePosition)
            .map { $0 && $1 }
            .removeDuplicates()
            .sink { [weak self] actif in
                MainActor.assumeIsolated { actif ? self?.armer() : self?.desarmer() }
            }
            .store(in: &subscriptions)
    }

    /// Le raccourci et le bouton : un bip quand le presse-papiers reste tel quel.
    func optimiser() {
        if !reecrire() { NSSound.beep() }
    }

    private func armer() {
        guard veille == nil else { return }
        // Ce qui était copié avant l'activation n'est pas une nouvelle copie.
        generationVue = PressePapiers.generation
        veille = Timer.scheduledTimer(withTimeInterval: Self.intervalleVeille, repeats: true) { _ in
            MainActor.assumeIsolated { ZaapClipboard.shared.surveiller() }
        }
        veille?.tolerance = 0.2
    }

    private func desarmer() {
        veille?.invalidate()
        veille = nil
    }

    /// Le contenu n'est lu qu'à une nouvelle copie : la génération seule ne
    /// coûte rien.
    private func surveiller() {
        let generation = PressePapiers.generation
        guard generation != generationVue else { return }
        generationVue = generation
        reecrire()
    }

    @discardableResult
    private func reecrire() -> Bool {
        guard let texte = PressePapiers.lire(),
              let nouveau = ItineraireZaap.reecrire(
                  texte, depuis: LecteurEcran.shared.positionDuPersoDevant,
                  gainMinimal: Preferences.shared.zaapGainMinimal)
        else { return false }
        PressePapiers.copier(nouveau)
        generationVue = PressePapiers.generation
        signaler()
        return true
    }

    private func signaler() {
        effacement?.cancel()
        reecritRecemment = true
        effacement = Task {
            try? await Task.sleep(for: Self.dureeSignal)
            guard !Task.isCancelled else { return }
            reecritRecemment = false
        }
    }
}
