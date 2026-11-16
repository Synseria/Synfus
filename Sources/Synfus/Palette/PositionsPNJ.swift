import CoreGraphics

/// Une position d'un PNJ, prête à se montrer en carte : où, ce qu'il y a à y faire, ce qu'il en coûte
/// d'y aller. `entree` est la carte telle que la grille des zaaps la dessine (`CarteZaap`).
struct PositionPNJ: Equatable, Identifiable, Sendable {
    let position: PNJ.Position
    let entree: EntreePalette
    /// Les noms des quêtes qui le placent ici, par ordre alphabétique.
    let quetes: [String]
    /// Le trajet copié, dit en clair (« 3 cartes via Village d'Amakna ») ; `nil` : position du perso inconnue.
    let itineraire: String?

    var id: PNJ.Position { position }
}

/// L'ordre des positions d'un PNJ et la carte « habituelle ». Pur.
enum OrdrePositions {
    struct Candidat: Equatable, Sendable {
        /// Le rang de la position parmi celles du PNJ, la plus citée d'abord.
        let rang: Int
        /// Les cartes à traverser depuis le perso, zaap compris ; `nil` : inconnu.
        let cout: Int?
        /// Les fois où l'on est allé à cette position, et le rang du dernier choix (`FrequentationPalette`).
        let fois: Int
        let dernier: Int
    }

    /// Les positions les plus fréquentées d'abord, puis du moins au plus coûteux ; à égalité, la plus citée.
    /// Il n'y a pas de favori par position : un favori est celui du PNJ.
    static func trier(_ candidats: [Candidat]) -> [Candidat] {
        candidats.sorted { a, b in
            if a.fois != b.fois { return a.fois > b.fois }
            if a.fois > 0, a.dernier != b.dernier { return a.dernier > b.dernier }
            if let ordre = ScorePalette.plusProche(a.cout, b.cout) { return ordre }
            return a.rang < b.rang
        }
    }

    /// Celle qu'on a le plus choisie ; sans habitude, la plus citée par les quêtes. `nil` : aucune position.
    static func habituelle(_ candidats: [Candidat]) -> Int? {
        let frequentees = candidats.filter { $0.fois > 0 }
        let choisie = frequentees.isEmpty
            ? candidats.min { $0.rang < $1.rang }
            : frequentees.max { ($0.fois, $0.dernier) < ($1.fois, $1.dernier) }
        return choisie?.rang
    }
}

/// Comment les cartes d'une rangée se partagent la largeur : une seule prend tout, deux la moitié,
/// trois le tiers ; au-delà, des tiers et un défilement, la carte suivante entamée au bord droit pour
/// dire qu'il y en a d'autres. Pur.
enum DispositionPositions {
    /// La part d'une carte entamée au bord droit quand la rangée défile.
    static let entamee: CGFloat = 0.3

    /// Combien de cartes tiennent en entier.
    static func entieres(_ nombre: Int) -> Int { min(max(nombre, 1), 3) }

    /// La largeur d'une carte pour `nombre` cartes dans `disponible`, `interstice` entre deux.
    static func largeur(nombre: Int, disponible: CGFloat, interstice: CGFloat) -> CGFloat {
        let entieres = CGFloat(entieres(nombre))
        // Un interstice entre deux cartes ; quand la rangée défile, un de plus avant la carte entamée.
        let interstices = nombre > 3 ? entieres : entieres - 1
        let part = nombre > 3 ? entieres + entamee : entieres
        return max((disponible - interstices * interstice) / part, 0)
    }

    /// La rangée défile : plus de cartes que de places entières.
    static func defile(_ nombre: Int) -> Bool { nombre > 3 }
}

extension PNJ {
    /// Ce qu'une position retenue dans les habitudes s'appelle : sa case, sous le PNJ.
    static func cle(_ id: Int, en position: Position) -> String { prefixeCle + "\(id):\(position.x),\(position.y)" }
}

extension RecherchePalette {
    /// Les positions d'un PNJ en cartes, dans l'ordre de `OrdrePositions`. La carte « habituelle » n'est
    /// dite que s'il y en a plusieurs.
    static func positions(de pnj: Int, _ contexte: ContextePalette) -> [PositionPNJ] {
        guard let quetes = contexte.quetes, let pnj = quetes.pnjs.first(where: { $0.id == pnj }) else { return [] }
        let citees = Set(pnj.passages.flatMap(\.quetes))
        let noms = Dictionary(quetes.quetes.lazy.filter { citees.contains($0.id) }
            .map { ($0.id, Lieu.traduit($0.noms, contexte.langue) ?? "?") }, uniquingKeysWith: { a, _ in a })
        let trajets = pnj.passages.map { versCase($0, contexte) }
        let candidats = pnj.passages.indices.map { rang in
            let compte = contexte.frequentation.comptes[PNJ.cle(pnj.id, en: pnj.passages[rang].position)]
            return OrdrePositions.Candidat(rang: rang, cout: trajets[rang].trajet?.cartes,
                                           fois: compte?.fois ?? 0, dernier: compte?.dernier ?? 0)
        }
        let habituelle = pnj.passages.count > 1 ? OrdrePositions.habituelle(candidats) : nil
        return OrdrePositions.trier(candidats).map { candidat in
            let passage = pnj.passages[candidat.rang]
            let position = passage.position
            let lieu = passage.sousZone.flatMap { quetes.sousZones[String($0)] }
            let coordonnees = Coordonnees.texte(position.x, position.y)
            let entree = EntreePalette(
                id: PNJ.cle(pnj.id, en: position), genre: .pnj,
                titre: lieu.flatMap { Lieu.traduit($0.noms, contexte.langue) } ?? coordonnees,
                sousTitre: lieu.flatMap { Lieu.traduit($0.zone, contexte.langue) },
                etiquette: candidat.rang == habituelle ? L("palette.pnj.habituelle") : nil,
                detail: coordonnees, carte: passage.carte, effet: trajets[candidat.rang].effet)
            return PositionPNJ(position: position, entree: entree,
                               quetes: passage.quetes.compactMap { noms[$0] }
                                   .sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                               itineraire: itineraire(trajets[candidat.rang].trajet, contexte.langue))
        }
    }
}
