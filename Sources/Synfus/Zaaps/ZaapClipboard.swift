import AppKit
import Combine

/// Le seul foyer des trajets copiés : passer un `/travel` copié par le zaap de
/// sa cible (au raccourci, au bouton de la barre, ou de lui-même
/// à chaque copie, `zaapAuto`), copier le trajet vers une case ou un `/zaap`.
/// La décision et les commandes sont dans `ItineraireZaap` ; ici, le
/// presse-papiers et le retour visuel.
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

    /// Change avec tout réglage et toute carte : ce qu'on tire des trajets se
    /// garde sous cette révision — l'index des zaaps, la dernière tournée, les
    /// repaires situés (`OuTrouverStore`).
    private(set) var revisionTrajets = 0
    private var zaapsSituesGardes = DernierCalcul<Int, ZaapsSitues>()
    /// Le panneau des quêtes la redemande à chaque rendu : jusqu'à 5 040 ordres essayés.
    private var tourneeGardee = DernierCalcul<[Int], [Int]>()

    private init() {
        // `objectWillChange` part avant l'affectation : ce qui se rebâtit à la
        // lecture suivante voit toujours la nouvelle valeur.
        Preferences.shared.objectWillChange.merge(with: CarteStore.shared.objectWillChange)
            .sink { [weak self] in MainActor.assumeIsolated { self?.revisionTrajets &+= 1 } }
            .store(in: &subscriptions)
    }

    /// Les zaaps actifs sur le réseau des sous-zones : ce que lisent la
    /// réécriture, les coûts et la palette, indexé une fois par liste et par carte.
    var zaapsSitues: ZaapsSitues {
        zaapsSituesGardes.valeur(pour: revisionTrajets) {
            ZaapsSitues(Preferences.shared.zaapsActifs, reseau: CarteStore.shared.reseau)
        }
    }

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

    /// Copie `/travel x,y`, précédé du zaap qui fait gagner assez de cartes
    /// depuis le perso devant — le même calcul que pour un `/travel` copié.
    /// Hors du Monde des Douze, le `/travel` seul : ses coordonnées recoupent
    /// celles d'Amakna, un zaap d'Amakna y mènerait à tort. Chaque appelant
    /// dit où est la case : un oubli copierait ce zaap-là.
    func copierTrajet(vers cible: (x: Int, y: Int), dansLesDouze: Bool) {
        let travel = ItineraireZaap.travel(vers: cible)
        guard dansLesDouze, let nouveau = itineraire(travel) else { return poser(travel) }
        poser(nouveau)
        signaler()
    }

    /// Les cartes à traverser jusqu'à une case depuis la position du perso
    /// (`positionDuPersoDevant`), zaap compris s'il vaut le coup — ce que
    /// coûterait `copierTrajet` —, les réglages lus une fois pour toutes les
    /// cases. `nil` : position inconnue, ou hors du Monde des Douze.
    func cout(depuis perso: PositionCarte?) -> ((_ cible: (x: Int, y: Int)) -> Int)? {
        guard let depart = ItineraireZaap.rejoindre(perso) else { return nil }
        let couts = Couts()
        return { couts.depuis(depart, vers: $0) }
    }

    /// L'ordre le plus court pour passer par toutes ces cases depuis le perso
    /// devant, zaaps compris — le calcul même de `copierTrajet`, trajet par
    /// trajet (`Tournee`). `nil` : position inconnue, ou hors du Monde des Douze.
    func tournee(_ cases: [(id: Int, x: Int, y: Int)]) -> [Int]? {
        guard let depart = ItineraireZaap.rejoindre(LecteurEcran.shared.positionDuPersoDevant) else { return nil }
        let cle = [revisionTrajets, depart.x, depart.y] + cases.flatMap { [$0.id, $0.x, $0.y] }
        return tourneeGardee.valeur(pour: cle) {
            let couts = Couts()
            let parId = Dictionary(cases.map { ($0.id, (x: $0.x, y: $0.y)) }, uniquingKeysWith: { a, _ in a })
            let zaapDe = parId.mapValues(couts.zaap)
            func cout(_ depuis: (x: Int, y: Int), _ vers: Int) -> Int {
                couts.depuis(depuis, vers: parId[vers]!, zaap: zaapDe[vers] ?? nil)
            }
            return Tournee.ordre(cases.map(\.id), depuisLeDepart: { cout(depart, $0) }, entre: { cout(parId[$0]!, $1) })
        }
    }

    /// Le coût d'un trajet selon les réglages du moment, lus une fois (sur
    /// main) ; le calcul, pur, se fait de n'importe où.
    @MainActor
    private struct Couts {
        let zaaps = ZaapClipboard.shared.zaapsSitues
        let zaapDuJeu = Preferences.shared.zaapDuJeu
        let gainMinimal = Preferences.shared.zaapGainMinimal

        nonisolated func zaap(_ cible: (x: Int, y: Int)) -> Zaap? {
            ItineraireZaap.zaap(vers: cible, parmi: zaaps, zaapDuJeu: zaapDuJeu)
        }

        nonisolated func depuis(_ depart: (x: Int, y: Int), vers cible: (x: Int, y: Int)) -> Int {
            depuis(depart, vers: cible, zaap: zaap(cible))
        }

        nonisolated func depuis(_ depart: (x: Int, y: Int), vers cible: (x: Int, y: Int), zaap: Zaap?) -> Int {
            ItineraireZaap.cartes(depuis: depart, vers: cible, zaap: zaap, gainMinimal: gainMinimal)
        }
    }

    func copierZaap(_ zaap: Zaap) {
        poser(ItineraireZaap.zaap(zaap))
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
        guard let texte = PressePapiers.lire(), let nouveau = itineraire(texte) else { return false }
        poser(nouveau)
        signaler()
        return true
    }

    private func itineraire(_ texte: String) -> String? {
        let prefs = Preferences.shared
        return ItineraireZaap.reecrire(texte, depuis: LecteurEcran.shared.positionDuPersoDevant,
                                       gainMinimal: prefs.zaapGainMinimal, zaaps: zaapsSitues,
                                       zaapDuJeu: prefs.zaapDuJeu, intercalees: prefs.commandesIntercalees)
    }

    /// Notre propre copie n'est pas une nouvelle copie à examiner.
    private func poser(_ texte: String) {
        PressePapiers.copier(texte)
        generationVue = PressePapiers.generation
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
