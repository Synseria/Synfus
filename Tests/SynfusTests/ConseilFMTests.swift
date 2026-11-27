import Testing
@testable import Synfus

@Suite("Runes conseillées")
struct ConseilFMTests {
    private let catalogue = ForgemagieTests.catalogue

    private func conseils(_ lignes: [ObjetFM.Ligne], cibles: [Int: Int] = [:], reliquat: Double? = 0) -> [ConseilFM.Proposition] {
        ConseilFM.propositions(objet: ObjetFM(lignes: lignes), cible: { cibles[$0.effet] ?? $0.max ?? $0.valeur },
                               reliquat: reliquat, catalogue: catalogue)
    }

    @Test("Le palier suit la valeur de la ligne : simple sous 20 de poids, Pa sous 60, Ra au-delà")
    func palier() throws {
        let fo = try #require(catalogue.runes[118])
        #expect(ConseilFM.palierAttendu(valeur: 10, poidsParPoint: 1, runes: fo) == 0)
        #expect(ConseilFM.palierAttendu(valeur: 45, poidsParPoint: 1, runes: fo) == 1)
        #expect(ConseilFM.palierAttendu(valeur: 70, poidsParPoint: 1, runes: fo) == 2)
        // Vitalité : 0,2 par point — Pa dès 100.
        #expect(ConseilFM.palierAttendu(valeur: 224, poidsParPoint: 0.2, runes: try #require(catalogue.runes[125])) == 1)
    }

    @Test("Loin du max, la petite rune ; tout près, celle qui comble l'écart sans le dépasser")
    func taille() {
        #expect(conseils([.init(effet: 118, valeur: 10, max: 60)]).first?.rune.nom == "Rune Fo")
        #expect(conseils([.init(effet: 118, valeur: 50, max: 60)]).first?.rune.nom == "Rune Ra Fo")
        #expect(conseils([.init(effet: 118, valeur: 57, max: 60)]).first?.rune.nom == "Rune Pa Fo")
        #expect(conseils([.init(effet: 125, valeur: 224, max: 250)]).first?.rune.nom == "Rune Pa Vi")
    }

    @Test("Rien à conseiller à la cible ; une cible voulue au-dessus du max, jusqu'au plafond")
    func cibles() {
        #expect(conseils([.init(effet: 118, valeur: 60, max: 60)]).isEmpty)
        #expect(conseils([.init(effet: 118, valeur: 55, max: 60)], cibles: [118: 50]).isEmpty)
        // 155 Force pour 60 : 95 d'over ; une Ra passerait le plafond de 101, pas une simple.
        let over = conseils([.init(effet: 118, valeur: 155, max: 60)], cibles: [118: 170])
        #expect(!over.isEmpty && !over.contains { $0.rune.nom == "Rune Ra Fo" })
    }

    @Test("Le score dit ses raisons ; le reliquat couvre la perte probable")
    func raisons() throws {
        let premiere = try #require(conseils([.init(effet: 118, valeur: 50, max: 60)], reliquat: 30).first)
        #expect(premiere.apres == 60)
        #expect(premiere.raisons.contains(.comble(points: 10, manque: 10)))
        #expect(premiere.raisons.contains(.procheDuMax))
        #expect(premiere.raisons.contains(.reliquatCouvre))
        #expect((0...100).contains(premiere.score))
        // Une proposition par ligne, triées, la meilleure d'abord.
        let toutes = conseils([.init(effet: 118, valeur: 30, max: 60), .init(effet: 125, valeur: 100, max: 250)])
        #expect(toutes.map(\.score) == toutes.map(\.score).sorted(by: >))
        #expect(Set(toutes.map(\.rune.effet)).count == toutes.count)
    }
}
