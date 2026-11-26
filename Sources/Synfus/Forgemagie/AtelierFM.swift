import CoreGraphics
import Foundation

/// L'atelier de forgemagie de Dofus 3 retrouvé dans les textes lus d'une
/// capture, sans zone calibrée : l'en-tête de sa table (« Min », « Max »,
/// « Effets / Carac. ») donne ses colonnes, l'historique est à sa gauche.
/// L'OCR rend les cases de la table une à une et dans le désordre : elles se
/// rangent par leur position. Les stocks de runes (colonnes Pa, Ra) se lisent
/// trop mal pour servir. Pur.
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

    static func lire(_ textes: [DetectionZones.TexteVu], catalogue: CatalogueFM) -> AtelierFM? {
        guard let en = EnTete(textes) else { return nil }
        let reliquatVu = textes.first { TexteFM.reliquat([$0.texte]) != nil }
        let haut = max(reliquatVu?.cadre.maxY ?? -.infinity,
                       textes.filter { normal($0.texte).hasPrefix("fusionner") }.map(\.cadre.maxY).max() ?? -.infinity)
        let pied = textes.first { normal($0.texte).contains("vider l historique") }
        let bas = pied.map { $0.cadre.maxY + 2 * en.hauteur } ?? .infinity

        // Les lignes de la table : un effet dans sa colonne, ses bornes à côté.
        var lignes: [ObjetFM.Ligne] = []
        var inconnues: [String] = []
        var occupe = en.cadre
        let effets = textes.filter {
            $0.cadre.minY > en.cadre.maxY && $0.cadre.maxY < bas
                && $0.cadre.minX >= en.max.cadre.maxX - en.hauteur && $0.cadre.minX < en.finEffets
                && $0.texte.firstMatch(of: /\d+\s+à\s+\d+/) == nil
        }
        for texte in effets {
            guard case .ligne(let points, let nom, let pourcent)? = TexteFM.entree(texte.texte) else { continue }
            occupe = occupe.union(texte.cadre)
            guard let effet = catalogue.effet(nomme: nom, pourcent: pourcent) else {
                inconnues.append(texte.texte)
                continue
            }
            let rang = textes.filter { abs($0.cadre.midY - texte.cadre.midY) < en.hauteur }
            let min = en.nombre(dans: rang, colonne: en.min)
            let max = en.nombre(dans: rang, colonne: en.max)
            // Ni min ni max : une exo (« - »). Un min sans max : une case mal lue.
            lignes.append(ObjetFM.Ligne(effet: effet.id, valeur: points, max: max, exo: min == nil && max == nil))
        }

        // L'historique : à gauche de la table, sous la barre de fusion.
        let gauche = en.min.cadre.minX - 0.55 * (en.droite - en.min.cadre.minX)
        let colonne = textes
            .filter { $0.cadre.midX >= gauche && $0.cadre.maxX < en.min.cadre.minX && $0.cadre.minY > haut && $0.cadre.maxY < (pied?.cadre.minY ?? bas) }
            .sorted { $0.cadre.midY < $1.cadre.midY }
        let historique = colonne.compactMap { TexteFM.entree($0.texte) }
        for texte in colonne { occupe = occupe.union(texte.cadre) }

        return AtelierFM(objet: ObjetFM(lignes: lignes.sorted { $0.effet < $1.effet }), inconnues: inconnues,
                         reliquat: reliquatVu.flatMap { TexteFM.reliquat([$0.texte]) }, historique: historique,
                         cadre: occupe.union(reliquatVu?.cadre ?? occupe))
    }

    /// Sans accents ni casse, ponctuation réduite à une espace.
    private static func normal(_ texte: String) -> String { Ressemblance.normaliser(texte) }

    /// L'en-tête de la table et ses colonnes.
    private struct EnTete {
        let min: DetectionZones.TexteVu
        let max: DetectionZones.TexteVu
        /// La colonne des effets finit où commence « Modif. », sinon à mi-chemin des stocks.
        let finEffets: CGFloat
        /// Le bord droit de la table (« Ra », « Pa » ou « Modif. »).
        let droite: CGFloat
        let hauteur: CGFloat
        let cadre: CGRect

        init?(_ textes: [DetectionZones.TexteVu]) {
            guard let effets = textes.first(where: { AtelierFM.normal($0.texte).hasPrefix("effets") }) else { return nil }
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
            let stocks = [mot("pa"), mot("ra")].compactMap(\.self)
            self.min = min
            self.max = max
            droite = (stocks.map(\.cadre.maxX) + [modif?.cadre.maxX ?? effets.cadre.maxX]).max() ?? effets.cadre.maxX
            finEffets = modif?.cadre.minX ?? (effets.cadre.maxX + droite) / 2
            hauteur = effets.cadre.height
            cadre = [max, effets].map(\.cadre).reduce(min.cadre) { $0.union($1) }
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
