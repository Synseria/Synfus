import CoreGraphics
import Foundation
import Testing
@testable import Synfus

@Suite("Atelier de forgemagie lu")
struct AtelierFMTests {
    private let catalogue = ForgemagieTests.catalogue

    private func lu(_ textes: [DetectionZones.TexteVu]) throws -> AtelierFM {
        try #require(AtelierFM.lire(textes, catalogue: catalogue))
    }

    private func ligne(_ atelier: AtelierFM, _ effet: Int) -> ObjetFM.Ligne? { atelier.objet.ligne(effet) }

    @Test("La table qui défile : chaque ligne vue, son jet max à côté")
    func tableQuiDefile() throws {
        let atelier = try lu(FixturesAtelierFM.tableQuiDefile)
        #expect(atelier.reliquat == 0)
        #expect(ligne(atelier, 125) == .init(effet: 125, valeur: 224, max: 150))
        #expect(ligne(atelier, 126) == .init(effet: 126, valeur: 57, max: 60))
        // « 3 46 Sagesse » : l'icône lue « 3 ».
        #expect(ligne(atelier, 124) == .init(effet: 124, valeur: 46, max: 50))
        // « - 7% Critique » : l'icône lue « - ».
        #expect(ligne(atelier, 115) == .init(effet: 115, valeur: 7, max: 7))
        #expect(ligne(atelier, 174) == .init(effet: 174, valeur: 499, max: 500))
        #expect(ligne(atelier, 210) == .init(effet: 210, valeur: 8, max: 8))
        #expect(ligne(atelier, 241) == .init(effet: 241, valeur: 12, max: 12))
        // Son max mal lu n'en fait pas une exo.
        #expect(ligne(atelier, 178) == .init(effet: 178, valeur: 4, max: nil, exo: false))
        #expect(atelier.objet.lignes.count == 14)
        // L'historique, la plus récente en bas.
        #expect(atelier.historique.last == .reliquat(gagne: false))
        #expect(atelier.historique.contains(.ligne(points: -18, nom: "Initiative", pourcent: false)))
    }

    @Test("Une exo n'a ni min ni max")
    func exo() throws {
        let atelier = try lu(FixturesAtelierFM.exoDommagesAuxSorts)
        #expect(ligne(atelier, 125) == .init(effet: 125, valeur: 341, max: 350))
        #expect(ligne(atelier, 2812) == .init(effet: 2812, valeur: 1, max: nil, exo: true))
        #expect(atelier.inconnues.isEmpty)
    }

    @Test("« Маx » en lettres cyrilliques, le reliquat à une décimale")
    func maxCyrillique() throws {
        let atelier = try lu(FixturesAtelierFM.apresTroisRunes)
        #expect(atelier.reliquat == 0.1)
        #expect(ligne(atelier, 125) == .init(effet: 125, valeur: 34, max: 45))
        #expect(ligne(atelier, 174) == .init(effet: 174, valeur: 49, max: 200))
        #expect(ligne(atelier, 158) == .init(effet: 158, valeur: 237, max: 200))
        #expect(atelier.objet.lignes.count == 3)
    }

    @Test("Les cases des runes : la colonne de chaque rang, la rangée de chaque ligne")
    func casesDesRunes() throws {
        let atelier = try lu(FixturesAtelierFM.apresTroisRunes)
        let runes = try #require(atelier.runes)
        // Au milieu des stocks lus : 550, 192, 169 dans la rangée de la Vitalité.
        let pa = try #require(runes.centre(effet: 125, rang: .pa))
        let simple = try #require(runes.centre(effet: 125, rang: .simple))
        let ra = try #require(runes.centre(effet: 158, rang: .ra))
        #expect(abs(pa.x - 0.878) < 0.004)
        #expect(abs(pa.y - 0.2511) < 0.004)
        #expect(abs(simple.x - 0.8331) < 0.004)
        #expect(abs(ra.x - 0.9244) < 0.004)
        #expect(abs(ra.y - 0.3623) < 0.004)
        #expect(runes.centre(effet: 999, rang: .simple) == nil)
    }

    @Test("L'écran entier : suivi de quêtes et infobulle n'entrent pas dans l'atelier")
    func ecranEntier() throws {
        let atelier = try lu(FixturesAtelierFM.ecranEntier)
        #expect(atelier.objet.lignes.map(\.effet) == [125, 158, 174])
        #expect(ligne(atelier, 174) == .init(effet: 174, valeur: 208, max: 200))
        // « 9 190 Pods » : l'icône lue « 9 ».
        #expect(ligne(atelier, 158) == .init(effet: 158, valeur: 190, max: 200))
        #expect(atelier.inconnues.isEmpty)
        #expect(atelier.historique.first == .ligne(points: 9, nom: "Initiative", pourcent: false))
        #expect(atelier.historique.last == .reliquat(gagne: true))
        // Le cadre couvre l'atelier, pas le suivi de quêtes à gauche ni l'inventaire à droite.
        #expect(atelier.cadre.minX > 0.12 && atelier.cadre.maxX < 0.62)
    }

    @Test("Une séance : chaque fusion comptée, sur des lectures confirmées ; un autre objet repart de zéro")
    func seance() {
        func atelier(_ lignes: [ObjetFM.Ligne], _ reliquat: Double = 0) -> AtelierFM {
            AtelierFM(objet: ObjetFM(lignes: lignes), inconnues: [], reliquat: reliquat, historique: [], cadre: .zero)
        }
        var suivi = SuiviFM()
        /// Deux lectures identiques de suite : une lecture sûre.
        func deuxFois(_ a: AtelierFM) -> FusionFM? {
            suivi.lu(a, catalogue: catalogue)
            return suivi.lu(a, catalogue: catalogue)
        }
        #expect(deuxFois(atelier([.init(effet: 174, valeur: 39, max: 200), .init(effet: 158, valeur: 255, max: 200)])) == nil)
        // Une lecture isolée (animation, chiffre mal lu) ne compte pas.
        suivi.lu(atelier([.init(effet: 174, valeur: 99, max: 200), .init(effet: 158, valeur: 255, max: 200)]), catalogue: catalogue)
        #expect(suivi.comptes.isEmpty)
        let sn = deuxFois(atelier([.init(effet: 174, valeur: 49, max: 200), .init(effet: 158, valeur: 251, max: 200)]))
        #expect(sn?.issue == .succesNeutre)
        deuxFois(atelier([.init(effet: 174, valeur: 59, max: 200), .init(effet: 158, valeur: 251, max: 200)]))
        #expect(suivi.comptes == [.succesNeutre: 1, .succesCritique: 1])
        // Rien de changé : pas de fusion.
        deuxFois(atelier([.init(effet: 174, valeur: 59, max: 200), .init(effet: 158, valeur: 251, max: 200)]))
        #expect(suivi.comptes.values.reduce(0, +) == 2)
        // Deux runes entre deux lectures (+40 Initiative) : pas une fusion qu'on sache lire.
        deuxFois(atelier([.init(effet: 174, valeur: 99, max: 200), .init(effet: 158, valeur: 251, max: 200)]))
        #expect(suivi.comptes.values.reduce(0, +) == 2)
        // Le max mal lu d'une ligne reste connu : pas une exo.
        deuxFois(atelier([.init(effet: 174, valeur: 59, max: nil, exo: true), .init(effet: 158, valeur: 251, max: 200)]))
        #expect(suivi.atelier?.objet.ligne(174) == .init(effet: 174, valeur: 59, max: 200))
        // Un autre objet : un jet max différent.
        deuxFois(atelier([.init(effet: 174, valeur: 400, max: 500)]))
        #expect(suivi.comptes.isEmpty && suivi.derniere == nil)
    }

    @Test("La lecture bornée au cadre de l'atelier garde son historique")
    func lectureBornee() throws {
        let premiere = try lu(FixturesAtelierFM.apresTroisRunes)
        let zone = ForgemagieModele.autour(premiere.cadre)
        // Ce que la capture de la zone aurait montré : les textes dedans, en fractions de la zone.
        let r = zone.rect
        let dedans = FixturesAtelierFM.apresTroisRunes.filter { r.contains($0.cadre) }.map {
            DetectionZones.TexteVu(texte: $0.texte, cadre: CGRect(x: ($0.cadre.minX - r.minX) / r.width, y: ($0.cadre.minY - r.minY) / r.height,
                                                                width: $0.cadre.width / r.width, height: $0.cadre.height / r.height))
        }
        let seconde = try lu(ForgemagieModele.dansLeContenu(dedans, region: zone))
        #expect(seconde.objet == premiere.objet)
        #expect(seconde.historique == premiere.historique)
        #expect(!seconde.historique.isEmpty)
    }

    @Test("La région suivante entoure l'atelier lu, bornée au contenu")
    func region() {
        let zone = ForgemagieModele.autour(CGRect(x: 0.02, y: 0.3, width: 0.5, height: 0.6))
        #expect(zone.x == 0 && abs(zone.y - 0.22) < 1e-9 && abs(zone.largeur - 0.6) < 1e-9 && abs(zone.hauteur - 0.76) < 1e-9)
    }

    @Test("Sans en-tête de table, pas d'atelier")
    func absent() {
        #expect(AtelierFM.lire([DetectionZones.TexteVu(texte: "Inventaire", cadre: CGRect(x: 0.5, y: 0.1, width: 0.1, height: 0.02))],
                               catalogue: catalogue) == nil)
    }
}

@Suite("Lecture sûre après un clic dans l'atelier")
struct AttenteClicTests {
    private func atelier(_ valeur: Int) -> AtelierFM {
        AtelierFM(objet: ObjetFM(lignes: [.init(effet: 125, valeur: valeur, max: 45)]), inconnues: [], reliquat: 0,
                  historique: [], cadre: .zero)
    }

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func lire(_ attente: inout SuiviFM.AttenteClic, _ lu: AtelierFM?, a date: Date) -> Bool {
        attente.lu(lu, a: date)
    }

    @Test("Une fusion : la valeur change, sûre à la deuxième lecture identique")
    func fusion() {
        var attente = SuiviFM.AttenteClic(le: t0, avant: atelier(34))
        // Le jeu n'a pas encore montré la fusion.
        #expect(!lire(&attente, atelier(34), a: t0.addingTimeInterval(0.25)))
        #expect(!lire(&attente, atelier(39), a: t0.addingTimeInterval(0.6)))
        #expect(lire(&attente, atelier(39), a: t0.addingTimeInterval(0.95)))
    }

    @Test("Un clic qui ne fusionne rien : sûre une fois la lecture stable assez longtemps")
    func rienFusionne() {
        var attente = SuiviFM.AttenteClic(le: t0, avant: atelier(34))
        #expect(!lire(&attente, atelier(34), a: t0.addingTimeInterval(0.25)))
        #expect(!lire(&attente, atelier(34), a: t0.addingTimeInterval(0.6)))
        #expect(lire(&attente, atelier(34), a: t0.addingTimeInterval(1.5)))
    }

    @Test("Rien de lu : on cesse d'attendre au bout du délai")
    func delai() {
        var attente = SuiviFM.AttenteClic(le: t0, avant: nil)
        #expect(!lire(&attente, nil, a: t0.addingTimeInterval(1)))
        #expect(lire(&attente, nil, a: t0.addingTimeInterval(4.5)))
    }
}
