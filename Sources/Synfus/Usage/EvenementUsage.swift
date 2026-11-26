// Statistiques d'utilisation : ce que Synfus compte (pur).

import Foundation
import Telemetrie

/// Tout ce que Synfus compte, et rien d'autre : la liste fermée de ce qui peut
/// partir dans un rapport (`usage.<rawValue>`). Le collecteur garde toute clé
/// en `[a-z0-9_]+` : un compteur ajouté ici passe sans le toucher.
enum EvenementUsage: String, CaseIterable, Codable, Sendable {
    // Bascules, par geste.
    case basculeRaccourci = "bascule_raccourci"
    case basculeBarre = "bascule_barre"
    case basculeMenu = "bascule_menu"
    case basculeAttention = "bascule_attention"
    case rotationRaccourci = "rotation_raccourci"
    case rotationClic = "rotation_clic"
    case session
    case equipeSuivante = "equipe_suivante"
    case rangement
    // Palette : ouverture, puis le genre de l'entrée choisie.
    case palette
    case paletteZaap = "palette_zaap"
    case paletteLieu = "palette_lieu"
    case paletteCommande = "palette_commande"
    case paletteVariable = "palette_variable"
    case palettePerso = "palette_perso"
    case paletteAction = "palette_action"
    case paletteRecent = "palette_recent"
    case paletteQuete = "palette_quete"
    case palettePNJ = "palette_pnj"
    case paletteMonstre = "palette_monstre"
    case paletteObjet = "palette_objet"
    // Outils.
    case trajetCopie = "trajet_copie"
    case trajetReecrit = "trajet_reecrit"
    case invitation
    case chasse
    case quetes
    case bossHarebourg = "boss_harebourg"
    case bossKimbo = "boss_kimbo"
    case bossToxoliath = "boss_toxoliath"
    case bossIlyzaelle = "boss_ilyzaelle"
    case bossTalKasha = "boss_tal_kasha"
    case apercu
    case apercuGrille = "apercu_grille"
    case reglages
    case miseAJour = "mise_a_jour"

    /// Le choix d'une entrée de la palette, selon son genre.
    static func palette(_ genre: EntreePalette.Genre) -> EvenementUsage {
        switch genre {
        case .zaap: return .paletteZaap
        case .lieu: return .paletteLieu
        case .commande: return .paletteCommande
        case .variable: return .paletteVariable
        case .perso: return .palettePerso
        case .action: return .paletteAction
        case .recent: return .paletteRecent
        case .quete: return .paletteQuete
        case .pnj: return .palettePNJ
        case .monstre: return .paletteMonstre
        case .objet: return .paletteObjet
        }
    }

    /// La clé du compteur : le `rawValue`, déjà en `[a-z0-9_]+` (un test le vérifie
    /// pour chaque cas, la conversion ne change donc rien).
    var cle: CleDeTelemetrie { CleDeTelemetrie(convertissant: rawValue) }

    static func boss(_ boss: Boss) -> EvenementUsage {
        switch boss {
        case .harebourg: return .bossHarebourg
        case .kimbo: return .bossKimbo
        case .toxoliath: return .bossToxoliath
        case .ilyzaelle: return .bossIlyzaelle
        case .talKasha: return .bossTalKasha
        }
    }
}

