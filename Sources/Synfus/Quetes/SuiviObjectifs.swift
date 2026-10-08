import Foundation

/// Les lignes lues sous le titre d'une quête du suivi → les objectifs de son
/// étape qu'elles désignent, et ce qu'on en déduit des autres. Pur.
///
/// Le suivi montre, sous chaque quête, les objectifs **ouverts** de l'étape
/// en cours, dans l'ordre de l'étape, un objectif souvent sur deux lignes ;
/// un objectif fait disparaît, et « VOIR PLUS… » coupe la fin de la liste,
/// jamais le début. Une étape ne dévoile pas tout d'un coup (« Pense-bête » :
/// neuf objectifs, un seul montré) et ses objectifs ne s'ouvrent pas toujours
/// en file : seul ce qui précède le **premier** objectif montré est tenu pour
/// fait — et les étapes d'avant, quand l'étape est sûre. Ce que le suivi tait
/// ensuite, jusqu'à la coupure, n'est pas ouvert (ou fait hors de l'ordre) :
/// le panneau le met en retrait, et ne le propose pas de cocher.
enum SuiviObjectifs {
    struct Lecture: Equatable, Sendable {
        let etape: Int
        /// Aucune autre étape ne lit mieux une seule ligne : l'étape est
        /// établie, le panneau peut y avancer.
        let sure: Bool
        let aFaire: [Int]
        let faits: [Int]
        /// Ce que l'écran tait d'une lecture entière : pas encore ouvert, ou
        /// fait hors de l'ordre.
        let nonMontres: [Int]
    }

    /// Un objectif tient au plus sur autant de lignes.
    static let lignesParObjectif = 3
    /// Ce qu'une ligne peut porter au-delà de l'objectif : l'épingle devant,
    /// lue parfois comme une lettre.
    static let surplus = 4
    /// Les fautes admises, une par tant de caractères : la police des
    /// objectifs, droite, se lit mieux que celle des titres.
    static let caracteresParFaute = 5
    /// En deçà, une ligne n'est que du bruit (icône, « 0/1 »).
    static let lettresMinimum = 3
    /// La ligne qui coupe la liste, dans les langues du jeu.
    static let troncatures = ["voir plus", "see more", "show more", "ver mas", "mostrar mas"]

    /// `lignes` : normalisées (`Ressemblance.normaliser`), dans l'ordre de
    /// l'écran ; `coupee` : la zone lue a pu couper la fin de la liste, comme
    /// « VOIR PLUS… ». `nil` : aucun objectif d'aucune étape ne s'y lit en
    /// entier, ou deux étapes s'y lisent aussi bien.
    static func lire(_ lignes: [String], coupee: Bool = false, quete: Quete, langue: Langue,
                     dans quetes: Quetes) -> Lecture? {
        let lignes = lignes.filter { $0.count { $0.isLetter } >= lettresMinimum }
        let lues = lignes.filter { !estTroncature($0) }
        guard !lues.isEmpty else { return nil }
        let fenetres = Self.fenetres(lues)
        let parEtape = quete.etapes.map { etape in
            affecter(fenetres, objectifs: etape.objectifs.map { objectif in
                let modele = Lieu.traduit(objectif.textes, langue) ?? ""
                return Ressemblance.Forme(Ressemblance.normaliser(quetes.texte(modele, en: langue)))
            })
        }
        let scores = parEtape.map { $0.reduce(0) { $0 + $1.explique } }
        guard let meilleur = scores.max(), meilleur > 0, scores.count(where: { $0 == meilleur }) == 1,
              let rang = scores.firstIndex(of: meilleur)
        else { return nil }
        let etape = quete.etapes[rang]
        let affectes = parEtape[rang].sorted { $0.debut < $1.debut }
        let aFaire = affectes.map { etape.objectifs[$0.objectif].id }
        let couts = Self.couts(parEtape[rang], lignes: lues.count)
        let sure = parEtape.indices.allSatisfy { autre in
            autre == rang || zip(couts, Self.couts(parEtape[autre], lignes: lues.count)).allSatisfy { $0 <= $1 }
        }
        // L'écran doit suivre l'ordre de l'étape, sur quoi repose la déduction,
        // et le premier objectif montré être la première ligne : une ligne
        // illisible avant lui pourrait être un objectif plus tôt, encore ouvert.
        let rangs = affectes.map(\.objectif)
        guard let premier = affectes.first, premier.debut == 0, rangs == rangs.sorted() else {
            return Lecture(etape: rang, sure: sure, aFaire: aFaire, faits: [], nonMontres: [])
        }
        let avant = sure ? quete.etapes[..<rang].flatMap { $0.objectifs.map(\.id) } : []
        // Ce que l'écran tait après le premier objectif montré n'est pas
        // ouvert — ou fait hors de l'ordre —, jusqu'à la coupure ; au-delà,
        // rien n'est su. Une ligne incomprise pourrait être l'un d'eux.
        var nonMontres: [Int] = []
        if couts.allSatisfy(\.isFinite) {
            let dernier = coupee || lues.count < lignes.count ? rangs.last ?? premier.objectif : etape.objectifs.count - 1
            nonMontres = (premier.objectif...dernier).filter { !rangs.contains($0) }.map { etape.objectifs[$0].id }
        }
        return Lecture(etape: rang, sure: sure, aFaire: aFaire,
                       faits: avant + etape.objectifs[..<premier.objectif].map(\.id), nonMontres: nonMontres)
    }

    /// Ce que coûte chaque ligne lue, par caractère, dans l'affectation d'une
    /// étape ; une ligne qu'elle n'explique pas coûte l'infini. L'étape est
    /// sûre quand aucune autre ne lit mieux une seule ligne : un texte
    /// répété d'étape en étape (« Retourner voir Maître des clefs ») ne la
    /// désigne pas, mais ne la dément pas non plus.
    private static func couts(_ affectes: [Affectation], lignes: Int) -> [Double] {
        var couts = [Double](repeating: .infinity, count: lignes)
        for affectation in affectes {
            for ligne in affectation.debut..<affectation.fin {
                couts[ligne] = Double(affectation.cout) / Double(affectation.longueur)
            }
        }
        return couts
    }

    private static func estTroncature(_ ligne: String) -> Bool {
        troncatures.contains { motif in
            ligne.count <= motif.count + 2 && Ressemblance.distanceDansTexte(motif, ligne) <= 1
        }
    }

    // MARK: - Affectation

    /// Une ou plusieurs lignes consécutives, jointes : un objectif à cheval
    /// sur deux lignes se lit comme une.
    private struct Fenetre {
        let debut: Int
        let fin: Int
        let forme: Ressemblance.Forme
    }

    private struct Affectation {
        let debut: Int
        let fin: Int
        let objectif: Int
        /// Éditions, débordement de la fenêtre compris.
        let cout: Int
        let longueur: Int
        /// Les caractères de l'objectif que la fenêtre explique : le score de
        /// l'étape.
        var explique: Int { longueur - cout }
    }

    private static func fenetres(_ lignes: [String]) -> [Fenetre] {
        lignes.indices.flatMap { debut in
            (1...lignesParObjectif).compactMap { taille -> Fenetre? in
                guard debut + taille <= lignes.count else { return nil }
                let texte = lignes[debut..<debut + taille].joined(separator: " ")
                return Fenetre(debut: debut, fin: debut + taille, forme: Ressemblance.Forme(texte))
            }
        }
    }

    /// Une ligne ↔ un objectif au plus, le mieux lu d'abord. À lecture égale
    /// — le même texte à plusieurs rangs (« Aller voir Jykel » deux fois) —
    /// le rang qui garde l'écran dans l'ordre de l'étape, puis le plus tôt :
    /// il laisse le moins d'objectifs passer pour faits.
    private static func affecter(_ fenetres: [Fenetre], objectifs: [Ressemblance.Forme]) -> [Affectation] {
        var candidats: [Affectation] = []
        for fenetre in fenetres {
            for (rang, objectif) in objectifs.enumerated() {
                if let cout = cout(objectif, fenetre.forme) {
                    candidats.append(Affectation(debut: fenetre.debut, fin: fenetre.fin, objectif: rang,
                                                 cout: cout, longueur: objectif.longueur))
                }
            }
        }
        var retenues: [Affectation] = []
        while !candidats.isEmpty {
            let choix = candidats.min { a, b in
                let ra = a.cout * b.longueur, rb = b.cout * a.longueur
                if ra != rb { return ra < rb }
                if a.debut != b.debut { return a.debut < b.debut }
                let (ia, ib) = (dansLOrdre(a, retenues), dansLOrdre(b, retenues))
                if ia != ib { return ia }
                return (a.objectif, a.fin) < (b.objectif, b.fin)
            }!
            retenues.append(choix)
            candidats.removeAll { $0.objectif == choix.objectif || ($0.debut < choix.fin && choix.debut < $0.fin) }
        }
        return retenues
    }

    /// Placée là, l'affectation garde-t-elle l'ordre de l'écran dans l'étape ?
    private static func dansLOrdre(_ candidat: Affectation, _ retenues: [Affectation]) -> Bool {
        retenues.allSatisfy { ($0.debut < candidat.debut) == ($0.objectif < candidat.objectif) }
    }

    /// Ce que coûte de lire `objectif` dans `texte`, `nil` au-delà des fautes
    /// admises. Le texte qui déborde compte : sans quoi une fenêtre de deux
    /// objectifs vaudrait le premier.
    private static func cout(_ objectif: Ressemblance.Forme, _ texte: Ressemblance.Forme) -> Int? {
        let longueur = objectif.longueur
        guard longueur >= SuiviQuetes.longueurFloue else { return nil }
        let tolerance = longueur / caracteresParFaute
        let deborde = max(texte.longueur - longueur, 0)
        guard deborde <= tolerance + surplus, longueur <= texte.longueur + tolerance,
              !objectif.tropLoin(de: texte, tolerance: tolerance)
        else { return nil }
        return Ressemblance.distanceDansTexte(objectif, texte, auPlus: tolerance).map { $0 + deborde }
    }
}
