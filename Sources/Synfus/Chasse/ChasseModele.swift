import Foundation

/// L'état du panneau de chasse : départ, direction, indice, résultat. Synfus
/// ne fait que lire l'écran et copier le trajet trouvé — le joueur colle,
/// marche et valide l'étape lui-même.
@MainActor
final class ChasseModele: ObservableObject {
    static let shared = ChasseModele()

    /// Une étape cherchée et ce qu'elle a donné, pour l'affichage : la
    /// recherche suivante remet direction et indice à zéro.
    struct Constat: Equatable {
        let cible: EtapeChasse.Cible
        let direction: Direction
        let resultat: EtapeChasse.Resultat
    }

    /// Vides tant qu'aucune position n'a été lue ni tapée : un départ inventé
    /// donnerait une étape fausse sans qu'on le voie.
    @Published var departX: Int?
    @Published var departY: Int?
    @Published private(set) var direction: Direction?
    /// La direction lue par le dernier scan, à mettre en couleur ; un choix
    /// manuel la remplace.
    @Published private(set) var directionLue: Direction?
    /// La direction a été choisie à la main sur la boussole : le prochain scan
    /// ne la change pas. Remise à zéro à l'étape suivante.
    @Published private(set) var directionManuelle = false
    @Published private(set) var cible: EtapeChasse.Cible?
    /// L'indice choisi par le dernier scan, à mettre en couleur ; une saisie
    /// ou un clic manuel le remplace.
    @Published private(set) var cibleLue = false
    /// Le champ de l'indice ; il ne propose rien tant qu'il nomme la cible.
    @Published var saisie = ""
    /// Les cibles proposées par la dernière lecture de l'écran.
    @Published private(set) var lues: [EtapeChasse.Cible] = []
    @Published private(set) var lectureEnCours = false
    /// La dernière lecture n'a rien reconnu.
    @Published private(set) var rienLu = false
    @Published private(set) var constat: Constat?
    @Published private(set) var rechercheEnCours = false
    @Published private(set) var echec: String?
    /// Le trajet du dernier résultat a été copié : la coche verte du bouton
    /// suffit, le libellé ne le répète pas.
    @Published private(set) var trajetCopie = false

    @Published private(set) var indices: [Indice] = []
    @Published private(set) var dateIndices: Date?
    @Published private(set) var chargementIndices = false
    @Published private(set) var echecIndices: String?

    private var recherche: Task<Void, Never>?
    private var historique = HistoriqueChasse()

    private init() {}

    /// Une instance de chasse, pour un perso de plus (`Chasses`) : la liste
    /// des indices se partage par le cache disque, chaque instance la relit.
    static func nouveau() -> ChasseModele { ChasseModele() }

    var departConnu: Bool { departX != nil && departY != nil }

    /// La liste des indices n'est pas encore là : rien ne se choisit.
    var enAttenteDesIndices: Bool { indices.isEmpty && echecIndices == nil }

    var attente: AttenteChasse {
        AttenteChasse(departConnu: departConnu, directionChoisie: direction != nil)
    }

    /// La phase où en est la chasse : départ à poser, étape à lire, carte à
    /// rejoindre, ou étape atteinte à valider dans le jeu.
    var phase: PhaseChasse {
        let cible: (x: Int, y: Int)? = {
            if case .trouve(let x, let y, _)? = constat?.resultat { return (x, y) }
            return nil
        }()
        let position = LecteurEcran.shared.positionDuPersoDevant.map { (x: $0.x, y: $0.y) }
        return PhaseChasse(departConnu: departConnu, cible: cible, position: position)
    }

    /// Les étapes déjà conclues (validées) **de la chasse en cours** —
    /// pour le menu horloge ; celles d'une chasse d'avant n'y sont pas.
    var etapesValidees: [HistoriqueChasse.Reprise] { historique.deLaChasseEnCours }

    var etapePrecedenteDisponible: Bool { !etapesValidees.isEmpty }

    /// Rouvre une étape passée choisie dans le menu horloge : les étapes
    /// suivantes sont retirées de l'historique, celle-ci est rouverte.
    func rouvrir(_ reprise: HistoriqueChasse.Reprise) {
        guard let i = historique.toutes.firstIndex(of: reprise) else { return }
        historique.tronquer(jusqua: i)
        etapePrecedente()
    }

    var langue: Langue { L10n.courante.langue }

    var suggestions: [EtapeChasse.Cible] {
        guard cible?.nom(en: langue) != saisie else { return [] }
        if EtapeChasse.estPhorreur(saisie) { return [.phorreur] }
        return IndicesChasse.rechercher(saisie, parmi: indices, langue: langue, limite: 6).map(EtapeChasse.Cible.indice)
    }

    #if DEBUG
    /// Un résultat et deux indices lus, pour la capture de la documentation (`CapturesTests`).
    func poserResultatPourCaptures(cible: EtapeChasse.Cible, lues: [EtapeChasse.Cible]) {
        constat = Constat(cible: cible, direction: .est, resultat: .trouve(x: -3, y: 0, distance: 1))
        historique.lire(lues + [cible])
        historique.noter(.init(departX: -2, departY: 0, direction: .est, cible: cible, cibleAtteinte: .init(x: -3, y: 0)))
        self.lues = lues
        self.cible = lues.first
        direction = .est
        directionLue = .est
        cibleLue = true
    }

    func viderPourCaptures() {
        departX = nil
        departY = nil
        constat = nil
        historique = HistoriqueChasse()
        lues = []
        cible = nil
        cibleLue = false
        directionLue = nil
    }

    /// Les indices indisponibles, pour la capture de la documentation (`CapturesTests`).
    func poserEchecPourCaptures() {
        indices = []
        echecIndices = "hors ligne"
    }
    #endif

    // MARK: - Ouverture

    /// À l'ouverture du panneau : le départ là où se tient le perso devant,
    /// la liste des indices, et la lecture de l'écran.
    func ouvrir() {
        reprendrePositionSiInconnue()
        Task {
            if indices.isEmpty { await chargerIndices() }
            lire()
        }
    }

    /// Reprend la position du perso devant — lue à l'occasion si aucune
    /// position n'est connue de ce perso (la lecture régulière de la position
    /// peut être éteinte, la chasse s'ouvre quand même dessus).
    func reprendrePositionSiInconnue() {
        guard !departConnu else { return }
        Task {
            await LecteurEcran.shared.lirePositionDevantUneFois()
            reprendrePosition()
        }
    }

    func reprendrePosition() {
        guard let position = LecteurEcran.shared.positionDuPersoDevant else { return }
        departX = position.x
        departY = position.y
    }

    /// `forcer` : le bouton des réglages, qui veut une liste neuve et la
    /// raison d'un échec.
    func chargerIndices(forcer: Bool = false) async {
        guard !chargementIndices else { return }
        chargementIndices = true
        echecIndices = nil
        do {
            let releve = try await ChasseDofusDB.indices(forcer: forcer)
            indices = releve.indices
            dateIndices = releve.date
        } catch {
            echecIndices = error.localizedDescription
        }
        chargementIndices = false
    }

    // MARK: - Lecture de l'écran

    /// Les rangs des lignes qui portent un indice de chasse — la détection des
    /// zones (`AutoCalibrage`) ; la liste des indices se charge s'il le faut.
    func rangsDIndices(_ lignes: [String]) async -> Set<Int> {
        if indices.isEmpty { await chargerIndices() }
        let indices = indices
        return await Task.detached(priority: .userInitiated) {
            Set(lignes.indices.filter { !EtapeChasse.ciblesLues(dans: [lignes[$0]], parmi: indices).isEmpty })
        }.value
    }

    /// La reconnaissance cherche chaque nom d'indice, à quelques fautes près,
    /// dans chaque ligne lue : un dixième de seconde, hors du fil principal.
    /// Le scan lit toute l'étape en cours d'un coup : la direction sur la
    /// Le scan lit toute l'étape en cours d'un coup : la direction sur la
    /// flèche de la ligne de l'indice — lue par l'OCR, sinon cherchée en pixels
    /// dans l'image de la zone (Vision écorche la flèche en triangle plein) —
    /// et l'indice de cette **même** ligne, la dernière fléchée du panneau.
    func lire() {
        guard !lectureEnCours, !indices.isEmpty else { return }
        lectureEnCours = true
        let indices = indices
        Task {
            guard let lu = await LecteurEcran.shared.lireChasseUneFois() else {
                self.lues = []
                self.rienLu = true
                self.lectureEnCours = false
                return
            }
            let (lues, etape) = await Task.detached(priority: .userInitiated) {
                let image = LumaBitmap(cgImage: lu.image)
                let lues = EtapeChasse.ciblesLues(dans: lu.lignes, parmi: indices)
                let etape = EtapeChasse.etapeLue(dans: lu.lignes, cadres: lu.cadres,
                                                 image: image, parmi: indices)
                Self.journaliserScan(lignes: lu.lignes, cadres: lu.cadres, image: image,
                                    indices: indices, etape: etape)
                return (lues, etape)
            }.value
            self.lues = lues
            // Le panneau lu dit quelles sont les étapes de la chasse en cours :
            // un panneau inconnu est une chasse neuve, l'historique repart à zéro.
            historique.lire(lues)
            rienLu = lues.isEmpty && etape.direction == nil && etape.cible == nil
            // La direction d'abord : choisir l'indice déclenche la recherche
            // dès que les deux sont là. Flèche pas lue sûrement : pas de
            // direction posée, on attend un clic. Une direction choisie à la
            // main n'est pas écrasée par le scan.
            directionLue = etape.direction
            if !directionManuelle { direction = etape.direction }
                lectureEnCours = false
            if let cible = etape.cible {
                choisir(cible, lue: true)
            }
        }
    }

    /// Journalise chaque scan de chasse (lignes lues, flèches détectées, étape
    /// retenue) dans `~/Library/Logs/Synfus/chasse.log` — pour régler la
    /// détection sur de vraies captures en résolution native.
    private nonisolated static func journaliserScan(lignes: [String], cadres: [CGRect], image: LumaBitmap?,
                                        indices: [Indice], etape: (direction: Direction?, cible: EtapeChasse.Cible?, rang: Int?)) {
        let analyse = EtapeChasse.analyser(dans: lignes, cadres: cadres, image: image)
        var texte = "=== \(Date()) | étape: dir=\(etape.direction.map { "\($0)" } ?? "-") cible=\(etape.cible.map { "\($0)" } ?? "-") rang=\(etape.rang.map { "\($0)" } ?? "-")\n"
        for a in analyse {
            let badge = a.enCours ? "EN COURS" : a.validee ? "VALIDÉ" : "-"
            let pixel = a.pixel.map { "\($0.direction):\(String(format: "%.2f", $0.score))" } ?? "-"
            texte += "  [\(badge)] glyphe=\(a.glyphe.map { "\($0)" } ?? "-") pixel=\(pixel) retenue=\(a.retenue.map { "\($0)" } ?? "-") | \(a.texte)\n"
        }
        guard let dossier = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/Synfus", isDirectory: true) else { return }
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let url = dossier.appendingPathComponent("chasse.log")
        var ancien = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let blocs = ancien.components(separatedBy: "=== ").filter { !$0.isEmpty }.map { "=== " + $0 }
        var tous = blocs + [texte]
        while tous.count > 50 { tous.removeFirst() }
        try? tous.joined().write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Étape

    func choisir(_ cible: EtapeChasse.Cible, lue: Bool = false) {
        self.cible = cible
        cibleLue = lue
        saisie = cible.nom(en: langue)
        chercherSiPret()
    }

    func choisir(_ direction: Direction) {
        guard !enAttenteDesIndices else { return }
        // Un choix manuel bloque la direction contre le prochain scan ;
        // re-cliquer dessus annule le choix : retour à la direction lue (auto).
        if directionManuelle, self.direction == direction {
            directionManuelle = false
            self.direction = directionLue
            chercherSiPret()
            return
        }
        directionManuelle = true
        directionLue = nil
        self.direction = direction
        chercherSiPret()
    }

    /// Entrée dans le champ : la première proposition ; champ vide, la
    /// lecture de l'écran — une flèche puis Entrée suffisent à une étape.
    func validerSaisie() {
        if saisie.isEmpty { return lire() }
        if let premiere = suggestions.first { choisir(premiere) } else { chercherSiPret() }
    }

    /// Une étape se cherche quand elle est complète ; le Phorreur n'a pas besoin
    /// de départ. Sans direction — aucune flèche lue sûrement au scan — on
    /// attend un clic sur la boussole : jamais de direction inventée.
    private func chercherSiPret() {
        guard let cible, cible.nom(en: langue) == saisie else { return }
        recherche?.cancel()
        echec = nil
        trajetCopie = false
        guard case .indice(let indice) = cible else {
            let reprise = HistoriqueChasse.Reprise(departX: departX, departY: departY, direction: direction ?? .est, cible: cible)
            conclure(Constat(cible: cible, direction: direction ?? .est, resultat: .phorreur), reprise: reprise)
            return
        }
        guard let x = departX, let y = departY else { return }
        if let direction {
            lancer(indice: indice, depuis: (x, y), direction: direction, cible: cible)
        }
        // Sinon, on attend un clic sur la boussole.
    }

    /// La recherche dans une direction donnée.
    private func lancer(indice: Indice, depuis: (x: Int, y: Int), direction: Direction, cible: EtapeChasse.Cible) {
        let reprise = HistoriqueChasse.Reprise(departX: depuis.x, departY: depuis.y, direction: direction, cible: cible)
        rechercheEnCours = true
        recherche = Task {
            defer { rechercheEnCours = false }
            do {
                let cartes = try await ChasseDofusDB.cartes(depuis: depuis.x, depuis.y, direction: direction)
                guard !Task.isCancelled else { return }
                conclure(Constat(cible: cible, direction: direction,
                                 resultat: EtapeChasse.resultat(indice: indice.id, cartes: cartes)), reprise: reprise)
            } catch {
                guard !Task.isCancelled else { return }
                echec = Self.messageErreur(error)
            }
        }
    }

    /// Un échec réseau se dit « hors ligne », pas un code NSURLError.
    private static func messageErreur(_ error: Error) -> String {
        if error is URLError { return L("chasse.horsLigne") }
        return error.localizedDescription
    }

    /// Une étape trouvée devient le départ de la suivante, et son trajet est
    /// copié par le seul foyer des trajets — zaap compris s'il fait gagner.
    private func conclure(_ constat: Constat, reprise: HistoriqueChasse.Reprise) {
        var reprise = reprise
        reprise.rangLu = lues.firstIndex(of: constat.cible)
        if case .trouve(let x, let y, _) = constat.resultat { reprise.cibleAtteinte = .init(x: x, y: y) }
        historique.noter(reprise)
        self.constat = constat
        // La direction reste allumée sur la boussole tant que le résultat
        // s'affiche — le prochain scan la remplacera. Le choix manuel, lui,
        // ne tient que jusqu'à l'étape suivante.
        directionManuelle = false
        cible = nil
        cibleLue = false
        saisie = ""
        lues.removeAll { $0 == constat.cible }
        if case .trouve(let x, let y, _) = constat.resultat {
            departX = x
            departY = y
            copier()
            trajetCopie = true
        }
    }

    /// Rouvre l'étape du résultat affiché : départ, direction et indice
    /// remis tels qu'ils étaient avant la recherche, résultat retiré.
    func etapePrecedente() {
        guard let reprise = historique.reprendre() else { return }
        recherche?.cancel()
        trajetCopie = false
        directionManuelle = false
        let rouverture = reprise.rouverture(departX: departX, departY: departY, lues: lues)
        departX = rouverture.departX
        departY = rouverture.departY
        lues = rouverture.lues
        direction = reprise.direction
        directionLue = nil
        cible = reprise.cible
        cibleLue = false
        saisie = reprise.cible.nom(en: langue)
        constat = nil
        echec = nil
    }

    func copier() {
        guard case .trouve(let x, let y, _) = constat?.resultat else { return }
        // Une chasse se joue dans le Monde des Douze.
        ZaapClipboard.shared.copierTrajet(vers: (x, y), sousZone: nil, dansLesDouze: true)
    }
}
