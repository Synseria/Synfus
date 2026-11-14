import Foundation

/// Les donjons de DofusDB : la liste et le nom des boss une fois par lancement,
/// à la première ouverture de la palette ou à la première zone lue par
/// l'aide aux boss (quelques pages) ; le détail d'un
/// donjon et ses conseils (Dofus pour les noobs) à l'ouverture de sa fiche.
/// Rien sur le disque : quelques requêtes, et la fiche se passe de réseau
/// pour copier le trajet.
@MainActor
final class DonjonsStore: ObservableObject {
    static let shared = DonjonsStore()

    @Published private(set) var donjons: Donjons?
    @Published private(set) var details: [Int: DetailDonjon] = [:]
    @Published private(set) var echecs: Set<Int> = []
    /// Par donjon ; vide quand sa page n'a pas de conseils tactiques.
    @Published private(set) var conseils: [Int: [ConseilCombat]] = [:]
    /// La liste est en route : l'en-tête du panneau des boss le montre.
    @Published private(set) var enCours = false
    private var chargement: Task<Void, Never>?
    /// Après un échec, la liste attend avant de se redemander : chaque
    /// position lue l'appelle, sans réseau on rechargerait à chaque lecture.
    private var dernierEchec: Date?
    static let attenteApresEchec: TimeInterval = 5 * 60
    private var demandes: Set<Int> = []
    private var conseilsDemandes: Set<Int> = []

    private init() {}

    /// Une fois ; un échec réessaie à un appel suivant, `attenteApresEchec` passée.
    func charger(maintenant: Date = Date()) {
        guard donjons == nil, chargement == nil else { return }
        if let dernierEchec, maintenant.timeIntervalSince(dernierEchec) < Self.attenteApresEchec { return }
        enCours = true
        chargement = Task {
            defer {
                chargement = nil
                enCours = false
            }
            guard let liste = try? await Self.telecharger() else {
                dernierEchec = Date()
                return
            }
            donjons = liste
        }
    }

    func demander(_ donjon: Donjon) {
        demanderConseils(donjon)
        guard details[donjon.id] == nil, demandes.insert(donjon.id).inserted else { return }
        echecs.remove(donjon.id)
        Task {
            defer { demandes.remove(donjon.id) }
            do {
                details[donjon.id] = try await Self.detail(donjon)
            } catch {
                echecs.insert(donjon.id)
            }
        }
    }

    /// Une page d'environ 200 Ko, lue hors du fil principal ; sans réseau,
    /// redemandée à la prochaine ouverture.
    private func demanderConseils(_ donjon: Donjon) {
        guard let nom = donjon.nomFrancais, conseils[donjon.id] == nil, conseilsDemandes.insert(donjon.id).inserted
        else { return }
        Task {
            defer { conseilsDemandes.remove(donjon.id) }
            guard let html = await DofusPourLesNoobs.html(nom) else { return }
            conseils[donjon.id] = await Task.detached(priority: .utility) { ConseilCombat.extraire(html) }.value
        }
    }

    // MARK: - Réseau

    private struct Nomme: Decodable, Sendable {
        let id: Int
        let name: DofusDB.Noms
    }

    private struct SuccesAPI: Decodable, Sendable {
        let id: Int
        let name: DofusDB.Noms
        let description: DofusDB.Noms?
    }

    private nonisolated static func telecharger() async throws -> Donjons {
        let api: [Donjon.API] = try await DofusDB.toutes("dungeons", DofusDB.selection(Donjon.API.champs))
        let liste = api.map(Donjon.init)
        let boss: [Nomme] = try await DofusDB.parIdentifiants("monsters", liste.flatMap(\.boss),
                                                              DofusDB.selection(["id", "name"]))
        return Donjons(liste, nomsBoss: Dictionary(boss.map { ($0.id, $0.name.parLangue) },
                                                   uniquingKeysWith: { premier, _ in premier }))
    }

    private nonisolated static func detail(_ donjon: Donjon) async throws -> DetailDonjon {
        async let monstres: [FicheCombat.MonstreAPI] = DofusDB.parIdentifiants(
            "monsters", donjon.monstres + donjon.boss, DofusDB.selection(FicheCombat.MonstreAPI.champs))
        async let objets: [Nomme] = DofusDB.parIdentifiants("items", donjon.clefs.map(\.objet),
                                                            DofusDB.selection(["id", "name"]))
        async let succes: [SuccesAPI] = DofusDB.parIdentifiants("achievements", donjon.succes,
                                                                DofusDB.selection(["id", "name", "description"]))
        let ordre = Dictionary(donjon.succes.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let nommes = try await succes.sorted { (ordre[$0.id] ?? .max) < (ordre[$1.id] ?? .max) }
            .map { DetailDonjon.Succes(noms: $0.name.parLangue, description: $0.description?.parLangue ?? [:]) }
        return DetailDonjon.assembler(
            donjon, monstres: try await monstres,
            objets: Dictionary(try await objets.map { ($0.id, $0.name.parLangue) }, uniquingKeysWith: { a, _ in a }),
            succes: nommes)
    }
}
