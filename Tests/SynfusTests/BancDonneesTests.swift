import Foundation
import Testing
@testable import Synfus

/// Le banc des calculs sur les données du jeu, sur le vrai catalogue des
/// quêtes — jamais celui du dépôt ; ignoré sans lui :
///
///     SYNFUS_QUETES="$HOME/Library/Application Support/Synfus/Quetes.json" sh test.sh BancDonnees
///
/// Des durées médianes en build de test : à comparer entre elles, pas à l'app.
/// Aucun rendu : ce que les vues redemandent, calculé seul. En série : des
/// mesures en parallèle se gêneraient.
@Suite(.serialized)
struct BancDonneesTests {
    static var chemin: String? { ProcessInfo.processInfo.environment["SYNFUS_QUETES"] }

    /// La médiane de `fois` passages.
    private static func chrono(_ fois: Int = 5, _ bloc: () -> Void) -> String {
        let horloge = ContinuousClock()
        let mediane = (0..<fois).map { _ in horloge.measure(bloc) }.sorted()[fois / 2]
        let ms = Double(mediane.components.seconds) * 1000 + Double(mediane.components.attoseconds) / 1e15
        return String(format: "%.3f ms", ms)
    }

    private static func lire() throws -> (donnees: Data, quetes: Quetes) {
        let donnees = try Data(contentsOf: URL(fileURLWithPath: (try #require(chemin) as NSString).expandingTildeInPath))
        return (donnees, try #require(QuetesDofusDB.relire(donnees), "Quetes.json illisible ou d'une autre forme"))
    }

    private static let position = PositionCarte(x: 2, y: -3, zone: "Amakna (Village d'Amakna)")
    private static let reseau = ReseauSousZones(Carte.integree)
    private static let zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:]),
                                           reseau: reseau)

    @Test("Lancement : ce qui se lit et s'indexe hors du fil principal", .enabled(if: chemin != nil))
    func lancement() throws {
        let (donnees, quetes) = try Self.lire()
        let carte = try Data(contentsOf: try #require(Ressources.url("Carte.json")))
        Sortie.dire("\(quetes.quetes.count) quêtes, \(quetes.pnjs.count) PNJ ; \(Carte.integree.lieux.count) lieux")
        Sortie.dire("lancement — décodage de Quetes.json : \(Self.chrono(3) { _ = QuetesDofusDB.relire(donnees) })")
        Sortie.dire("lancement — jeu en vigueur (index et tris) : \(Self.chrono { _ = QuetesEnVigueur(quetes, langue: .fr) })")
        Sortie.dire("lancement — décodage de la carte intégrée : \(Self.chrono(3) { _ = try? JSONDecoder().decode(Carte.self, from: carte) })")
        let index = Self.chrono {
            _ = ReseauSousZones(Carte.integree)
            _ = Carte.integree.zaaps
            _ = ReperesCarte(Carte.integree.lieux)
        }
        Sortie.dire("lancement — réseau, zaaps et repères de la carte : \(index)")
    }

    @Test("Panneau des quêtes : la fiche, faite puis gardée ; la tournée", .enabled(if: chemin != nil))
    func panneau() throws {
        let quetes = try Self.lire().quetes
        let longue = try #require(quetes.quetes.max { $0.etapes.count < $1.etapes.count })
        Sortie.dire("fiche — la plus longue (\(longue.etapes.count) étapes), faite : \(Self.chrono(20) { _ = quetes.fiche(longue, en: .fr) })")
        var enVigueur = QuetesEnVigueur(quetes, langue: .fr)
        _ = enVigueur.fiche(longue.id)
        Sortie.dire("fiche — la plus longue, gardée : \(Self.chrono(20) { _ = enVigueur.fiche(longue.id) })")
        let cases = [(1, 5, -18), (2, -20, 10), (3, 14, 25), (4, -2, 0), (5, 3, -5), (6, -27, -36), (7, 7, -4)]
        Sortie.dire("tournée — 7 objectifs, calculée : \(Self.chrono { _ = Self.tournee(cases.map { (id: $0.0, x: $0.1, y: $0.2) }) })")
    }

    @Test("Trajets : où trouver un objet de trente lâcheurs, les zaaps par distance", .enabled(if: chemin != nil))
    func trajets() {
        let carte = Carte.integree
        let sousZones = carte.sousZones.map(\.id).filter { !Self.reseau.cases($0).isEmpty }
        let donjons = carte.lieux.filter { $0.categorie == CategorieLieu.donjon.rawValue }
        let lacheurs = (0..<30).map { rang in
            let repaires = (0..<4).map {
                RepaireMonstre(genre: .sousZone, id: sousZones[(rang * 7 + $0 * 13) % sousZones.count], noms: [:], entree: nil)
            } + [RepaireMonstre(genre: .donjon, id: rang, noms: donjons[rang % donjons.count].noms, entree: nil)]
            return SourcesObjet.Lacheur(monstre: FicheMonstre(id: rang, noms: [:], repaires: repaires), taux: Double(rang))
        }
        let depart = ItineraireZaap.rejoindre(Self.position)!
        let reperes = ReperesCarte(carte.lieux)
        let situes = Self.chrono {
            _ = OuTrouver.lacheurs(SourcesObjet(lacheurs: lacheurs, recette: nil)) { fiche in
                OuTrouver.situes(fiche.repaires, depuis: depart, reseau: Self.reseau, reperes: reperes) { Self.cout(depart, $0) }
            }
        }
        Sortie.dire("où trouver — 30 lâcheurs × 5 repaires, situés : \(situes)")
        let parDistance = Self.chrono(20) { _ = CatalogueZaaps.parDistance(Self.zaaps.liste, depuis: Self.position) }
        Sortie.dire("zaaps — par distance (\(Self.zaaps.liste.count)) : \(parDistance)")
    }

    @Test("Palette : l'index à la première frappe, les frappes, les tris", .enabled(if: chemin != nil))
    func palette() throws {
        var contexte = ContextePalette()
        contexte.position = Self.position
        contexte.zaaps = Self.zaaps
        contexte.lieux = Carte.integree.lieux
        contexte.quetes = try Self.lire().quetes
        let champs = IndexPalette.champs(de: contexte)
        Sortie.dire("palette — index préchauffé, première frappe : \(Self.chrono(3) { _ = IndexPalette(contexte, connus: champs).tout })")
        let index = IndexPalette(contexte, connus: champs)
        _ = index.tout
        _ = index.quetes
        for requete in ["a", "bo", "bonta", "/quete a", "/pnj "] {
            Sortie.dire("palette — frappe « \(requete) » : \(Self.chrono { _ = RecherchePalette.entrees(requete, index) })")
        }
        Sortie.dire("palette — frappe « a », tri alphabétique : \(Self.chrono { _ = RecherchePalette.entrees("a", index, tri: .alphabetique) })")
        let quetes = Self.chrono { _ = RecherchePalette.entrees("", index, filtre: .quetes, tri: .alphabetique) }
        Sortie.dire("palette — quêtes sans rien taper, tri alphabétique : \(quetes)")
        let cle = { (titre: String) in RecherchePalette.Champs(titre: titre).cleAlphabetique }
        let titres = index.tout.map(\.entree.titre).sorted { cle($0) < cle($1) }
        let inversions = zip(titres, titres.dropFirst()).filter { $0.localizedStandardCompare($1) == .orderedDescending }
        Sortie.dire("palette — clé alphabétique : \(inversions.count) voisins sur \(titres.count) rangés autrement que localizedStandardCompare")
        inversions.prefix(8).forEach { Sortie.dire("    « \($0) » avant « \($1) »") }
    }

    @Test("Chasse et images : la reconnaissance des indices, les vues de carte décodées", .enabled(if: chemin != nil))
    func chasseEtImages() {
        if let donnees = try? Data(contentsOf: Ressources.dossierUtilisateur.appending(path: "IndicesChasse.json")),
           let indices = try? JSONDecoder().decode(ChasseDofusDB.Releve.self, from: donnees).indices {
            let lignes = ["Départ [-25,38]", "Étape : 3/5", "Affiche de carte au trésor", "Arbre à épines",
                          "Crâne de likrone dans la glace", "Poupée koalak", "Ancre dorée", "Rose noire", "Phorreur",
                          "Aiguile à coudre"]
            Sortie.dire("chasse — \(indices.count) indices, 10 lignes reconnues : \(Self.chrono { _ = EtapeChasse.ciblesLues(dans: lignes, parmi: indices) })")
            for saisie in ["arb", "arbre a epnes"] {
                let suggestions = Self.chrono { _ = IndicesChasse.rechercher(saisie, parmi: indices, langue: .fr, limite: 6) }
                Sortie.dire("chasse — suggestions « \(saisie) » : \(suggestions)")
            }
        }
        let dossier = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "Synfus/DofusDB", directoryHint: .isDirectory)
        guard let nom = (try? FileManager.default.contentsOfDirectory(atPath: dossier.path))?.first(where: { $0.hasPrefix("0.5-") }),
              let jpeg = try? Data(contentsOf: dossier.appending(path: nom))
        else { return }
        for cote in [nil, 400, 104] as [Int?] {
            let image = ImagesDofusDB.decoder(jpeg, cote: cote)
            Sortie.dire("image — vue de carte, côté \(cote.map(String.init) ?? "entier") : \(image?.width ?? 0) px, "
                        + "\((image.map { $0.bytesPerRow * $0.height } ?? 0) / 1024) Ko décodés, "
                        + "\(Self.chrono { _ = ImagesDofusDB.decoder(jpeg, cote: cote) })")
        }
    }

    private final class Stockage: PreferencesStore {
        private(set) var ecritures = 0
        func donnees(pour _: String) -> Data? { nil }
        func enregistrer(_: Data, pour _: String) { ecritures += 1 }
    }

    @Test("Coches : une écriture des réglages, une coche, une lecture du suivi", .enabled(if: chemin != nil))
    @MainActor
    func coches() throws {
        let stockage = Stockage()
        let prefs = Preferences.forTesting(store: stockage)
        // Deux cents quêtes suivies, dix objectifs cochés chacune.
        let suivies = Array(try Self.lire().quetes.quetes.prefix(200)).map(\.id)
        prefs.quetesValides = Dictionary(uniqueKeysWithValues: suivies.map { (String($0), Array(1...10)) })
        Sortie.dire("coches — une écriture des réglages : \(Self.chrono(20) { prefs.quetesCompact.toggle() })")
        var objectif = 100
        let avant = stockage.ecritures
        let coche = Self.chrono(20) {
            objectif += 1
            prefs.mettreEnCours(objectif, de: suivies[0])
            prefs.cocher(objectif, de: suivies[0], true)
        }
        Sortie.dire("coches — mise en cours puis coche : \(coche), \((stockage.ecritures - avant) / 20) écritures")
        let lues = suivies.prefix(10).map { SuiviQuetes.Reconnue(id: $0, etape: nil, etapeSure: false, aFaire: [], faits: [500]) }
        let ecrites = stockage.ecritures
        Sortie.dire("coches — lecture du suivi de dix quêtes : \(Self.chrono(1) { prefs.appliquer(lues) }), "
                    + "\(stockage.ecritures - ecrites) écriture")
    }

    /// Ce que coûte un trajet copié, zaap compris (`ZaapClipboard.Couts`).
    private static func cout(_ depart: (x: Int, y: Int), _ cible: (x: Int, y: Int)) -> Int {
        ItineraireZaap.cartes(depuis: depart, vers: cible,
                              zaap: ItineraireZaap.zaap(vers: cible, parmi: zaaps, zaapDuJeu: true), gainMinimal: 5)
    }

    /// Ce que calcule `ZaapClipboard.tournee`, sans le perso devant ni la garde.
    private static func tournee(_ cases: [(id: Int, x: Int, y: Int)]) -> [Int] {
        let depart = (x: position.x, y: position.y)
        let parId = Dictionary(uniqueKeysWithValues: cases.map { ($0.id, (x: $0.x, y: $0.y)) })
        let zaapDe = parId.mapValues { ItineraireZaap.zaap(vers: $0, parmi: zaaps, zaapDuJeu: true) }
        func cout(_ depuis: (x: Int, y: Int), _ vers: Int) -> Int {
            ItineraireZaap.cartes(depuis: depuis, vers: parId[vers]!, zaap: zaapDe[vers] ?? nil, gainMinimal: 5)
        }
        return Tournee.ordre(cases.map(\.id), depuisLeDepart: { cout(depart, $0) }, entre: { cout(parId[$0]!, $1) })
    }
}
