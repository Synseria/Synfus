---
name: marque-assets
description: Classes du jeu et leurs icônes (fournies par l'utilisateur, jamais embarquées — CGU Dofus 13.2), script de téléchargement Ankama, et la marque « la Couvée » dessinée par le code (SynfusMark, SynfusGlyph, icône du bundle). Charger avant de toucher Classes/ (DofusClass, ClassIconStore, AnkamaAssets), Marque/, Tools/ (FetchAnkamaAssets, AppIconExport, generate-app-icons.sh) ou Resources/.
user-invocable: false
---

# Classes, visuels du jeu et marque

## Classes — `Sources/Synfus/Classes/DofusClass.swift`

- **Source unique** des classes (clé sans accent, libellé, couleur) : une entrée ajoutée
  apparaît d'office dans la barre et les réglages. Classe inconnue : teinte dérivée par hachage
  du nom, pas du gris.
- Le titre de fenêtre est dans la langue du **jeu** : `DofusClass.Breed` porte les noms `en` et
  `es`, `key(for:)` les ramène à la clé française (`DofusClassTests`).
- `DofusClass` est compilé seul par `Tools/` : pas de `L()` dedans (skill `localisation`).

## Visuels Ankama — jamais dans le dépôt

- L'article 13.2 des CGU de Dofus interdit de distribuer les visuels du jeu : le dépôt ne
  transporte que des URL. Ne jamais ajouter d'image du jeu, ni convertir le script en assets
  embarqués.
- Icônes utilisateur : `~/Library/Application Support/Synfus/Classes/<clé>.png`, l'unique état
  modifiable (`ClassIconStore`, import réencodé en PNG 128 px).
- `Tools/fetch-ankama-assets.sh` compile `FetchAnkamaAssets.swift` **avec** `DofusClass.swift`
  (mêmes clés que l'app) et télécharge depuis DofusDB (le CDN d'Ankama répond 403) dans
  `Resources/Ankama/Classes/` (gitignoré). `build.sh` l'embarque s'il existe ; la CI ne l'a pas.
- Résolution (`AnkamaAssets`) : Application Support d'abord, bundle ensuite.
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
