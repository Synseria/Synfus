import Foundation
import Testing
@testable import Synfus

/// Le banc de simulation du suivi de quêtes : pour chaque quête du vrai
/// catalogue et chaque étape, les écrans que le suivi du jeu montrerait —
/// objectifs ouverts en file, ensemble ou peu à peu, pour chaque nombre de
/// faits —, empilés par deux à quatre, bruités comme l'OCR les rend, relus
/// par `SuiviQuetes.reconnaitre`. Le catalogue est celui de l'app, jamais le
/// dépôt ; ignoré sans lui :
///
///     SYNFUS_QUETES="$HOME/Library/Application Support/Synfus/Quetes.json" sh test.sh SimulationSuivi
///
/// Une coche ne se défait pas (`Preferences.appliquer`) : « faits faux » doit
/// rester à zéro, le rappel vient après.
struct SimulationSuiviTests {
    static var chemin: String? { ProcessInfo.processInfo.environment["SYNFUS_QUETES"] }

    @Test("Le suivi simulé sur le vrai catalogue : titres, étapes, faits", .enabled(if: chemin != nil))
    func simulation() throws {
        let donnees = try Data(contentsOf: URL(fileURLWithPath: (try #require(Self.chemin) as NSString).expandingTildeInPath))
        let quetes = try #require(QuetesDofusDB.relire(donnees), "Quetes.json illisible ou d'une autre forme")
        let banc = Banc(quetes)
        Sortie.dire("\(quetes.quetes.count) quêtes ; largeur du suivi \(banc.limite) ‰ em \(banc.calibrage)")
        Sortie.dire("écran de 10 quêtes : \(banc.chronometrer()) (build de test)")
        for bruite in [false, true] {
            Sortie.dire(bruite ? "— bruité (graine \(Banc.graine))" : "— sans bruit")
            Sortie.dire(Mesures.entete)
            var exemples: [String: [String]] = [:]
            for mode in Mode.allCases {
                let mesures = banc.mesurer(mode, bruite: bruite, exemples: &exemples)
                Sortie.dire(mesures.ligne(mode.rawValue))
                Sortie.dire("  lectures aux faits faux : \(mesures.bruits)")
                Sortie.dire("  titres faux : \(mesures.pireTitres)")
            }
            for (genre, liste) in exemples.sorted(by: { $0.key < $1.key }) {
                Sortie.dire("  \(genre) :")
                liste.forEach { Sortie.dire($0) }
            }
        }
    }
}

// Rangés dans le banc : l'app a aussi son `Mode`.
extension SimulationSuiviTests {
    // MARK: - Écrans simulés

    /// Comment l'étape ouvre ses objectifs : un à la fois, tous ensemble (faits
    /// dans n'importe quel ordre), ou quelques-uns d'avance.
    enum Mode: String, CaseIterable {
        case file = "en file"
        case ensemble
        case progressif
    }

    /// Une quête à l'écran : son étape, ce qui y est fait (rangs), ce que le suivi
    /// montre ouvert, dans l'ordre.
    struct Scenario {
        let quete: Quete
        let etape: Int
        let faits: Set<Int>
        let ouverts: [Int]

        var visibles: [Int] { Array(ouverts.prefix(Banc.objectifsMontres)) }
        var coupe: Bool { ouverts.count > Banc.objectifsMontres }
        var objectifs: [ObjectifQuete] { quete.etapes[etape].objectifs }

        /// Les étapes d'avant comprises.
        var faitsReels: Set<Int> {
            Set(quete.etapes[..<etape].flatMap { $0.objectifs.map(\.id) } + faits.map { objectifs[$0].id })
        }

        /// Ce que le suivi tait entre le premier objectif montré et la coupure.
        var taits: Set<Int> {
            guard let premier = visibles.first else { return [] }
            let dernier = coupe ? visibles.last! : objectifs.count - 1
            return Set((premier...dernier).filter { !visibles.contains($0) }.map { objectifs[$0].id })
        }
    }

    /// SplitMix64 : le même bruit à chaque passage.
    struct Hasard: RandomNumberGenerator {
        private var etat: UInt64
        init(_ graine: UInt64) { etat = graine }
        mutating func next() -> UInt64 {
            etat &+= 0x9E37_79B9_7F4A_7C15
            var z = etat
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func si(_ probabilite: Double) -> Bool { Double.random(in: 0..<1, using: &self) < probabilite }
    }

    /// Les écorchures de l'OCR, chacune nommée pour dire laquelle fait les fautes.
    enum Bruit: String, CaseIterable, Comparable {
        /// l/I/1, O/0, c/e, 3/8, 5/S : la police du jeu.
        case lettres
        /// Accents et apostrophes perdus.
        case accents
        /// L'épingle devant l'objectif, lue comme une lettre.
        case epingle
        /// Les icônes après le titre, lues comme des lettres.
        case icone
        /// L'objectif replié ailleurs (largeur, police).
        case coupure
        /// Une ligne que l'OCR n'a pas rendue.
        case perte

        static func < (a: Bruit, b: Bruit) -> Bool { a.rawValue < b.rawValue }
    }

    /// Les chasses d'Helvetica, en millièmes de cadratin : le suivi replie au mot
    /// près, la largeur se mesure sur les lignes d'une vraie capture.
    enum Chasse {
        private static let table: [Character: Int] = {
            let groupes: [(String, Int)] = [
                ("'", 191), ("ijl’", 222), (" !,./:;[]Ift", 278), ("-()r", 333), ("\"", 355),
                ("cksvxyzJ", 500), ("+<=>", 584), ("FTZ", 611), ("ABEKPSVXY&", 667), ("CDHNRUw", 722),
                ("GOQ", 778), ("mM", 833), ("%", 889), ("Wœ", 944), ("…Œ", 1000),
            ]
            return Dictionary(uniqueKeysWithValues: groupes.flatMap { lettres, chasse in lettres.map { ($0, chasse) } })
        }()

        static func de(_ texte: some StringProtocol) -> Int {
            texte.reduce(0) { total, lettre in
                let base = String(lettre).folding(options: .diacriticInsensitive, locale: nil).first ?? lettre
                return total + (table[lettre] ?? table[base] ?? 556)
            }
        }

        static func replier(_ texte: String, limite: Int) -> [String] {
            var lignes: [String] = [], ligne = ""
            for mot in texte.split(separator: " ") {
                let essai = ligne.isEmpty ? String(mot) : ligne + " " + mot
                if !ligne.isEmpty, de(essai) > limite {
                    lignes.append(ligne)
                    ligne = String(mot)
                } else {
                    ligne = essai
                }
            }
            return ligne.isEmpty ? lignes : lignes + [ligne]
        }
    }

    struct Banc {
        static let graine: UInt64 = 20_261_009
        /// Ce que le suivi montre d'une quête avant « VOIR PLUS… » (la capture
        /// réelle : trois objectifs, cinq lignes).
        static let objectifsMontres = 3

        let quetes: Quetes
        let index: SuiviQuetes.Index
        let limite: Int
        let calibrage: String

        init(_ quetes: Quetes) {
            self.quetes = quetes
            index = SuiviQuetes.Index(quetes)
            // Les lignes de la capture réelle (`SuiviObjectifsTests`) et le mot
            // suivant qui n'y a pas tenu.
            let lues: [(String, String?)] = [
                ("Retrouver Meuh Sieurchance chez lui, au village des", "éleveurs"),
                ("Rapporter 1 âme de Gelée Royale Bleuet à", "Assistante"),
                ("Rapporter 1 âme de Shin Larve à Assistante d'Otomaï.", nil),
                ("Rapporter 1 âme de Rakoopeur à Assistante", "d'Otomaï."),
                ("Examiner l'arche de l'ancien quartier des éleveurs", nil),
                ("Découvrir la carte : Sortie du Labyrinthe du Minotot", nil),
                ("Vaincre x1 [Minotot] en un seul combat", nil),
            ]
            // La police réelle n'est pas Helvetica : la largeur qui contredit le
            // moins de lignes, la plus grande à égalité.
            let tiennent = lues.map { Chasse.de($0.0) }
            let debordent = lues.compactMap { ligne, suivant in suivant.map { Chasse.de(ligne + " " + $0) } }
            func contredites(_ limite: Int) -> Int { tiennent.count { $0 > limite } + debordent.count { $0 <= limite } }
            limite = tiennent.max { (contredites($1), $0) < (contredites($0), $1) }!
            calibrage = "(\(contredites(limite)) ligne sur \(lues.count) contredite)"
        }

        func texte(_ objectif: ObjectifQuete) -> String {
            quetes.texte(Lieu.traduit(objectif.textes, .fr) ?? "", en: .fr)
        }

        /// Chaque étape, chaque nombre de faits, une fois.
        func scenarios(_ mode: Mode) -> [Scenario] {
            quetes.quetes.flatMap { quete in
                quete.etapes.indices.flatMap { etape -> [Scenario] in
                    let objectifs = quete.etapes[etape].objectifs
                    guard !objectifs.isEmpty, objectifs.allSatisfy({ !texte($0).isEmpty }) else { return [] }
                    let n = objectifs.count
                    return (0..<n).map { k in
                        var hasard = Hasard(Self.graine ^ UInt64(quete.id) << 20 ^ UInt64(etape) << 10 ^ UInt64(k))
                        switch mode {
                        case .file:
                            return Scenario(quete: quete, etape: etape, faits: Set(0..<k), ouverts: [k])
                        case .ensemble:
                            let faits = Set(Array(0..<n).shuffled(using: &hasard).prefix(k))
                            return Scenario(quete: quete, etape: etape, faits: faits, ouverts: (0..<n).filter { !faits.contains($0) })
                        case .progressif:
                            let ouverts = n - k < 2 ? 1 : Int.random(in: 2...(n - k), using: &hasard)
                            return Scenario(quete: quete, etape: etape, faits: Set(0..<k), ouverts: Array(k..<k + ouverts))
                        }
                    }
                }
            }
        }

        /// Par deux à quatre quêtes, jamais deux fois la même.
        func ecrans(_ scenarios: [Scenario], hasard: inout Hasard) -> [[Scenario]] {
            var ecrans: [[Scenario]] = [], ecran: [Scenario] = []
            var taille = Int.random(in: 2...4, using: &hasard)
            for scenario in scenarios.shuffled(using: &hasard) {
                if ecran.count == taille || ecran.contains(where: { $0.quete.id == scenario.quete.id }) {
                    ecrans.append(ecran)
                    ecran = []
                    taille = Int.random(in: 2...4, using: &hasard)
                }
                ecran.append(scenario)
            }
            return ecran.isEmpty ? ecrans : ecrans + [ecran]
        }

        /// Les lignes que l'OCR rendrait de l'écran, et les bruits posés sur chaque quête.
        func lignes(_ ecran: [Scenario], bruite: Bool, hasard: inout Hasard) -> (lignes: [String], bruits: [Set<Bruit>]) {
            var lignes: [String] = [], bruits: [Set<Bruit>] = []
            if hasard.si(0.5) { lignes.append("Suivi de quêtes") }
            for scenario in ecran {
                var poses: Set<Bruit> = []
                var bloc: [String] = []
                var titre = Lieu.traduit(scenario.quete.noms, .fr) ?? ""
                if bruite, hasard.si(0.2) {
                    titre += [" 8", " @", " Q", " oo", " 88"].randomElement(using: &hasard)!
                    poses.insert(.icone)
                }
                bloc.append(titre)
                for rang in scenario.visibles {
                    var largeur = limite
                    if bruite, hasard.si(0.1) {
                        largeur = Int(Double(limite) * Double.random(in: 0.8...1.2, using: &hasard))
                        poses.insert(.coupure)
                    }
                    var replie = Chasse.replier(texte(scenario.objectifs[rang]), limite: largeur)
                    if bruite, hasard.si(0.15) {
                        replie[0] = ["e ", "o ", "Q ", "? ", "• "].randomElement(using: &hasard)! + replie[0]
                        poses.insert(.epingle)
                    }
                    bloc += replie
                }
                if scenario.coupe { bloc.append(bruite && hasard.si(0.3) ? "VOIR PLU5..." : "VOIR PLUS…") }
                if bruite {
                    bloc = bloc.compactMap { ligne in
                        if hasard.si(0.01) {
                            poses.insert(.perte)
                            return nil
                        }
                        return ecorcher(ligne, poses: &poses, hasard: &hasard)
                    }
                }
                lignes += bloc
                bruits.append(poses)
            }
            return (lignes, bruits)
        }

        private func ecorcher(_ ligne: String, poses: inout Set<Bruit>, hasard: inout Hasard) -> String {
            let lettres: [Character: [(Character?, Double)]] = [
                "l": [("I", 0.04), ("i", 0.01)], "I": [("l", 0.15), ("1", 0.03)], "1": [("l", 0.1), ("I", 0.05)],
                "O": [("0", 0.1)], "0": [("O", 0.1)], "o": [("0", 0.01)], "e": [("c", 0.01)], "i": [("l", 0.02)],
                "3": [("8", 0.02)], "5": [("S", 0.03), ("6", 0.01)], "6": [("5", 0.01)], "8": [("3", 0.02), ("B", 0.02)],
            ]
            var sortie = ""
            for lettre in ligne {
                if let fautes = lettres[lettre], let faute = fautes.first(where: { hasard.si($0.1) }) {
                    poses.insert(.lettres)
                    if let remplacante = faute.0 { sortie.append(remplacante) }
                } else if lettre == "'" || lettre == "’", hasard.si(0.3) {
                    poses.insert(.accents)
                } else if let base = String(lettre).folding(options: .diacriticInsensitive, locale: nil).first,
                          base != lettre, hasard.si(0.3) {
                    poses.insert(.accents)
                    sortie.append(base)
                } else {
                    sortie.append(lettre)
                }
            }
            return sortie
        }

        /// `exemples` : quelques lectures fautives par genre de faute, pour en chercher la cause.
        func mesurer(_ mode: Mode, bruite: Bool, exemples: inout [String: [String]]) -> Mesures {
            var hasard = Hasard(Self.graine ^ UInt64(Mode.allCases.firstIndex(of: mode)!) << 40)
            var mesures = Mesures()
            for ecran in ecrans(scenarios(mode), hasard: &hasard) {
                let (lignes, bruits) = self.lignes(ecran, bruite: bruite, hasard: &hasard)
                let lu = SuiviQuetes.reconnaitre(lignes, dans: index)
                let presentes = Set(ecran.map(\.quete.id))
                for reconnue in lu.reconnues where !presentes.contains(reconnue.id) {
                    mesures.titresFaux += 1
                    mesures.faitsFauxTitre += reconnue.faits.count
                    let nom = quetes.quetes.first { $0.id == reconnue.id }.flatMap { Lieu.traduit($0.noms, .fr) } ?? "?"
                    let vrai = ecran.contains { Lieu.traduit($0.quete.noms, .fr) == nom }
                    mesures.titresFauxNoms[vrai ? "\(nom) (homonyme)" : nom, default: 0] += 1
                }
                for (scenario, poses) in zip(ecran, bruits) {
                    let reconnue = lu.reconnues.first { $0.id == scenario.quete.id }
                    let (faux, ouvertTu) = mesures.noter(scenario, reconnue, poses: poses)
                    let etapeFausse = reconnue?.etape.map { $0 != scenario.etape } ?? false
                    let genre = faux > 0 ? "faits faux" : ouvertTu ? "ouvert tu" : etapeFausse ? "étape fausse" : nil
                    guard let genre, exemples[genre, default: []].count < 6 else { continue }
                    let nom = Lieu.traduit(scenario.quete.noms, .fr) ?? "?"
                    exemples[genre, default: []].append(
                        "    \(mode.rawValue) · \(nom) (#\(scenario.quete.id)) étape \(scenario.etape + 1)/"
                        + "\(scenario.quete.etapes.count), faits \(scenario.faits.sorted()), ouverts \(scenario.ouverts) → "
                        + "\(faux) faux, lue étape \(reconnue?.etape.map { "\($0 + 1)" } ?? "—"), tus \(reconnue?.nonMontres ?? []) ; \(lignes)")
                }
            }
            return mesures
        }

        /// Une reconnaissance d'un écran de dix quêtes bruité, médiane et pire.
        func chronometrer() -> String {
            var hasard = Hasard(Self.graine)
            let tous = Mode.allCases.flatMap { scenarios($0) }
            var durees: [Double] = []
            for _ in 0..<60 {
                var ecran: [Scenario] = []
                while ecran.count < 10 {
                    let scenario = tous.randomElement(using: &hasard)!
                    if !ecran.contains(where: { $0.quete.id == scenario.quete.id }) { ecran.append(scenario) }
                }
                let lignes = self.lignes(ecran, bruite: true, hasard: &hasard).lignes
                let debut = ContinuousClock.now
                _ = SuiviQuetes.reconnaitre(lignes, dans: index)
                let duree = ContinuousClock.now - debut
                durees.append(Double(duree.components.attoseconds) / 1e15 + Double(duree.components.seconds) * 1000)
            }
            durees.sort()
            return "médiane \(Int(durees[durees.count / 2])) ms, pire \(Int(durees.last!)) ms"
        }
    }

    // MARK: - Mesures

    struct Mesures {
        var lectures = 0
        var titres = 0
        var titresFaux = 0
        var multi = 0
        var etapeJuste = 0
        var etapeSure = 0
        var etapeSureFausse = 0
        var etapeFausse = 0
        var faitsReels = 0
        var faitsTrouves = 0
        var faitsFaux = 0
        var lecturesFaitsFaux = 0
        var faitsFauxTitre = 0
        var titresFauxNoms: [String: Int] = [:]

        var aFaireJuste = 0
        var nonMontresJuste = 0
        var nonMontresFaux = 0
        /// Les lectures aux faits faux, par bruit posé sur leur quête.
        var parBruit: [Bruit: Int] = [:]
        var fauxSansBruit = 0
        var fauxEtapeIncertaine = 0

        var pireTitres: String {
            titresFauxNoms.sorted { ($1.value, $0.key) < ($0.value, $1.key) }.prefix(8).map { "\($0.key) \($0.value)" }
                .joined(separator: ", ")
        }

        var bruits: String {
            (["étape incertaine \(fauxEtapeIncertaine)", "aucun bruit \(fauxSansBruit)"] + parBruit.sorted { $0.key < $1.key }.map { "\($0.key.rawValue) \($0.value)" })
                .joined(separator: ", ")
        }

        /// Rend combien de faits sont faux, et si un objectif ouvert passe pour tu.
        mutating func noter(_ scenario: Scenario, _ reconnue: SuiviQuetes.Reconnue?, poses: Set<Bruit>) -> (Int, Bool) {
            lectures += 1
            guard let reconnue else { return (0, false) }
            titres += 1
            if scenario.quete.etapes.count > 1 {
                multi += 1
                if reconnue.etape == scenario.etape { etapeJuste += 1 } else if reconnue.etape != nil { etapeFausse += 1 }
                if reconnue.etapeSure {
                    if reconnue.etape == scenario.etape { etapeSure += 1 } else { etapeSureFausse += 1 }
                }
            }
            let reels = scenario.faitsReels
            let faits = Set(reconnue.faits)
            let faux = faits.subtracting(reels).count
            faitsReels += reels.count
            faitsTrouves += faits.intersection(reels).count
            faitsFaux += faux
            if faux > 0 {
                lecturesFaitsFaux += 1
                if poses.isEmpty { fauxSansBruit += 1 }
                if scenario.quete.etapes.count > 1, !reconnue.etapeSure { fauxEtapeIncertaine += 1 }
                for bruit in poses { parBruit[bruit, default: 0] += 1 }
            }
            let objectifs = scenario.objectifs
            if reconnue.aFaire == scenario.visibles.map({ objectifs[$0].id }) { aFaireJuste += 1 }
            if Set(reconnue.nonMontres) == scenario.taits { nonMontresJuste += 1 }
            let ouvertTu = !Set(reconnue.nonMontres).isDisjoint(with: scenario.ouverts.map { objectifs[$0].id })
            if ouvertTu { nonMontresFaux += 1 }
            return (faux, ouvertTu)
        }

        static let entete = "mode        | lectures | titres | t. faux | étape | é. fausse | sûre  | sûre fausse | faits faux (lect.) | f. faux titre | rappel | à faire | non montrés | n.m. faux"

        func ligne(_ nom: String) -> String {
            func pc(_ a: Int, _ b: Int) -> String { b == 0 ? "  —  " : String(format: "%5.1f", 100 * Double(a) / Double(b)) }
            return [nom.padding(toLength: 11, withPad: " ", startingAt: 0), String(format: "%8d", lectures),
                    pc(titres, lectures) + " ", String(format: "%7d", titresFaux), pc(etapeJuste, multi), String(format: "%9d", etapeFausse), pc(etapeSure, multi),
                    String(format: "%11d", etapeSureFausse), String(format: "%9d (%6d)", faitsFaux, lecturesFaitsFaux),
                    String(format: "%13d", faitsFauxTitre), pc(faitsTrouves, faitsReels) + " ", pc(aFaireJuste, titres) + "  ",
                    pc(nonMontresJuste, titres) + "      ", String(format: "%9d", nonMontresFaux)]
                .joined(separator: " | ")
        }
    }
}
