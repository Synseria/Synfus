// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json c5f3400ce23232ce · contenu 29894f4de41090a5
import SwiftUI

/// Les valeurs de design Synseria telles que Synfus les reçoit : toute couleur, taille ou durée
/// d'une vue vient d'ici, jamais d'un chiffre écrit dans la vue. Couleurs : `Nuancier.couleurs(thème, nuance)`.
enum Jetons {
    struct RVB: Sendable, Hashable {
        let hex: UInt32
        let opacite: Double
        init(_ hex: UInt32, opacite: Double = 1) {
            self.hex = hex
            self.opacite = opacite
        }
        func voile(_ opacite: Double) -> RVB { RVB(hex, opacite: opacite) }
        var couleur: Color {
            Color(.sRGB, red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255, opacity: opacite)
        }
    }
    enum Police: Sendable, Hashable { case ui, code }
    struct Typo: Sendable, Hashable {
        let graisse: Int
        let taille: CGFloat
        let interligne: CGFloat
        let police: Police
        var font: Font {
            let poids: Font.Weight = switch graisse {
            case 700: .bold
            case 600: .semibold
            case 500: .medium
            default: .regular
            }
            return .system(size: taille, weight: poids, design: police == .code ? .monospaced : .rounded)
        }
    }
    struct Courbe: Sendable, Hashable {
        let x1, y1, x2, y2: Double
        func animation(_ duree: Double) -> Animation { .timingCurve(x1, y1, x2, y2, duration: duree) }
    }
    // MARK: Espacements
    /// écart entre une icône et son libellé, entre deux touches
    static let espace1: CGFloat = 4
    /// marge d'une plaque dans la fenêtre, padding d'une rangée dans une carte
    static let espace2: CGFloat = 8
    /// padding horizontal d'une rangée, écart entre éléments d'une ligne
    static let espace3: CGFloat = 12
    /// gouttière de page, sous l'en-tête d'une page
    static let espace4: CGFloat = 16
    /// entre deux blocs d'une page, padding d'une plaque
    static let espace5: CGFloat = 24
    /// entre deux groupes d'une planche
    static let espace6: CGFloat = 32
    /// entre deux sections, haut d'un flottant sous son ancre
    static let espace7: CGFloat = 48

    // MARK: Typographie
    /// interface et titres (Rounded)
    static let policeUi = Police.ui
    /// commandes, code, touches
    static let policeCode = Police.code
    /// titre de page (« Lundi 16 novembre »)
    static let typoTitrePage = Typo(graisse: 700, taille: 28, interligne: 32, police: .ui)
    /// titre de carte ou de section
    static let typoSection = Typo(graisse: 600, taille: 17, interligne: 22, police: .ui)
    /// titre d'une fiche, d'un élément nommé
    static let typoTitreCarte = Typo(graisse: 600, taille: 14, interligne: 20, police: .ui)
    /// texte courant, rangées, boutons
    static let typoCorps = Typo(graisse: 400, taille: 14, interligne: 20, police: .ui)
    /// lecture longue (docs, overlay)
    static let typoLecture = Typo(graisse: 400, taille: 15, interligne: 24, police: .ui)
    /// ligne secondaire sous un titre, compteurs
    static let typoMeta = Typo(graisse: 400, taille: 12, interligne: 16, police: .ui)
    /// commande, bloc de code
    static let typoCode = Typo(graisse: 400, taille: 13, interligne: 20, police: .code)
    /// touches, étiquettes, axes de graphique
    static let typoMicro = Typo(graisse: 500, taille: 11, interligne: 16, police: .ui)

    // MARK: Rayons et filets
    /// touche, trou d'une commande, piste
    static let rayon0: CGFloat = 4
    /// rangée compacte, menu, fond creux
    static let rayon1: CGFloat = 8
    /// rangée, champ, fenêtre
    static let rayon2: CGFloat = 12
    /// plaque, carte, flottant ; rayon intérieur = extérieur − padding
    static let rayon3: CGFloat = 16
    /// bouton, sous-onglet, interrupteur
    static let rayonPilule: CGFloat = 999
    /// bordure d'une plaque ou d'une carte, filet entre rangées
    static let epaisseurFilet: CGFloat = 1
    /// anneau de focus au clavier
    static let epaisseurFocus: CGFloat = 2
    /// écart de l'anneau de focus
    static let decalageFocus: CGFloat = 2

    // MARK: Tailles
    /// rangée de liste, champ
    static let hauteurRangee: CGFloat = 36
    /// bouton, onglet rond, sous-onglet
    static let hauteurControle: CGFloat = 28
    /// interrupteur, badge, segment
    static let hauteurCase: CGFloat = 24
    /// piste d'un curseur
    static let hauteurPiste: CGFloat = 4
    /// case ronde d'une tâche, pouce d'interrupteur
    static let diametreRond: CGFloat = 20
    /// feux de fenêtre, coche, punaise
    static let diametreMini: CGFloat = 12
    /// pouce d'un curseur
    static let diametrePouce: CGFloat = 16
    /// icône d'interface
    static let tailleIcone: CGFloat = 16
    /// interrupteur
    static let largeurInterrupteur: CGFloat = 48
    /// barre latérale ; base des petites largeurs (menus, listes)
    static let largeurNav: CGFloat = 200
    /// feuille de confirmation ; borne de la liste d'un champ à suggestions
    static let largeurFeuille: CGFloat = 400
    /// fenêtre À propos
    static let largeurApropos: CGFloat = 340

    // MARK: Mouvement
    /// survol, pression
    static let dureeRapide: Double = 0.12
    /// bascule, apparition
    static let dureeNormale: Double = 0.2
    /// progression, changement de page
    static let dureeLente: Double = 0.32
    /// caret, progression indéterminée (TimelineView dans l'app)
    static let dureeBoucle: Double = 1.4
    /// un tour de l'indicateur d'activité
    static let dureeTour: Double = 0.8
    /// par défaut
    static let courbeStandard = Courbe(x1: 0.4, y1: 0, x2: 0.2, y2: 1)
    /// ce qui arrive (décélère)
    static let courbeSortie = Courbe(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1)
    /// ce qui s'en va (accélère)
    static let courbeEntree = Courbe(x1: 0.4, y1: 0, x2: 1, y2: 1)

    // MARK: Verre et états
    /// part du fond de fenêtre dans le verre de ce qui prend le clavier (fenêtre, palette, overlay, panneau, bloc-notes), focus ou pas : franc, le bureau flouté se voit ; une teinte sous le verre — valeur d'essai, à fixer par les essais de l'utilisateur
    static let verreOpaciteFocus: Double = 0.41
    /// verre de ce qui ne prend jamais le clavier (carte de réunion) — valeur d'essai, à fixer par les essais de l'utilisateur
    static let verreOpaciteFlottant: Double = 0.45
    /// flou derrière le verre
    static let verreFlou: CGFloat = 28
    /// contrôle désactivé
    static let opaciteDesactive: Double = 0.4
    /// contrôle pressé : il rétrécit
    static let echellePressee: Double = 0.97
    /// survol d'un contrôle neutre (bouton-icône, onglet rond) : l'encre en voile
    static let voileSurvol: Double = 0.08
    /// pression d'un contrôle neutre : l'encre en voile
    static let voilePression: Double = 0.14
    /// touche posée sur un plein : un voile de son texte
    static let voileTouche: Double = 0.18
    /// piste d'un interrupteur éteint : l'encre mêlée à la plaque
    static let pisteRepos: Double = 0.22
    /// piste d'un interrupteur éteint survolé
    static let pisteSurvol: Double = 0.32
    /// filet d'un champ survolé : l'encre mêlée au filet
    static let filetSurvol: Double = 0.35

    // MARK: Tailles — propre à Synfus
    /// écran du jeu derrière les flottants (aperçus)
    static let largeurFenetre: CGFloat = 1280
    /// palette
    static let largeurPalette: CGFloat = 660
    /// panneau des quêtes, à son ouverture
    static let largeurPanneauQuetes: CGFloat = 360
    /// panneau de chasse au trésor
    static let largeurPanneauChasse: CGFloat = 216
    /// panneau d'aide aux boss
    static let largeurPanneauBoss: CGFloat = 252
    /// fenêtre des réglages
    static let largeurReglages: CGFloat = 1120
    /// colonne d'une page de réglages
    static let largeurColonne: CGFloat = 640
    /// vignette d'une carte du jeu ; sa hauteur est hauteur-rangee
    static let largeurVignette: CGFloat = 48
}

extension Jetons {
    /// Les thèmes nommés, dans l'ordre du spectre.
    enum Coloris: String, CaseIterable, Sendable, Identifiable {
        case cerise, terracotta, abricot, ambre, miel, sauge, lagon, bleuet, lilas, prune, graphite
        var id: String { rawValue }
        var nom: String {
            switch self {
            case .cerise: "Cerise"
            case .terracotta: "Terracotta"
            case .abricot: "Abricot"
            case .ambre: "Ambre"
            case .miel: "Miel"
            case .sauge: "Sauge"
            case .lagon: "Lagon"
            case .bleuet: "Bleuet"
            case .lilas: "Lilas"
            case .prune: "Prune"
            case .graphite: "Graphite"
            }
        }
        /// Le Jour écrit du thème, dans l'ordre de `Nuancier.Valeurs`.
        var jour: [UInt32] {
            switch self {
            case .cerise: [0xF8EEF0, 0xFFFFFF, 0xE9D0D5, 0x26171A, 0x744E54, 0x9F898D, 0xE63754, 0x220B0F, 0xA1273B, 0xF3E5E7]
            case .terracotta: [0xF9EFEA, 0xFFFFFF, 0xEBD3C8, 0x2D1D18, 0x735A51, 0xA08980, 0xD9694A, 0xFFF7F3, 0xA8402A, 0xF6E5DC]
            case .abricot: [0xFBF3EC, 0xFFFFFF, 0xEFDDCD, 0x2B2119, 0x6E5E52, 0x9C8C80, 0xEC9A6C, 0x2B1608, 0xA24B1E, 0xF9EDE2]
            case .ambre: [0xFBF3E0, 0xFFFFFF, 0xEFDDB5, 0x2B2110, 0x6B5A38, 0x9A8A64, 0xE09A1C, 0x2B1700, 0x8F5600, 0xF8EACA]
            case .miel: [0xFBF8DE, 0xFFFFFF, 0xEEE8B2, 0x29260A, 0x656030, 0x948F5C, 0xF0D030, 0x2B2600, 0x7A6C00, 0xF8F2C6]
            case .sauge: [0xF3F5EC, 0xFFFFFF, 0xE0E6D3, 0x1F2619, 0x566150, 0x868F7F, 0x7DA689, 0x12210F, 0x3F6B4D, 0xEAEFE0]
            case .lagon: [0xEDF6F3, 0xFFFFFF, 0xD2E6E0, 0x15262A, 0x4E6568, 0x7F9598, 0x3FB0A4, 0x04201D, 0x0E766C, 0xE1F0EC]
            case .bleuet: [0xEFF4FA, 0xFFFFFF, 0xD5E1F0, 0x14202E, 0x4D6078, 0x8095AD, 0x6E9FDC, 0x07182E, 0x2F66AE, 0xE3EDF8]
            case .lilas: [0xF5F1FA, 0xFFFFFF, 0xE0D8EE, 0x221B2E, 0x5E5470, 0x8F86A1, 0x9C84D6, 0x140A2B, 0x6B4FB0, 0xEEE7F8]
            case .prune: [0xFAF0F4, 0xFFFFFF, 0xEDD5DF, 0x2A1822, 0x6E5663, 0x9C8591, 0xC0608F, 0xFFFFFF, 0x9A3A69, 0xF6E4EC]
            case .graphite: [0xF2F3F4, 0xFFFFFF, 0xDADCDF, 0x171D26, 0x525E6F, 0x89929F, 0x6B7480, 0xFFFFFF, 0x4B515A, 0xEBECED]
            }
        }
        /// L'accent des nuances sombres.
        var accentSombre: UInt32 {
            switch self {
            case .cerise: 0xEE7387
            case .terracotta: 0xE8805F
            case .abricot: 0xF2A27C
            case .ambre: 0xF0AE3E
            case .miel: 0xF4DA52
            case .sauge: 0xA6CDAF
            case .lagon: 0x5ED0C3
            case .bleuet: 0x8DB6EC
            case .lilas: 0xB8A2EC
            case .prune: 0xE58CB5
            case .graphite: 0x979EA6
            }
        }
    }

    /// La lumière de l'app, du plus clair au plus sombre.
    enum Nuance: String, CaseIterable, Sendable, Identifiable {
        case jour, crepuscule, penombre, nuit
        var id: String { rawValue }
        var nom: String {
            switch self {
            case .jour: "Jour"
            case .crepuscule: "Crépuscule"
            case .penombre: "Pénombre"
            case .nuit: "Nuit"
            }
        }
        /// Les contrôles du système (menus, champs) se dessinent sombres.
        var sombre: Bool { self == .penombre || self == .nuit }
        /// « Suivre le système » : la nuance selon l'apparence du Mac.
        static func duSysteme(sombre: Bool) -> Nuance { sombre ? .penombre : .jour }
    }

    static let themeParDefaut = Theme.coloris(.lagon)
    /// nil : la nuance suit le système.
    static let nuanceParDefaut: Nuance? = nil
    static let personnaliseParDefaut: UInt32 = 0x3FA9D8

    /// Les réglages du calcul des couleurs (`couleur.calcul` de jetons.json).
    enum Parametres {
        static let nomPersonnalise = "Personnalisé"
        enum Personnalise {
            static let couleur = Octets(0x3FA9D8)
            static let saturation: [Double] = [8, 85]
            static let clarte: [Double] = [44, 66]
            static let saturationCurseurMin: Double = 40
        }
        static let tauxSelection: Double = 18
        enum Choix {
            static func part(_ nuance: Nuance) -> Double {
                switch nuance {
                case .jour: 18
                case .crepuscule: 18
                case .penombre: 18
                case .nuit: 16
                }
            }
            static let partSurvol: Double = 40
            static let pas: Double = 2
            static let max: Double = 40
            static let contrasteChoixSurvol: Double = 1.1
            static let contrasteSurvolFond: Double = 1.04
        }
        static let creux: Double = 8
        enum Seuils {
            static let encre: Double = 7.3
            static let encre2: Double = 4.8
            static let accentTexte: Double = 4.8
            static let semantiques: Double = 4.8
            static let texteSurAccent: Double = 4.6
            static let texteSurAccentPlancher: Double = 4.5
            static let texteSurEtat: Double = 4.5
            static let texteSurVerre: Double = 3
        }
        static let pasRenfort: Double = 0.05
        static let pasTexteSurAccent: Double = 0.06
        static let iterationsMax: Double = 80
        static let texteFonce = Octets(0x0B0B0B)
        enum Semantiques {
            enum Clair {
                static let danger: [Double] = [4, 68, 44]
                static let succes: [Double] = [150, 60, 32]
                static let avertissement: [Double] = [36, 92, 34]
                static let info: [Double] = [212, 72, 42]
            }
            enum Sombre {
                static let danger: [Double] = [4, 80, 70]
                static let succes: [Double] = [150, 50, 62]
                static let avertissement: [Double] = [40, 85, 62]
                static let info: [Double] = [212, 85, 72]
            }
        }
        enum Chroma {
            static let diviseur: Double = 62
            static let min: Double = 0.12
        }
        static let texteSurAccentSombre: [Double] = [60, 8]
        enum JourEngendre {
            enum SaturationFond {
                static let facteur: Double = 0.5
                static let min: Double = 7
                static let max: Double = 42
            }
            static let clarteFondFenetre: Double = 95.3
            static let clarteFondTeinte: Double = 92.6
            static let plaque = Octets(0xFFFFFF)
            static let filet: [Double] = [0.9, 86.5]
            static let encre: [Double] = [24, 12]
            static let encre2: [Double] = [14, 0.15, 38]
            static let encre3: [Double] = [10, 58]
            static let texteSurAccentFonce: [Double] = [50, 9]
            static let accentTexteVersNoir: Double = 0.3
            static let accentSombreVersBlanc: Double = 0.3
        }
        enum Crepuscule {
            static let fondFenetre = Melange(de: Octets(0xD9D3C9), part: 0.05)
            static let plaque = Melange(de: Octets(0xE7E2D9), part: 0.03)
            static let filet = Melange(de: Octets(0xBDB5A7), part: 0.12)
            static let encre = Melange(de: Octets(0x16130F), part: 0.08)
            static let encre2 = Melange(de: Octets(0x4A4339), part: 0.1)
            static let encre3 = Melange(de: Octets(0x70685B), part: 0.1)
            static let fondTeinte: Double = 0.14
        }
        enum Penombre {
            static let fondFenetre = Melange(de: Octets(0x34302D), part: 0.04)
            static let plaque = Melange(de: Octets(0x3F3A36), part: 0.04)
            static let filet = Octets(0x5C554E)
            static let encre = Octets(0xEFE8DC)
            static let encre2 = Octets(0xC6BDB0)
            static let encre3 = Octets(0x9A9185)
            static let accent = Melange(de: Octets(0x34302D), part: 0.08)
        }
        enum Nuit {
            static let saturation: [Double] = [6, 22]
            static let fondFenetre: [Double] = [1, 0, 10.5]
            static let plaque: [Double] = [1, 0, 14]
            static let filet: [Double] = [0.9, 0, 24]
            static let encre: [Double] = [0.4, 6, 92]
            static let encre2: [Double] = [0.35, 4, 73]
            static let encre3: [Double] = [0.3, 4, 55]
        }
        enum Graphiques {
            static let seuil: Double = 3
            static let decalages: [[Double]] = [[0, 180, 60, 240, 120, 300], [0, 200, 100, 300, 50, 250], [0, 120, 240, 60, 180, 300], [0, 160, 320, 80, 240, 40]]
            enum Clair {
                static let saturation: Double = 64
                static let clartes: [Double] = [0, 38, 52, 36, 50, 40]
            }
            enum Sombre {
                static let saturation: Double = 62
                static let clartes: [Double] = [0, 76, 62, 78, 64, 74]
            }
            static let sequentielle: [Double] = [0.16, 0.36, 0.56, 0.78, 1]
            static let neutreDivergente: Double = 0.25
        }
        enum Melanges {
            static let accentSurvol: Double = 14
            static let accentPresse: Double = 28
            static let dangerSurvol: Double = 14
            static let dangerPresse: Double = 28
        }
    }

    /// Les couleurs propres à Synfus.
    enum Propres {
        static func suggestionSynfus(_ nuance: Nuance) -> RVB { nuance.sombre ? RVB(0x9E73F2) : RVB(0x7C4DE0) }
    }
}

// Le calcul des couleurs de modele/couleur.js, porté pas à pas : chaque mélange revient à l'octet
// comme dans la page, sinon un seuil bascule d'un cran. Aucun réglage ici : tous viennent de
// `Parametres` (jetons.json). outils/test_swift.py compare ce calcul à la page, rôle par rôle.

extension Jetons {
    /// Le thème de l'app : un des thèmes nommés, ou Personnalisé, engendré d'une seule couleur.
    enum Theme: Hashable, Sendable {
        case coloris(Coloris)
        case personnalise(UInt32)

        var nom: String {
            switch self {
            case .coloris(let c): c.nom
            case .personnalise: Parametres.nomPersonnalise
            }
        }
    }

    /// Les couleurs d'un thème dans une nuance, nommées par leur rôle (`couleur.roles` de jetons.json).
    struct Couleurs: Hashable, Sendable {
        let fondFenetre, plaque, filet, encre, encre2, encre3: RVB
        let accent, texteSurAccent, accentTexte, fondTeinte: RVB
        let danger, texteSurDanger, succes, avertissement, info, creux: RVB
        /// Survol et pression d'un plein : mêlés de l'encre ou du fond, celui qui s'écarte de son texte.
        let accentSurvol, accentPresse, dangerSurvol, dangerPresse: RVB
        /// Le choix : sa teinte, sa part et celle du survol (en %).
        let teinteChoix: RVB
        let partChoix, partSurvol: Double

        /// Une carte a le fond de la plaque : elle s'en distingue par son filet.
        var carte: RVB { plaque }
        var selection: RVB { teinteChoix.voile(partChoix / 100) }
        var survol: RVB { teinteChoix.voile(partSurvol / 100) }
    }

    /// Les palettes de données d'un thème dans une nuance : catégorielle (distincte en protanopie et
    /// deutéranopie), séquentielle (plaque → première catégorie), divergente (danger → succès).
    struct Graphiques: Hashable, Sendable {
        let categorielle, sequentielle, divergente: [RVB]
        /// Le pire contraste d'une catégorie sur la plaque, et l'écart (ΔE OKLab × 100) entre voisines.
        let contraste, ecartNormal, ecartDaltonien: Double
    }

    enum Nuancier {
        static func couleurs(_ theme: Theme, _ nuance: Nuance) -> Couleurs {
            let v = valeurs(theme, nuance)
            return Couleurs(
                fondFenetre: v.fondFenetre.rvb, plaque: v.plaque.rvb, filet: v.filet.rvb, encre: v.encre.rvb,
                encre2: v.encre2.rvb, encre3: v.encre3.rvb, accent: v.accent.rvb, texteSurAccent: v.texteSurAccent.rvb,
                accentTexte: v.accentTexte.rvb, fondTeinte: v.fondTeinte.rvb, danger: v.danger.rvb,
                texteSurDanger: v.texteSurDanger.rvb, succes: v.succes.rvb, avertissement: v.avertissement.rvb, info: v.info.rvb,
                creux: v.creux.rvb, accentSurvol: v.accentSurvol.rvb, accentPresse: v.accentPresse.rvb,
                dangerSurvol: v.dangerSurvol.rvb, dangerPresse: v.dangerPresse.rvb, teinteChoix: v.teinteChoix.rvb, partChoix: v.partChoix, partSurvol: v.partSurvol)
        }

        static func graphiques(_ theme: Theme, _ nuance: Nuance) -> Graphiques {
            graphiques(valeurs(theme, nuance), clair: !nuance.sombre)
        }

        // MARK: - Les formules de la page

        /// Les rôles en cours de calcul ; les dix premiers dans l'ordre où un thème écrit son Jour.
        struct Valeurs {
            var fondFenetre, plaque, filet, encre, encre2, encre3, accent, texteSurAccent, accentTexte, fondTeinte: Octets
            var danger = Octets.noir, succes = Octets.noir, avertissement = Octets.noir, info = Octets.noir
            var texteSurDanger = Octets.noir, creux = Octets.noir, teinteChoix = Octets.noir
            var accentSurvol = Octets.noir, accentPresse = Octets.noir, dangerSurvol = Octets.noir, dangerPresse = Octets.noir
            var partChoix = 0.0, partSurvol = 0.0

            init(_ v: [Octets]) {
                (fondFenetre, plaque, filet, encre, encre2) = (v[0], v[1], v[2], v[3], v[4])
                (encre3, accent, texteSurAccent, accentTexte, fondTeinte) = (v[5], v[6], v[7], v[8], v[9])
            }

            var surfaces: [Octets] { [fondFenetre, plaque, fondTeinte] }
            var selections: [Octets] {
                [plaque, fondTeinte, fondFenetre].map { Octets.melange($0, accent, Parametres.tauxSelection / 100) }
            }
            /// Le fond d'une rangée choisie, sur la fenêtre et sur la plaque.
            var choisis: [Octets] { [fondFenetre, plaque].map { Octets.melange($0, teinteChoix, partChoix / 100) } }
        }

        /// Le choix : en clair l'accent foncé (un accent clair teint sans assombrir), en sombre l'accent ;
        /// sa part monte par pas jusqu'à ce que choix et survol se distinguent, et le survol du fond.
        static func doserChoix(_ v: inout Valeurs, clair: Bool, nuance: Nuance) {
            typealias X = Parametres.Choix
            let t = clair ? v.accentTexte : v.accent
            func distincts(_ p: Double) -> Bool {
                [v.fondFenetre, v.plaque].allSatisfy { f in
                    let choix = Octets.melange(f, t, p / 100), survol = Octets.melange(f, t, p / 100 * (X.partSurvol / 100))
                    return Octets.contraste(choix, survol) >= X.contrasteChoixSurvol && Octets.contraste(survol, f) >= X.contrasteSurvolFond
                }
            }
            var p = X.part(nuance)
            while !distincts(p), p < X.max { p += X.pas }
            (v.teinteChoix, v.partChoix, v.partSurvol) = (t, p, p * X.partSurvol / 100)
        }

        /// `finir` : chaque encre va vers le noir (clair) ou le blanc (sombre) jusqu'à son seuil.
        static func finir(_ depart: Valeurs, clair: Bool, nuance: Nuance) -> Valeurs {
            typealias S = Parametres.Seuils
            var v = depart
            doserChoix(&v, clair: clair, nuance: nuance)
            (v.danger, v.succes, v.avertissement, v.info) = semantiques(clair: clair)
            let vers = clair ? Octets.noir : Octets.blanc
            let fonds = v.surfaces, tous = fonds + v.selections
            v.encre = Octets.renforcer(v.encre, fonds, S.encre, vers: vers)
            v.encre2 = Octets.renforcer(v.encre2, tous, S.encre2, vers: vers)
            v.accentTexte = Octets.renforcer(Octets.renforcer(v.accentTexte, tous, S.accentTexte, vers: vers), v.choisis, S.accentTexte, vers: vers)
            v.danger = Octets.renforcer(v.danger, fonds, S.semantiques, vers: vers)
            v.succes = Octets.renforcer(v.succes, fonds, S.semantiques, vers: vers)
            v.avertissement = Octets.renforcer(v.avertissement, fonds, S.semantiques, vers: vers)
            v.info = Octets.renforcer(v.info, fonds, S.semantiques, vers: vers)
            let texte = Octets.contraste(.noir, v.accent) > Octets.contraste(.blanc, v.accent) ? Octets.noir : Octets.blanc
            var n = 0.0
            while Octets.contraste(v.texteSurAccent, v.accent) < S.texteSurAccent, n < Parametres.iterationsMax {
                v.texteSurAccent = Octets.melange(v.texteSurAccent, texte, Parametres.pasTexteSurAccent)
                n += 1
            }
            // Un accent de clarté moyenne (un rouge vif, un gris) plafonne avec le noir comme avec le
            // blanc : c'est lui qui s'écarte alors du texte (seuls des Personnalisé y passent).
            n = 0
            while Octets.contraste(v.texteSurAccent, v.accent) < S.texteSurAccentPlancher, n < Parametres.iterationsMax {
                v.accent = Octets.melange(v.accent, texte == .noir ? .blanc : .noir, Parametres.pasRenfort)
                n += 1
            }
            v.texteSurDanger = Octets.texteSur(v.danger)
            etats(&v)
            v.creux = Octets.melange(v.fondTeinte, v.encre, Parametres.creux / 100)
            return v
        }

        /// Survol et pression d'un plein (accent, danger) : il se mêle de l'encre ou du fond, celui qui
        /// s'écarte le plus de son texte. Vers l'encre seule, un accent clair au texte foncé (Jour,
        /// Crépuscule) s'assombrirait vers son propre texte, sous 4,5:1.
        static func etats(_ v: inout Valeurs) {
            typealias M = Parametres.Melanges
            func pole(_ texte: Octets) -> Octets {
                Octets.contraste(v.encre, texte) >= Octets.contraste(v.fondFenetre, texte) ? v.encre : v.fondFenetre
            }
            let (a, d) = (pole(v.texteSurAccent), pole(v.texteSurDanger))
            v.accentSurvol = Octets.melange(v.accent, a, M.accentSurvol / 100)
            v.accentPresse = Octets.melange(v.accent, a, M.accentPresse / 100)
            v.dangerSurvol = Octets.melange(v.danger, d, M.dangerSurvol / 100)
            v.dangerPresse = Octets.melange(v.danger, d, M.dangerPresse / 100)
        }

        static func semantiques(clair: Bool) -> (Octets, Octets, Octets, Octets) {
            typealias C = Parametres.Semantiques.Clair
            typealias F = Parametres.Semantiques.Sombre
            return clair ? (Octets.tsl(C.danger), Octets.tsl(C.succes), Octets.tsl(C.avertissement), Octets.tsl(C.info))
                : (Octets.tsl(F.danger), Octets.tsl(F.succes), Octets.tsl(F.avertissement), Octets.tsl(F.info))
        }

        /// Une nuance d'un thème : le Jour écrit (ou engendré), les trois autres calculées.
        static func valeurs(_ theme: Theme, _ nuance: Nuance) -> Valeurs {
            let (jour, sombre) = source(theme)
            let a = jour.accent
            let (h, saturation, _) = a.tsl
            typealias Ch = Parametres.Chroma
            let k = max(Ch.min, min(1, saturation / Ch.diviseur))
            let surAccentSombre = Octets.tsl(h, Parametres.texteSurAccentSombre[0], Parametres.texteSurAccentSombre[1])
            switch nuance {
            case .jour:
                return finir(jour, clair: true, nuance: nuance)
            case .crepuscule:
                typealias K = Parametres.Crepuscule
                func m(_ x: Melange) -> Octets { Octets.melange(x.de, a, x.part) }
                let fond = m(K.fondFenetre)
                return finir(Valeurs([fond, m(K.plaque), m(K.filet), m(K.encre), m(K.encre2), m(K.encre3), a,
                                      jour.texteSurAccent, jour.accentTexte, Octets.melange(fond, a, K.fondTeinte)]), clair: true, nuance: nuance)
            case .penombre:
                typealias P = Parametres.Penombre
                let fond = Octets.melange(P.fondFenetre.de, sombre, P.fondFenetre.part)
                return finir(Valeurs([fond, Octets.melange(P.plaque.de, sombre, P.plaque.part), P.filet, P.encre, P.encre2,
                                      P.encre3, Octets.melange(sombre, P.accent.de, P.accent.part), surAccentSombre, sombre,
                                      fond]), clair: false, nuance: nuance)
            case .nuit:
                typealias N = Parametres.Nuit
                let s = N.saturation[0] + N.saturation[1] * k
                func n(_ r: [Double]) -> Octets { Octets.tsl(h, s * r[0] + r[1], r[2]) }
                return finir(Valeurs([n(N.fondFenetre), n(N.plaque), n(N.filet), n(N.encre), n(N.encre2), n(N.encre3),
                                      sombre, surAccentSombre, sombre, n(N.fondFenetre)]), clair: false, nuance: nuance)
            }
        }

        /// Le Jour brut d'un thème et son accent sombre.
        static func source(_ theme: Theme) -> (Valeurs, Octets) {
            switch theme {
            case .coloris(let c):
                return (Valeurs(c.jour.map(Octets.init)), Octets(c.accentSombre))
            case .personnalise(let couleur):
                return personnalise(Octets(couleur))
            }
        }

        /// Personnalisé : un Jour engendré d'une seule couleur (teinte, saturation, clarté bornées).
        static func personnalise(_ couleur: Octets) -> (Valeurs, Octets) {
            typealias P = Parametres.Personnalise
            typealias G = Parametres.JourEngendre
            let (h, s0, l0) = couleur.tsl
            let s = max(P.saturation[0], min(P.saturation[1], s0)), l = max(P.clarte[0], min(P.clarte[1], l0))
            let bs = max(G.SaturationFond.min, min(s * G.SaturationFond.facteur, G.SaturationFond.max))
            let accent = Octets.tsl(h, s, l)
            let surAccent = Octets.contraste(.noir, accent) > Octets.contraste(.blanc, accent)
                ? Octets.tsl(h, G.texteSurAccentFonce[0], G.texteSurAccentFonce[1]) : Octets.blanc
            let jour = Valeurs([
                Octets.tsl(h, bs, G.clarteFondFenetre), G.plaque, Octets.tsl(h, bs * G.filet[0], G.filet[1]),
                Octets.tsl(h, G.encre[0], G.encre[1]), Octets.tsl(h, G.encre2[0] + bs * G.encre2[1], G.encre2[2]),
                Octets.tsl(h, G.encre3[0], G.encre3[1]), accent, surAccent,
                Octets.melange(accent, .noir, G.accentTexteVersNoir), Octets.tsl(h, bs, G.clarteFondTeinte),
            ])
            return (jour, Octets.melange(accent, .blanc, G.accentSombreVersBlanc))
        }

        // MARK: - Graphiques

        static func graphiques(_ v: Valeurs, clair: Bool) -> Graphiques {
            typealias G = Parametres.Graphiques
            let (saturation, clartes) = clair ? (G.Clair.saturation, G.Clair.clartes) : (G.Sombre.saturation, G.Sombre.clartes)
            let fonds = [v.plaque], vers = clair ? Octets.noir : Octets.blanc, h = v.accent.tsl.0
            var meilleur: (cat: [Octets], daltonien: Double, normal: Double)?
            for o in G.decalages {
                var c = [Octets.renforcer(v.accent, fonds, G.seuil, vers: vers)]
                for i in 1..<6 {
                    let teinte = (h + o[i]).truncatingRemainder(dividingBy: 360)
                    c.append(Octets.renforcer(Octets.tsl(teinte, saturation, clartes[i]), fonds, G.seuil, vers: vers))
                }
                var daltonien = 99.0, normal = 99.0
                for i in 0..<5 {
                    daltonien = min(daltonien, Oklab.ecart(c[i], c[i + 1], .deuteranopie), Oklab.ecart(c[i], c[i + 1], .protanopie))
                    normal = min(normal, Oklab.ecart(c[i], c[i + 1], nil))
                }
                if meilleur == nil || daltonien > meilleur!.daltonien { meilleur = (c, daltonien, normal) }
            }
            let m = meilleur!
            let neutre = Octets.melange(v.plaque, v.encre2, G.neutreDivergente)
            return Graphiques(
                categorielle: m.cat.map(\.rvb),
                sequentielle: G.sequentielle.map { Octets.melange(v.plaque, m.cat[0], $0).rvb },
                divergente: [v.danger, Octets.melange(v.danger, neutre, 0.5), neutre, Octets.melange(v.succes, neutre, 0.5), v.succes].map(\.rvb),
                contraste: m.cat.map { Octets.contraste($0, v.plaque) }.min() ?? 0,
                ecartNormal: m.normal, ecartDaltonien: m.daltonien)
        }
    }

    /// OKLab, et la simulation des daltonismes (Machado 2009, sévérité 1), pour l'écart des catégories.
    enum Oklab {
        enum Vision { case deuteranopie, protanopie }

        static func ecart(_ a: Octets, _ b: Octets, _ vision: Vision?) -> Double {
            let x = lab(a, vision), y = lab(b, vision)
            return 100 * ((x[0] - y[0]) * (x[0] - y[0]) + (x[1] - y[1]) * (x[1] - y[1]) + (x[2] - y[2]) * (x[2] - y[2])).squareRoot()
        }

        static func lab(_ o: Octets, _ vision: Vision?) -> [Double] {
            func lineaire(_ x: Int) -> Double {
                let v = Double(x) / 255
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            var c = [lineaire(o.r), lineaire(o.v), lineaire(o.b)]
            if let vision {
                let m = vision == .deuteranopie
                    ? [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.01182, 0.04294, 0.968881]]
                    : [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]
                c = m.map { $0[0] * c[0] + $0[1] * c[1] + $0[2] * c[2] }
            }
            c = c.map { max(0, min(1, $0)) }
            let l = cbrt(0.4122214708 * c[0] + 0.5363325363 * c[1] + 0.0514459929 * c[2])
            let m = cbrt(0.2119034982 * c[0] + 0.6806995451 * c[1] + 0.1073969566 * c[2])
            let s = cbrt(0.0883024619 * c[0] + 0.2817188376 * c[1] + 0.6299787005 * c[2])
            return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
                    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
                    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s]
        }
    }

    /// Une couleur à l'octet, comme les `#RRGGBB` de la page : chaque opération y revient.
    struct Octets: Hashable, Sendable {
        let r, v, b: Int

        static let noir = Octets(0x000000)
        static let blanc = Octets(0xFFFFFF)

        init(_ hex: UInt32) {
            (r, v, b) = (Int(hex >> 16 & 0xFF), Int(hex >> 8 & 0xFF), Int(hex & 0xFF))
        }

        /// Borné puis arrondi comme `Math.round`.
        init(_ r: Double, _ v: Double, _ b: Double) {
            func octet(_ x: Double) -> Int { Int((max(0, min(255, x)) + 0.5).rounded(.down)) }
            (self.r, self.v, self.b) = (octet(r), octet(v), octet(b))
        }

        var hex: UInt32 { UInt32(r) << 16 | UInt32(v) << 8 | UInt32(b) }
        var rvb: RVB { RVB(hex) }

        static func melange(_ a: Octets, _ b: Octets, _ t: Double) -> Octets {
            func m(_ x: Int, _ y: Int) -> Double { Double(x) + Double(y - x) * t }
            return Octets(m(a.r, b.r), m(a.v, b.v), m(a.b, b.b))
        }

        /// La luminance relative de WCAG, au seuil de la page (0,03928).
        var luminance: Double {
            func lineaire(_ c: Int) -> Double {
                let x = Double(c) / 255
                return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * lineaire(r) + 0.7152 * lineaire(v) + 0.0722 * lineaire(b)
        }

        static func contraste(_ a: Octets, _ b: Octets) -> Double {
            let (x, y) = (a.luminance, b.luminance)
            return (max(x, y) + 0.05) / (min(x, y) + 0.05)
        }

        static func pire(_ c: Octets, _ fonds: [Octets]) -> Double { fonds.map { contraste(c, $0) }.min() ?? .infinity }

        /// Pousse `c` vers `vers` par pas jusqu'au seuil sur le pire des fonds.
        static func renforcer(_ c: Octets, _ fonds: [Octets], _ seuil: Double, vers: Octets) -> Octets {
            var c = c, n = 0.0
            while pire(c, fonds) < seuil, n < Parametres.iterationsMax {
                c = melange(c, vers, Parametres.pasRenfort)
                n += 1
            }
            return c
        }

        /// Noir (le texte foncé de la page) ou blanc, celui qui se lit le mieux sur `c`.
        static func texteSur(_ c: Octets) -> Octets { contraste(noir, c) > contraste(blanc, c) ? Parametres.texteFonce : blanc }

        /// Teinte (degrés), saturation et clarté (en %).
        var tsl: (Double, Double, Double) {
            let c = [Double(r) / 255, Double(v) / 255, Double(b) / 255]
            let haut = c.max() ?? 0, bas = c.min() ?? 0, d = haut - bas, l = (haut + bas) / 2
            let s = d == 0 ? 0 : d / (1 - abs(2 * l - 1))
            var t = 0.0
            if d != 0 {
                if haut == c[0] {
                    t = ((c[1] - c[2]) / d).truncatingRemainder(dividingBy: 6)
                } else if haut == c[1] {
                    t = (c[2] - c[0]) / d + 2
                } else {
                    t = (c[0] - c[1]) / d + 4
                }
            }
            return ((t * 60 + 360).truncatingRemainder(dividingBy: 360), s * 100, l * 100)
        }

        static func tsl(_ t: Double, _ s: Double, _ l: Double) -> Octets {
            let s = max(0, min(100, s)) / 100, l = l / 100
            let a = s * min(l, 1 - l)
            func f(_ n: Double) -> Double {
                let k = (n + t / 30).truncatingRemainder(dividingBy: 12)
                return l - a * max(-1, min(k - 3, 9 - k, 1))
            }
            return Octets(f(0) * 255, f(8) * 255, f(4) * 255)
        }

        static func tsl(_ v: [Double]) -> Octets { tsl(v[0], v[1], v[2]) }
    }

    /// Une couleur fixe mêlée d'une part de l'accent du thème (`[#RRGGBB, part]` dans jetons.json).
    struct Melange: Sendable {
        let de: Octets
        let part: Double
    }
}
