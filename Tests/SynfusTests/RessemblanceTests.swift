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

    @Test("Un objectif se trouve dans la ligne malgré une faute, pas au-delà de la borne")
    func objectif() {
        let motif = Ressemblance.Forme(Ressemblance.normaliser("Rapporter 1 âme de Shin Larve"))
        let lu = Ressemblance.Forme(Ressemblance.normaliser("• Rapporter 1 ame de Shin Larvc à"))
        #expect(Ressemblance.distanceDansTexte(motif, lu, auPlus: 2) == 1)
        #expect(Ressemblance.distanceDansTexte(motif, lu, auPlus: 0) == nil)
    }
}
