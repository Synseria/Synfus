import Testing
@testable import Synfus

/// Les objectifs faits et à venir d'une étape, repliés sous une ligne qui les compte.
struct RepliObjectifsTests {
    @Test("Faits et à venir repliés, le reste montré dans l'ordre")
    func replies() {
        let repli = RepliObjectifs.replier([1, 2, 3, 4, 5], faits: [1, 2], aVenir: [5], montrerFaits: false, montrerAVenir: false)
        #expect(repli == .init(faits: [1, 2], aVenir: [5], montres: [3, 4]))
    }

    @Test("Un groupe déplié montre ses objectifs à leur place ; un objectif fait n'est jamais à venir")
    func deplies() {
        let repli = RepliObjectifs.replier([1, 2, 3], faits: [1, 3], aVenir: [3], montrerFaits: true, montrerAVenir: false)
        #expect(repli == .init(faits: [1, 3], aVenir: [], montres: [1, 2, 3]))
    }

    @Test("Sans lecture du suivi, rien n'est à venir")
    func sansLecture() {
        let repli = RepliObjectifs.replier([1, 2], faits: [], aVenir: [], montrerFaits: false, montrerAVenir: false)
        #expect(repli.montres == [1, 2])
    }
}
