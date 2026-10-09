import Testing
@testable import Synfus

/// La comparaison tolérante commune à la chasse et au suivi de quêtes.
struct RessemblanceTests {
    @Test("La distance bornée rend la distance pleine tant qu'elle tient sous la borne")
    func distanceBornee() {
        var generateur = SystemRandomNumberGenerator()
        let lettres = Array("abcde ")
        func texte(_ longueur: Int) -> String {
            String((0..<longueur).map { _ in lettres.randomElement(using: &generateur)! })
        }
        for _ in 0..<500 {
            let motif = Ressemblance.Forme(texte(Int.random(in: 1...20, using: &generateur)))
            let lu = Ressemblance.Forme(texte(Int.random(in: 0...40, using: &generateur)))
            let pleine = Ressemblance.distanceDansTexte(motif, lu)
            for borne in 0...8 {
                #expect(Ressemblance.distanceDansTexte(motif, lu, auPlus: borne) == (pleine <= borne ? pleine : nil),
                        "\(motif.scalaires) dans \(lu.scalaires), borne \(borne)")
            }
        }
    }

    @Test("Calé au début, le motif ne se cherche pas au milieu du texte")
    func auDebut() {
        var generateur = SystemRandomNumberGenerator()
        let lettres = Array("abcde ")
        func texte(_ longueur: Int) -> [Character] {
            (0..<longueur).map { _ in lettres.randomElement(using: &generateur)! }
        }
        /// Levenshtein du motif au meilleur début du texte, sans détour.
        func attendue(_ motif: [Character], _ lu: [Character]) -> Int {
            var ligne = Array(0...motif.count)
            var meilleur = ligne[motif.count]
            for (j, c) in lu.enumerated() {
                var suivante = [j + 1]
                for i in 1...motif.count {
                    suivante.append(min(ligne[i - 1] + (motif[i - 1] == c ? 0 : 1), ligne[i] + 1, suivante[i - 1] + 1))
                }
                ligne = suivante
                meilleur = min(meilleur, ligne[motif.count])
            }
            return meilleur
        }
        for _ in 0..<500 {
            let motif = texte(Int.random(in: 1...15, using: &generateur))
            let lu = texte(Int.random(in: 0...30, using: &generateur))
            let pleine = attendue(motif, lu)
            for borne in 0...8 {
                #expect(Ressemblance.distanceAuDebut(.init(String(motif)), .init(String(lu)), auPlus: borne)
                        == (pleine <= borne ? pleine : nil), "\(String(motif)) au début de \(String(lu)), borne \(borne)")
            }
        }
        let charge = Ressemblance.Forme("charge")
        #expect(Ressemblance.distanceDansTexte(charge, .init("de rechange"), auPlus: 1) == 1)
        #expect(Ressemblance.distanceAuDebut(charge, .init("de rechange"), auPlus: 1) == nil)
        #expect(Ressemblance.distanceAuDebut(charge, .init("charge 8"), auPlus: 1) == 0)
    }

    @Test("La borne basse n'écarte jamais un motif qui tient sous la tolérance")
    func borneBasse() {
        var generateur = SystemRandomNumberGenerator()
        let lettres = Array("abcdef 12")
        func texte(_ longueur: Int) -> String {
            String((0..<longueur).map { _ in lettres.randomElement(using: &generateur)! })
        }
        var ecartes = 0
        for _ in 0..<2000 {
            let motif = Ressemblance.Forme(texte(Int.random(in: 1...20, using: &generateur)))
            let lu = Ressemblance.Forme(texte(Int.random(in: 0...40, using: &generateur)))
            let distance = Ressemblance.distanceDansTexte(motif, lu)
            for tolerance in 0...6 where motif.tropLoin(de: lu, tolerance: tolerance) {
                ecartes += 1
                #expect(distance > tolerance, "\(motif.scalaires) dans \(lu.scalaires), tolérance \(tolerance)")
            }
        }
        #expect(ecartes > 0)
    }

    @Test("Un objectif se trouve dans la ligne malgré une faute, pas au-delà de la borne")
    func objectif() {
        let motif = Ressemblance.Forme(Ressemblance.normaliser("Rapporter 1 âme de Shin Larve"))
        let lu = Ressemblance.Forme(Ressemblance.normaliser("• Rapporter 1 ame de Shin Larvc à"))
        #expect(Ressemblance.distanceDansTexte(motif, lu, auPlus: 2) == 1)
        #expect(Ressemblance.distanceDansTexte(motif, lu, auPlus: 0) == nil)
    }
}
