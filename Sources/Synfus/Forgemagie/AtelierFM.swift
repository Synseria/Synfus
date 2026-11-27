import CoreGraphics
import Foundation

/// L'atelier de forgemagie de Dofus 3 retrouvé dans les textes lus d'une
/// capture, sans zone calibrée : l'en-tête de sa table (« Min », « Max »,
/// « Effets / Carac. ») donne ses colonnes, l'historique est à sa gauche.
/// L'OCR rend les cases de la table une à une et dans le désordre : elles se
/// rangent par leur position. Les stocks de runes (colonnes Pa, Ra) se lisent
/// trop mal pour servir ; leur place, elle, dit où poser chaque rune. Pur.
struct AtelierFM: Equatable, Sendable {
    /// L'objet tel que la table le montre ; la table défile, il peut en manquer.
    let objet: ObjetFM
    /// Les lignes dont le nom n'est d'aucun effet connu : gardées telles quelles.
    let inconnues: [String]
    /// « reliquat : N », le puits que le jeu affiche.
    let reliquat: Double?
    /// L'historique, de haut en bas : la plus récente entrée en bas.
    let historique: [TexteFM.Entree]
    /// Ce que couvrent l'en-tête, la table et l'historique, dans le repère des
    /// textes : la lecture suivante peut s'y borner.
    let cadre: CGRect
    /// Où se trouve chaque rune des lignes lues ; `nil` sans les en-têtes Pa et Ra.
    var runes: EmplacementsRunes?

    /// Les cases des runes : une rangée par ligne de l'objet, une colonne par
    /// rang (simple, Pa, Ra), dans le repère des textes.
    struct EmplacementsRunes: Equatable, Sendable {
        /// Le milieu de la case de chaque rang.
        let colonnes: [CGFloat]
        /// Le milieu de la rangée de chaque effet.
        let rangees: [Int: CGFloat]

        /// L'écart entre deux cases voisines, en largeur de contenu.
        var pas: CGFloat { colonnes[colonnes.count - 1] - colonnes[colonnes.count - 2] }

        func centre(effet: Int, rang: CatalogueFM.Rang) -> CGPoint? {
            guard colonnes.indices.contains(rang.rawValue), let y = rangees[effet] else { return nil }
            return CGPoint(x: colonnes[rang.rawValue], y: y)
        }
    }

    static func lire(_ textes: [DetectionZones.TexteVu], catalogue: CatalogueFM) -> AtelierFM? {
        // Une infobulle peut porter elle aussi « Effets » : le premier en-tête complet compte.
        guard let en = textes.lazy.filter({ normal($0.texte).hasPrefix("effets") }).compactMap({ EnTete(textes, effets: $0) }).first
        else { return nil }
        let reliquatVu = textes.first { TexteFM.reliquat([$0.texte]) != nil }
        let haut = max(reliquatVu?.cadre.maxY ?? -.infinity,
                       textes.filter { normal($0.texte).hasPrefix("fusionner") }.map(\.cadre.maxY).max() ?? -.infinity)
        let pied = textes.first { normal($0.texte).contains("vider l historique") }
        let bas = pied.map { $0.cadre.maxY + 2 * en.hauteur } ?? .infinity

        // Les lignes de la table : un effet dans sa colonne, ses bornes à côté.
        var lignes: [ObjetFM.Ligne] = []
        var rangees: [Int: CGFloat] = [:]
        var inconnues: [String] = []
        var occupe = en.cadre
        let effets = textes.filter {
            $0.cadre.minY > en.cadre.maxY && $0.cadre.maxY < bas
                && $0.cadre.minX >= en.max.cadre.maxX - en.hauteur && $0.cadre.minX < en.finEffets
                // La ligne d'arme, « 9 à 11 dommages Eau » (l'accent parfois perdu), ne se forgemage pas.
                && normal($0.texte).firstMatch(of: /\d+ a \d+/) == nil
        }
        for texte in effets.sorted(by: { $0.cadre.midY < $1.cadre.midY }) {
            guard case .ligne(let points, let nom, let pourcent)? = TexteFM.entree(texte.texte) else { continue }
            occupe = occupe.union(texte.cadre)
            guard let effet = catalogue.effet(nomme: nom, pourcent: pourcent) else {
                inconnues.append(texte.texte)
                continue
            }
            // Un effet lu deux fois : la seconde est une erreur de lecture.
            guard !lignes.contains(where: { $0.effet == effet.id }) else { continue }
            let rang = textes.filter { abs($0.cadre.midY - texte.cadre.midY) < en.hauteur }
            let min = en.nombre(dans: rang, colonne: en.min)
            let max = en.nombre(dans: rang, colonne: en.max)
            // Ni min ni max : une exo (« - »). Un min sans max : une case mal lue.
            lignes.append(ObjetFM.Ligne(effet: effet.id, valeur: points, max: max, exo: min == nil && max == nil))
            rangees[effet.id] = texte.cadre.midY
        }

        // L'historique : à gauche de la table, sous la barre de fusion, sur
        // cinq pas et demi de colonne — le suivi de quêtes, plus à gauche, n'y
        // entre pas. Le pas Min–Max se lit même quand la lecture ne couvre plus
        // les stocks, à droite.
        let gauche = en.min.cadre.minX - 5.5 * (en.max.cadre.midX - en.min.cadre.midX)
        let colonne = textes
            .filter { $0.cadre.midX >= gauche && $0.cadre.maxX < en.min.cadre.minX && $0.cadre.minY > haut && $0.cadre.maxY < (pied?.cadre.minY ?? bas) }
            .sorted { $0.cadre.midY < $1.cadre.midY }
        let historique = colonne.compactMap { TexteFM.entree($0.texte) }
        for texte in colonne { occupe = occupe.union(texte.cadre) }

        return AtelierFM(objet: ObjetFM(lignes: lignes.sorted { $0.effet < $1.effet }), inconnues: inconnues,
                         reliquat: reliquatVu.flatMap { TexteFM.reliquat([$0.texte]) }, historique: historique,
                         cadre: occupe.union(reliquatVu?.cadre ?? occupe),
                         runes: en.colonnesRunes(textes, rangees: rangees).map { EmplacementsRunes(colonnes: $0, rangees: rangees) })
    }

    /// Sans accents ni casse, ponctuation réduite à une espace.
    private static func normal(_ texte: String) -> String { Ressemblance.normaliser(texte) }

    /// L'en-tête de la table et ses colonnes.
    private struct EnTete {
        let min: DetectionZones.TexteVu
        let max: DetectionZones.TexteVu
        /// La colonne des effets finit où commence « Modif. », sinon à mi-chemin des stocks.
        let finEffets: CGFloat
        let hauteur: CGFloat
        let cadre: CGRect
        let pa: DetectionZones.TexteVu?
        let ra: DetectionZones.TexteVu?

        /// Le milieu des cases simple, Pa et Ra. Les en-têtes Pa et Ra sont
        /// calés à gauche de leur case (un cinquième de pas) ; les stocks lus
        /// dans les rangées, au milieu de la case, les corrigent.
        func colonnesRunes(_ textes: [DetectionZones.TexteVu], rangees: [Int: CGFloat]) -> [CGFloat]? {
            guard let pa, let ra, ra.cadre.midX > pa.cadre.midX else { return nil }
            let pas = ra.cadre.midX - pa.cadre.midX
            let estimees = [pa.cadre.midX - pas, pa.cadre.midX, ra.cadre.midX].map { $0 + 0.2 * pas }
            let stocks = textes.filter { texte in
                Int(texte.texte.trimmingCharacters(in: .whitespaces)) != nil
                    && rangees.values.contains { abs($0 - texte.cadre.midY) < hauteur }
            }
            return estimees.map { x in
                let vus = stocks.map(\.cadre.midX).filter { abs($0 - x) < pas / 3 }.sorted()
                return vus.isEmpty ? x : vus[vus.count / 2]
            }
        }

        init?(_ textes: [DetectionZones.TexteVu], effets: DetectionZones.TexteVu) {
            let ligne = textes.filter { abs($0.cadre.midY - effets.cadre.midY) < effets.cadre.height }
            func mot(_ attendu: String) -> DetectionZones.TexteVu? {
                ligne.first { AtelierFM.normal($0.texte) == attendu }
            }
            // « Max » se lit parfois « Маx », lettres cyrilliques : c'est la case
            // entre « Min » et les effets.
            guard let min = mot("min"),
                  let max = ligne.filter({ $0.cadre.minX > min.cadre.maxX && $0.cadre.maxX <= effets.cadre.minX })
                      .min(by: { $0.cadre.minX < $1.cadre.minX })
            else { return nil }
            let modif = mot("modif")
            pa = mot("pa")
            ra = mot("ra")
            let stocks = [pa, ra].compactMap(\.self)
            self.min = min
            self.max = max
            let droite = (stocks.map(\.cadre.maxX) + [modif?.cadre.maxX ?? effets.cadre.maxX]).max() ?? effets.cadre.maxX
            finEffets = modif?.cadre.minX ?? (effets.cadre.maxX + droite) / 2
            hauteur = effets.cadre.height
            // Le cadre couvre la table jusqu'aux stocks : la lecture suivante, bornée à lui, garde « Modif. ».
            cadre = ([max, effets] + [modif].compactMap(\.self) + stocks).map(\.cadre).reduce(min.cadre) { $0.union($1) }
        }

        /// Le nombre d'une case dans la colonne de `colonne`, à mi-chemin de la
        /// suivante près ; `nil` pour « - » (exo) ou une case illisible.
        func nombre(dans rang: [DetectionZones.TexteVu], colonne: DetectionZones.TexteVu) -> Int? {
            let demiPas = (max.cadre.midX - min.cadre.midX) / 2
            return rang.lazy
                .filter { abs($0.cadre.midX - colonne.cadre.midX) < demiPas }
                .compactMap { Int($0.texte.trimmingCharacters(in: .whitespaces)) }
                .first
        }
    }
}
