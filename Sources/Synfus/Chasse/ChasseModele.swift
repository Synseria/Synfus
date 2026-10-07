import Foundation

/// L'état du panneau de chasse : départ, direction, indice, résultat. Synfus
/// ne fait que lire l'écran et copier le trajet trouvé — le joueur colle,
/// marche et valide l'étape lui-même.
@MainActor
final class ChasseModele: ObservableObject {
    static let shared = ChasseModele()

    /// Une étape cherchée et ce qu'elle a donné, pour l'affichage : la
    /// recherche suivante remet direction et indice à zéro.
    struct Constat: Equatable {
        let cible: EtapeChasse.Cible
        let direction: Direction
        let resultat: EtapeChasse.Resultat
    }

    @Published var departX = 0
    @Published var departY = 0
    @Published private(set) var direction: Direction?
    @Published private(set) var cible: EtapeChasse.Cible?
    /// Le champ de l'indice ; il ne propose rien tant qu'il nomme la cible.
    @Published var saisie = ""
    /// Les cibles proposées par la dernière lecture de l'écran.
    @Published private(set) var lues: [EtapeChasse.Cible] = []
    @Published private(set) var lectureEnCours = false
    /// La dernière lecture n'a rien reconnu.
    @Published private(set) var rienLu = false
    @Published private(set) var constat: Constat?
    @Published private(set) var rechercheEnCours = false
    @Published private(set) var echec: String?

    @Published private(set) var indices: [Indice] = []
    @Published private(set) var dateIndices: Date?
    @Published private(set) var chargementIndices = false
    @Published private(set) var echecIndices: String?

    private var recherche: Task<Void, Never>?

    private init() {}

    var langue: Langue { L10n.courante.langue }

    var suggestions: [EtapeChasse.Cible] {
        guard cible?.nom(en: langue) != saisie else { return [] }
        if EtapeChasse.estPhorreur(saisie) { return [.phorreur] }
        return IndicesChasse.rechercher(saisie, parmi: indices, langue: langue, limite: 6).map(EtapeChasse.Cible.indice)
    }

    // MARK: - Ouverture

    /// À l'ouverture du panneau : le départ là où se tient le perso devant,
    /// la liste des indices, et la lecture de l'écran.
    func ouvrir() {
        reprendrePosition()
        Task {
            if indices.isEmpty { await chargerIndices() }
            lire()
        }
    }

    func reprendrePosition() {
        guard let position = LecteurEcran.shared.positionDuPersoDevant else { return }
        departX = position.x
        departY = position.y
    }

    /// `forcer` : le bouton des réglages, qui veut une liste neuve et la
    /// raison d'un échec.
    func chargerIndices(forcer: Bool = false) async {
        guard !chargementIndices else { return }
        chargementIndices = true
        echecIndices = nil
        do {
            let releve = try await ChasseDofusDB.indices(forcer: forcer)
            indices = releve.indices
            dateIndices = releve.date
        } catch {
            echecIndices = error.localizedDescription
        }
        chargementIndices = false
    }

    // MARK: - Lecture de l'écran

    func lire() {
        guard !lectureEnCours, !indices.isEmpty else { return }
        lectureEnCours = true
        Task {
            let lignes = await LecteurEcran.shared.lireUneFois(.chasse) ?? []
            lues = EtapeChasse.ciblesLues(dans: lignes, parmi: indices)
            rienLu = lues.isEmpty
            lectureEnCours = false
            if let derniere = lues.last { choisir(derniere) }
        }
    }

    // MARK: - Étape

    func choisir(_ cible: EtapeChasse.Cible) {
        self.cible = cible
        saisie = cible.nom(en: langue)
        chercherSiPret()
    }

    func choisir(_ direction: Direction) {
        self.direction = direction
        chercherSiPret()
    }

    /// Entrée dans le champ : la première proposition.
    func validerSaisie() {
        if let premiere = suggestions.first { choisir(premiere) } else { chercherSiPret() }
    }

    private func chercherSiPret() {
        guard let cible, let direction, cible.nom(en: langue) == saisie else { return }
        recherche?.cancel()
        echec = nil
        guard case .indice(let indice) = cible else {
            conclure(Constat(cible: cible, direction: direction, resultat: .phorreur))
            return
        }
        let (x, y) = (departX, departY)
        rechercheEnCours = true
        recherche = Task {
            defer { rechercheEnCours = false }
            do {
                let cartes = try await ChasseDofusDB.cartes(depuis: x, y, direction: direction)
                guard !Task.isCancelled else { return }
                conclure(Constat(cible: cible, direction: direction,
                                 resultat: EtapeChasse.resultat(indice: indice.id, cartes: cartes)))
            } catch {
                guard !Task.isCancelled else { return }
                echec = error.localizedDescription
            }
        }
    }

    /// Une étape trouvée devient le départ de la suivante, et son trajet est
    /// copié par le seul foyer des trajets — zaap compris s'il fait gagner.
    private func conclure(_ constat: Constat) {
        self.constat = constat
        direction = nil
        cible = nil
        saisie = ""
        lues.removeAll { $0 == constat.cible }
        if case .trouve(let x, let y, _) = constat.resultat {
            departX = x
            departY = y
            copier()
        }
    }

    func copier() {
        guard case .trouve(let x, let y, _) = constat?.resultat else { return }
        ZaapClipboard.shared.copierTrajet(vers: (x, y))
    }
}
