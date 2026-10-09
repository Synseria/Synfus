import Foundation

/// Les coches, les décoches, l'objectif en cours et l'étape d'une quête,
/// gardés par quête dans les préférences : le seul chemin qui les écrit, à la
/// main comme à la lecture du suivi. Un geste touche jusqu'à trois de ces
/// réglages : il ne les écrit qu'une fois (`enUneEcriture`).
extension Preferences {
    /// Coche ou décoche à la main. Coché, il n'est plus en cours ; décoché, il
    /// est retenu : la lecture suivante, qui le tient peut-être encore pour
    /// fait, ne le recoche pas.
    func cocher(_ objectif: Int, de quete: Int, _ valide: Bool) {
        let cle = String(quete)
        enUneEcriture {
            if valide {
                if (quetesDecoches[cle] ?? []).contains(objectif) { quetesDecoches[cle] = Self.sans([objectif], quetesDecoches[cle]) }
                ajouter([objectif], de: quete)
                return
            }
            guard (quetesValides[cle] ?? []).contains(objectif) else { return }
            quetesValides[cle] = Self.sans([objectif], quetesValides[cle])
            if !(quetesDecoches[cle] ?? []).contains(objectif) { quetesDecoches[cle, default: []].append(objectif) }
        }
    }

    /// Ce qu'une lecture du suivi dit des quêtes qu'il montre, écrit d'un
    /// coup. Pour chacune : ses objectifs montrés ouverts ne sont plus des
    /// décoches — le jeu dit lui-même qu'ils restent à faire. Ses faits se
    /// cochent (`quetesCocherSuivi`), jamais ceux décochés à la main, et rien
    /// ne se décoche. Une étape établie après celle que montre le panneau l'y
    /// fait avancer, jamais reculer : le suivi d'un perso en retard ne ramène
    /// pas en arrière. Rend combien d'objectifs se sont cochés.
    @discardableResult
    func appliquer(_ lues: [SuiviQuetes.Reconnue]) -> Int {
        enUneEcriture { lues.reduce(0) { $0 + appliquer(lue: $1) } }
    }

    private func appliquer(lue: SuiviQuetes.Reconnue) -> Int {
        let cle = String(lue.id)
        if let decoches = quetesDecoches[cle], decoches.contains(where: lue.aFaire.contains) {
            quetesDecoches[cle] = Self.sans(lue.aFaire, decoches)
        }
        if lue.etapeSure, let etape = lue.etape, etape > quetesEtape[cle] ?? 0 { quetesEtape[cle] = etape }
        guard quetesCocherSuivi else { return 0 }
        let decoches = quetesDecoches[cle] ?? []
        return ajouter(lue.faits.filter { !decoches.contains($0) }, de: lue.id)
    }

    /// L'objectif devient celui en cours de sa quête, à la place du précédent.
    /// Un objectif coché ne l'est pas : il est fait.
    func mettreEnCours(_ objectif: Int, de quete: Int) {
        let cle = String(quete)
        guard quetesEnCours[cle] != objectif, !(quetesValides[cle] ?? []).contains(objectif) else { return }
        quetesEnCours[cle] = objectif
    }

    /// Coche sans jamais décocher ; rend combien ne l'étaient pas.
    @discardableResult
    private func ajouter(_ objectifs: [Int], de quete: Int) -> Int {
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

    /// La liste privée de `retires` ; `nil` quand elle se vide, pour ne pas
    /// garder de clé vide dans la sauvegarde.
    private static func sans(_ retires: [Int], _ liste: [Int]?) -> [Int]? {
        let reste = (liste ?? []).filter { !retires.contains($0) }
        return reste.isEmpty ? nil : reste
    }
}
