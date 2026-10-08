import Foundation

/// Les coches et l'objectif en cours d'une quête, gardés par quête dans les
/// préférences : le seul chemin qui les écrit, à la main comme à la lecture
/// du suivi.
extension Preferences {
    /// Coche ou décoche un objectif. Coché, il n'est plus en cours.
    func cocher(_ objectif: Int, de quete: Int, _ valide: Bool) {
        guard valide else {
            let cle = String(quete)
            let avant = quetesValides[cle] ?? []
            guard avant.contains(objectif) else { return }
            let apres = avant.filter { $0 != objectif }
            quetesValides[cle] = apres.isEmpty ? nil : apres
            return
        }
        cocher([objectif], de: quete)
    }

    /// Coche des objectifs sans jamais en décocher : une coche posée à la main
    /// reste. Rend combien ne l'étaient pas.
    @discardableResult
    func cocher(_ objectifs: [Int], de quete: Int) -> Int {
        let cle = String(quete)
        let avant = quetesValides[cle] ?? []
        var nouveaux: [Int] = []
        for objectif in objectifs where !avant.contains(objectif) && !nouveaux.contains(objectif) {
            nouveaux.append(objectif)
        }
        if !nouveaux.isEmpty { quetesValides[cle] = avant + nouveaux }
        if let enCours = quetesEnCours[cle], objectifs.contains(enCours) { quetesEnCours[cle] = nil }
        return nouveaux.count
    }

    /// L'objectif devient celui en cours de sa quête, à la place du précédent.
    /// Un objectif coché ne l'est pas : il est fait.
    func mettreEnCours(_ objectif: Int, de quete: Int) {
        let cle = String(quete)
        guard quetesEnCours[cle] != objectif, !(quetesValides[cle] ?? []).contains(objectif) else { return }
        quetesEnCours[cle] = objectif
    }
}
