import Foundation

/// Les lignes lues sous le titre d'une quête du suivi → les objectifs de son
/// étape qu'elles désignent, et ce qu'on en déduit des autres. Pur.
///
/// Le suivi montre, sous chaque quête, les objectifs **actifs** de l'étape
/// en cours, dans l'ordre de l'étape, un objectif souvent sur deux lignes ;
/// un objectif fait disparaît, et « VOIR PLUS… » coupe la liste. Une étape
/// ne dévoile pas tout d'un coup (« Pense-bête » : neuf objectifs, un seul
/// montré) : ce qui suit le dernier objectif montré peut n'être pas encore
/// ouvert, seul ce qui le précède est tenu pour fait.
enum SuiviObjectifs {
    struct Lecture: Equatable, Sendable {
        let etape: Int
        let aFaire: [Int]
        let faits: [Int]
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
    /// l'écran. `nil` : aucun objectif d'aucune étape ne s'y lit en entier,
    /// ou deux étapes s'y lisent aussi bien.
    static func lire(_ lignes: [String], quete: Quete, langue: Langue, dans quetes: Quetes) -> Lecture? {
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
        return Lecture(etape: rang, aFaire: aFaire,
                       faits: sure(affectes, lignes: lues.count)
                           ? faits(etape.objectifs.map(\.id), affectes: affectes) : [])
    }

    /// La lecture permet-elle de conclure sur les faits ? Chaque ligne doit
    /// être un objectif — sinon une ligne mal lue pourrait être l'un de ceux
    /// qu'on croirait faits —, et l'écran dans l'ordre de l'étape, ce sur quoi
    /// repose la déduction. Une liste coupée n'y change rien : ce qu'elle cache
    /// vient après.
    private static func sure(_ affectes: [Affectation], lignes: Int) -> Bool {
        let couvertes = affectes.reduce(0) { $0 + $1.fin - $1.debut }
        let rangs = affectes.map(\.objectif)
        return couvertes == lignes && rangs == rangs.sorted()
    }

    /// Les objectifs qui précèdent le dernier montré et ne le sont pas.
    private static func faits(_ ids: [Int], affectes: [Affectation]) -> [Int] {
        guard let dernier = affectes.map(\.objectif).max() else { return [] }
        let montres = Set(affectes.map(\.objectif))
        return (0..<dernier).filter { !montres.contains($0) }.map { ids[$0] }
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
    /// l'ordre de l'écran départage, puis le plus tôt dans l'étape : il laisse
    /// le moins d'objectifs passer pour faits.
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
