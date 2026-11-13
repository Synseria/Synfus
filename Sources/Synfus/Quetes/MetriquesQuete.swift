import CoreGraphics

/// Les tailles de la fiche d'une quête, en un seul endroit : le confort, ou le
/// mode compact qui laisse voir plus de jeu (`Preferences.quetesCompact`).
/// Une vue n'écrit aucune taille de texte ou de marge de la fiche en dur.
struct MetriquesQuete: Equatable {
    /// Objectifs, ressources, quêtes suivantes, menu de l'en-tête.
    let texte: Jetons.Typo
    /// Objectif en cours.
    let texteFort: Jetons.Typo
    /// Nom de la quête.
    let titre: Jetons.Typo
    /// Le nom de la quête, appuyé.
    let titreFort: Jetons.Typo
    /// Consigne de l'étape.
    let consigne: Jetons.Typo
    /// Position, catégorie, niveau, récompenses, titres de section.
    let detail: Jetons.Typo
    /// Le détail appuyé : « Copié », titres de section.
    let detailFort: Jetons.Typo
    /// Coche d'un objectif.
    let coche: Jetons.Typo
    /// Pictogramme d'une ressource ou d'une suivante.
    let icone: Jetons.Typo
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
        texte: .corps, texteFort: .corpsFort, titre: .titre, titreFort: .corpsFort,
        consigne: .note, detail: .note, detailFort: .corpsFort, coche: .corps, icone: .note,
        marge: Jetons.Espace.trois, ecartSections: Jetons.Espace.trois, ecartLignes: Jetons.Espace.un,
        ligneHorizontale: Jetons.Espace.deux, ligneVerticale: Jetons.Espace.un,
        vignette: CGSize(width: 52, height: 36))

    /// Sous la grille de 4 : le mode compact existe pour laisser voir le jeu, ses écarts de 1 et 2 pt
    /// sont ce qui le distingue du confort.
    static let compact = MetriquesQuete(
        texte: .petit, texteFort: .raccourci, titre: .corps, titreFort: .corpsFort,
        consigne: .petit, detail: .petit, detailFort: .raccourci, coche: .petit, icone: .petit,
        marge: Jetons.Espace.deux, ecartSections: Jetons.Espace.deux, ecartLignes: 1,
        ligneHorizontale: Jetons.Espace.un, ligneVerticale: 2,
        vignette: CGSize(width: 44, height: 30))

    static func pour(compact: Bool) -> MetriquesQuete { compact ? .compact : .confort }
}
