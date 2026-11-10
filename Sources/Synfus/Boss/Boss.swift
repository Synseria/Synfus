import Foundation

/// Les boss dont la mécanique demande de réfléchir en jouant, et ce que l'aide
/// lit pour eux. Les règles viennent des guides des joueurs (Dofus pour les
/// noobs, Millenium, Papycha), relevées une fois et testées. Pur.
enum Boss: String, CaseIterable, Codable, Sendable {
    case harebourg, kimbo, toxoliath, ilyzaelle
    /// Sa valeur est la sauvegarde du boss choisi : elle ne change plus.
    case talKasha = "talKasha"

    /// Ce que l'aide lit en combat, en plus du bouton de combat qui compte les
    /// tours.
    var lectures: [GenreLecture] {
        switch self {
        case .harebourg: return [.vie, .tchat]
        case .kimbo: return [.tchat]
        case .toxoliath, .ilyzaelle, .talKasha: return []
        }
    }
}

// MARK: - Kimbo

/// Frappé en Terre ou en Eau, Kimbo passe en « Glyphe impaire » ; en Air ou
/// en Feu, en « Glyphe paire ». Le Disciple pose alors ses glyphes sur les
/// cases à distance de cette parité ; qui y commence son tour meurt, et Kimbo
/// qui y commence le sien perd 400 % de résistances dans les éléments de son
/// état (et en gagne 800 % dans les deux autres) pendant un tour.
enum Kimbo {
    enum Etat: Equatable, Sendable {
        /// Terre ou Eau.
        case impair
        /// Air ou Feu.
        case pair

        /// La parité des cases glyphées, en distance au Disciple.
        var glyphesImpairs: Bool { self == .impair }
    }

    /// Le dernier état annoncé au canal combat (« Glyphe impaire »,
    /// « Glyphe paire » ; en/es : odd/even, impar/par), de la ligne la plus
    /// récente à la plus ancienne. `nil` : rien de lu.
    static func etat(_ lignes: [String]) -> Etat? {
        for ligne in lignes.reversed() {
            let mots = Set(Ressemblance.normaliser(ligne).split(separator: " "))
            if mots.contains(where: { $0.hasPrefix("glyph") }) {
                if mots.contains("impaire") || mots.contains("impair") || mots.contains("odd") { return .impair }
                if mots.contains("paire") || mots.contains("pair") || mots.contains("even") { return .pair }
            }
            if mots.contains(where: { $0.hasPrefix("glifo") }) {
                if mots.contains("impar") { return .impair }
                if mots.contains("par") { return .pair }
            }
        }
        return nil
    }
}

// MARK: - Toxoliath

/// Cinq vagues de monstres aux tours 1, 6, 11, 16 et 21 ; à partir du tour 6,
/// « Poison Volatile » tous les quatre tours (+2 PM, −2 PA, poison, dégâts
/// subis +50 %) — d'où le conseil de le tuer avant. Toucher le Toxoliath
/// (Toxmose) empoisonne de 700 par PM utilisé pendant deux tours.
enum Toxoliath {
    static let vagues = [1, 6, 11, 16, 21]
    static let premierPoisonVolatile = 6
    static let relancePoisonVolatile = 4
    /// Le tour du coup et le suivant.
    static let dureeToxmose = 2

    static func prochaineVague(apres tour: Int) -> Int? { vagues.first { $0 > tour } }

    static func poisonVolatile(au tour: Int) -> Bool {
        tour >= premierPoisonVolatile && (tour - premierPoisonVolatile) % relancePoisonVolatile == 0
    }

    /// Le prochain Poison Volatile, ce tour compris.
    static func prochainPoisonVolatile(depuis tour: Int) -> Int {
        guard tour > premierPoisonVolatile else { return premierPoisonVolatile }
        let ecart = (tour - premierPoisonVolatile) % relancePoisonVolatile
        return ecart == 0 ? tour : tour + relancePoisonVolatile - ecart
    }

    /// Le poison de Toxmose court-il encore, le Toxoliath touché au tour `coup` ?
    static func toxmose(toucheAu coup: Int?, tour: Int) -> Bool {
        guard let coup else { return false }
        return tour >= coup && tour < coup + dureeToxmose
    }
}

// MARK: - Ilyzaelle

/// À 75 % puis à 50 % de sa vie maximale (pas d'érosion : le seuil se compte
/// sur la vie maximale), Ilyzaelle passe deux tours alliée et invulnérable et
/// pose un glyphe qui donne +400 % de dégâts finaux ; tenir deux tours après
/// le second seuil gagne le combat. « Vers les ténèbres » attire les persos en
/// ligne au tour 3, puis tous les trois tours ; des monstres sortent du
/// portail tous les trois tours.
enum Ilyzaelle {
    static let premierVersLesTenebres = 3
    static let relanceVersLesTenebres = 3
    static let dureeAlliee = 2

    enum Phase: Equatable, Sendable {
        /// Avant le seuil de 75 %.
        case premiere
        /// Alliée et invulnérable depuis le tour donné (75 %).
        case allieeA75(depuis: Int)
        /// Avant le seuil de 50 %.
        case seconde
        /// Alliée depuis le tour donné : tenir jusqu'à la fin.
        case allieeA50(depuis: Int)
        case gagnee
    }

    /// La phase au `tour`, les seuils franchis aux tours donnés.
    static func phase(seuil75: Int?, seuil50: Int?, tour: Int) -> Phase {
        if let seuil50 { return tour < seuil50 + dureeAlliee ? .allieeA50(depuis: seuil50) : .gagnee }
        guard let seuil75 else { return .premiere }
        return tour < seuil75 + dureeAlliee ? .allieeA75(depuis: seuil75) : .seconde
    }

    static func versLesTenebres(au tour: Int) -> Bool {
        tour >= premierVersLesTenebres && tour % relanceVersLesTenebres == 0
    }

    static func prochainVersLesTenebres(depuis tour: Int) -> Int {
        max(premierVersLesTenebres, (tour + relanceVersLesTenebres - 1) / relanceVersLesTenebres * relanceVersLesTenebres)
    }
}

// MARK: - Tal Kasha

/// Invulnérable tant qu'elle n'a pas commencé son tour sur les glyphes de
/// trois monstres différents — morts, ils laissent un glyphe où elle les
/// ressuscite au tour suivant. Le jeu en montre le compte au-dessus d'elle,
/// de I à III.
enum TalKasha {
    static let glyphesRequis = 3
}

// MARK: - Ce que l'aide retient d'un combat

/// Ce que le joueur a signalé ou que le tchat a dit pendant le combat en
/// cours ; un nouveau combat repart de zéro. Pur.
struct SessionBoss: Equatable, Sendable {
    var kimbo: Kimbo.Etat?
    /// Le tour où le Toxoliath a été touché, pour Toxmose.
    var toxoliathTouche: Int?
    var ilyzaelle75: Int?
    var ilyzaelle50: Int?
    var glyphesTalKasha = 0
}

// MARK: - Où le trouver, qui il est

extension Boss {
    /// Le boss chez DofusDB (`monsters`) : niveau, vie et résistances de sa fiche.
    var monstre: Int {
        switch self {
        case .harebourg: return 3416
        case .kimbo: return 1045
        case .toxoliath: return 3752
        case .ilyzaelle: return 4967
        case .talKasha: return 4744
        }
    }

    /// Son donjon, tel que Dofus pour les noobs en titre la page.
    var donjon: String {
        switch self {
        case .harebourg: return "Donjon du Comte Harebourg"
        case .kimbo: return "Canopée du Kimbo"
        case .toxoliath: return "Cave du Toxoliath"
        case .ilyzaelle: return "Belvédère d'Ilyzaelle"
        case .talKasha: return "Chambre de Tal Kasha"
        }
    }

    /// Le nom de la sous-zone de sa salle, que le jeu écrit au-dessus de la
    /// position, en fr, en et es (DofusDB : 794, 459, 831, 893, 882). Une
    /// expédition reprend le nom de la salle : « Expédition de l'Audace -
    /// Donjon du Comte Harebourg ».
    var salle: [String] {
        switch self {
        case .harebourg: return ["Donjon du Comte Harebourg", "Count Harebourg's Dungeon", "Mazmorra del Conde Kontatrás"]
        case .kimbo: return ["Canopée du Kimbo", "Kimbo's Canopy", "Canopea del Kimbo"]
        case .toxoliath: return ["Cave du Toxoliath", "Toxoliath's Cave", "Cueva de Toxoliat"]
        case .ilyzaelle: return ["Belvédère d'Ilyzaelle", "Ilyzaelle's Lookout", "Mirador de Ilyzaelle"]
        case .talKasha: return ["Chambre de Tal Kasha", "Chamber of Tal Kasha", "Cámara de Tal Kasha"]
        }
    }

    /// Les écorchures de l'OCR tolérées dans le nom d'une salle.
    static let fautesTolerees = 2

    /// Le boss dont la salle est nommée dans la zone lue (« Frigost (Donjon
    /// du Comte Harebourg) ») ; `nil` ailleurs, ou la zone illisible.
    static func dans(zone: String?) -> Boss? {
        guard let zone else { return nil }
        let lue = Ressemblance.Forme(Ressemblance.normaliser(zone))
        return allCases.first { boss in
            boss.salle.contains { nom in
                Ressemblance.distanceDansTexte(Ressemblance.Forme(Ressemblance.normaliser(nom)), lue,
                                               auPlus: fautesTolerees) != nil
            }
        }
    }
}
