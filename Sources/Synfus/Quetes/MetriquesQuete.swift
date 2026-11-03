import CoreGraphics

/// Les tailles de la fiche d'une quête, en un seul endroit : le confort, ou le
/// mode compact qui laisse voir plus de jeu (`Preferences.quetesCompact`).
/// Une vue n'écrit aucune taille de texte ou de marge de la fiche en dur.
struct MetriquesQuete: Equatable {
    /// Objectifs, ressources, quêtes suivantes, menu de l'en-tête.
    let texte: CGFloat
    /// Nom de la quête.
    let titre: CGFloat
    /// Consigne de l'étape.
    let consigne: CGFloat
    /// Position, catégorie, niveau, récompenses, titres de section.
    let detail: CGFloat
    /// Coche d'un objectif.
    let coche: CGFloat
    /// Pictogramme d'une ressource ou d'une suivante.
    let icone: CGFloat
    /// Autour de la fiche.
    let marge: CGFloat
    /// Entre deux sections (en-tête, ressources, étape, suivantes).
    let ecartSections: CGFloat
    /// Entre deux lignes d'une section.
    let ecartLignes: CGFloat
    /// Autour du contenu d'une ligne cliquable.
    let ligneHorizontale: CGFloat
    let ligneVerticale: CGFloat
    /// Vignette de carte d'un objectif (`Preferences.quetesVignettes`).
    let vignette: CGSize

    static let confort = MetriquesQuete(
        texte: 13, titre: 15, consigne: 12, detail: 11, coche: 12, icone: 11,
        marge: 12, ecartSections: 12, ecartLignes: 4, ligneHorizontale: 6, ligneVerticale: 4,
        vignette: CGSize(width: 52, height: 36))

    static let compact = MetriquesQuete(
        texte: 12, titre: 13, consigne: 11, detail: 11, coche: 11, icone: 11,
        marge: 8, ecartSections: 8, ecartLignes: 1, ligneHorizontale: 4, ligneVerticale: 2,
        vignette: CGSize(width: 44, height: 30))

    static func pour(compact: Bool) -> MetriquesQuete { compact ? .compact : .confort }
}
