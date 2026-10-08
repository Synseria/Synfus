---
name: marque-assets
description: Classes du jeu (table intégrée rafraîchie par DofusDB) et leurs emblèmes (DofusDB, gardés dans les caches de l'utilisateur, ou l'icône qu'il pose — jamais embarqués, CGU Dofus 13.2), et la marque « la Couvée » dessinée par le code (SynfusMark, SynfusGlyph, icône du bundle). Charger avant de toucher Classes/ (DofusClass, ClassesDofusDB, ClassesStore), Marque/, Tools/ (AppIconExport, generate-app-icons.sh) ou Resources/.
user-invocable: false
---

# Classes, visuels du jeu et marque

## Classes — `Sources/Synfus/Classes/`

- **Une règle, deux données** : `DofusClass.integrees` (19 classes : identifiant DofusDB, noms
  fr/en/es, couleur) est la reconnaissance hors ligne et la seule source des couleurs ;
  `ClassesDofusDB` télécharge `breeds` (au démarrage si plus de 30 jours, ou « Mettre à jour »),
  le garde dans `Application Support/Synfus/Classes.json` (format versionné) et
  `ClassesDofusDB.catalogue` fusionne — c'est le seul endroit qui combine les deux.
- Fusion par **identifiant DofusDB** : une classe connue garde sa **clé** (nom de fichier des
  icônes, `DofusClassTests` la fige) et sa couleur, prend les noms et l'emblème de DofusDB, reste
  reconnue sous ses anciens noms (`alias`). Une classe que la table n'a pas s'ajoute à la suite,
  teinte dérivée du nom : pas de mise à jour de Synfus nécessaire. Ajouter une classe à la table
  ne sert qu'à lui donner une couleur choisie.
- Le titre de fenêtre est dans la langue du **jeu** : `Catalogue.key(for:)` ramène tout nom (fr,
  en, es, ancien) à la clé. Pliage sans locale (`DofusClass.cle`).
- La barre, le menu et les réglages lisent `ClassesStore.shared.catalogue`, jamais la table.

## Emblèmes — jamais dans le dépôt ni le bundle

- L'article 13.2 des CGU de Dofus interdit de distribuer les visuels du jeu : le dépôt ne
  transporte que des URL (`DofusDB.emblemeClasse`, `img` de `breeds`). Ne jamais ajouter d'image
  du jeu, ni d'étape de build qui en embarque.
- Ordre (`DofusClass.provenance`, pur) : l'icône de l'utilisateur
  (`Application Support/Synfus/Classes/<clé>.png`, l'unique état modifiable, import réencodé en
  PNG 128 px), sinon l'emblème DofusDB via `ImagesDofusDB` (caches, demandé une fois par
  lancement ; « Mettre à jour » le redemande avec `recharger`, l'ancien reste si le réseau manque).
- L'onglet Classes montre la provenance (« DofusDB » / « La tienne ») ; seule la tienne se retire.
- Garder la mention « Certaines illustrations sont la propriété d'Ankama Studio et de Dofus —
  Tous droits réservés ».

## La marque — `Sources/Synfus/Marque/`

- La Couvée (trois œufs de dragon, un par compte, le perso actif devant) est décrite **une
  seule fois** dans `SynfusMark.swift` : CoreGraphics pur, n'importe que CoreGraphics et
  Foundation (`Tools/AppIconExport.swift` le compile tel quel ; un `import AppKit` le casse).
  Tracés originaux, aucun asset du jeu.
- Periphery signale `SynfusMark` comme du code mort : hors `dragonEgg` (repris par
  `SynfusGlyph`), il ne sert qu'à `Tools/AppIconExport.swift`, compilé hors du paquet. Faux
  positif attendu — ne pas supprimer.
- Usages : icône du bundle (`./Tools/generate-app-icons.sh` → `Resources/Synfus.{icns,png}`) et
  symbole de la barre de menus (`SynfusGlyph.menuBarImage()`). Ne jamais retoucher les PNG :
  modifier `SynfusMark`, relancer le script.
- Repère de description 256 × 256, y vers le bas ; `roundedInsetRatio`, `eggAspect`,
  `texturesBelow` (sous ce seuil, les textures sont abandonnées).
- `SynfusGlyph` est une image *template* : seule l'opacité compte, le détourage de l'œuf de tête
  passe par un effacement de l'alpha (`.clear` / `.destinationOut`), jamais par un trait.
