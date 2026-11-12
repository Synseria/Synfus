---
name: marque-assets
description: Classes du jeu (table intégrée rafraîchie par DofusDB) et leurs emblèmes (DofusDB, gardés dans les caches de l'utilisateur, ou l'icône qu'il pose — jamais embarqués, CGU Dofus 13.2), et la marque « l'Œuf ajouré » dessinée par le code (SynfusMark, Couvee, SynfusGlyph, icône du bundle) et ses variantes au choix (IconeApp, IconeAppliquee). Charger avant de toucher Classes/ (DofusClass, ClassesDofusDB, ClassesStore), Marque/, App/IconeAppliquee.swift, Tools/ (AppIconExport, generate-app-icons.sh) ou Resources/.
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

- L'Œuf ajouré (un Dofus en treillis de rubans ondés, blanc bleuté, éclairé du dedans, posé sur
  un feuillage à l'accent de l'app, sur une tuile — macOS 26 enferme dans un carré gris,
  réduite, toute icône du bundle qui n'est pas une tuile) est décrit **une seule fois** dans
  `SynfusMark.swift` : CoreGraphics pur, n'importe que CoreGraphics et Foundation
  (`Tools/AppIconExport.swift` le compile avec `Couvee.swift` et `IconeApp.swift` ; un
  `import AppKit` ou un `L()` dans ces trois fichiers le casse). Tracés originaux, aucun asset du jeu.
- **Variantes** (`IconeApp`, pur, Codable : motif × fond, Réglages → Général) : motifs `oeuf`
  et `couvee` (`Couvee.swift`, l'ancien logo, repère 256, sans fond propre) ; fonds `nuit`,
  `foret`, `aube` (teintes dans `SynfusMark.teintes`) et `transparent` (pas de tuile : le motif
  prend tout le carré, l'ombre portée d'un calque sous lui). `SynfusMark.image(pixelSize:icone:)`
  centre chaque motif par son `cadre`, à 92 % de la tuile. Un nouveau motif : son `cadre`, son
  `dessiner(pixels:)`, une ligne dans `poser`, et son fichier dans `generate-app-icons.sh`.
- Deux défauts : `IconeApp.duBundle` (oeuf + nuit, une tuile : macOS 26 enferme dans un carré
  gris l'icône d'un bundle qui n'en est pas une) et `IconeApp.parDefaut` (oeuf + transparent),
  posé par `IconeAppliquee` dès le lancement — une icône posée sur le bundle n'est pas enfermée.
  Ne régénérer les icônes (`./Tools/generate-app-icons.sh` → `Resources/Synfus.{icns,png}`) que
  si `duBundle` change. Ne jamais
  retoucher les PNG : modifier le dessin, relancer le script. Tué (`Killed: 9`) en écrivant dans
  `Resources/` : lancer le générateur vers `$TMPDIR`, copier, puis `iconutil`.
- `setShadow` prend décalage et flou en **pixels**, hors de la transformation : les multiplier
  par l'échelle du rendu, sinon l'ombre noie le carré des petites tailles.
- **Icône choisie** : `App/IconeAppliquee` est le seul à la poser — `NSApp.applicationIconImage`
  et `NSWorkspace.setIcon` sur le bundle (le défaut retire l'icône posée : `nil`), à chaque choix
  et au lancement si elle n'est pas le défaut (une mise à jour remplace le bundle). Rendu hors de
  main ; hors bundle, rien. `setIcon` ajoute `Icon\r` et `com.apple.FinderInfo` au bundle :
  lancement et TCC tiennent (le code signé est intact), mais `codesign --verify --strict` refuse
  le bundle installé — ne jamais vérifier ni re-signer l'app en place (`InstallateurMiseAJour`
  vérifie l'app téléchargée ; `build.sh` signe une copie neuve).
- Usages du dessin : icône du bundle, icône choisie et ses vignettes (`IconeAppliquee.vignette`),
  symbole de la barre de menus (`SynfusGlyph.menuBarImage()` → `SynfusMark.dessinerGlyphe`, l'Œuf
  quel que soit le choix).
- Repère 1024 × 1024, y vers le bas. `treillis(pixels:)` allège le treillis en petit (moins de
  rubans, plus larges) ; le trait ne descend pas sous `traitMinimalPixels`.
- Le treillis de devant est **une pièce** : contours de tout puis plein de tout, coupés par la
  silhouette, avec un rebord. Un effet sur la pièce (biseau) efface dans un calque en
  remplissage plein, jamais en pair-impair : les croisements compteraient deux fois.
- Le glyphe est une image *template* : seule l'opacité compte ; jours du treillis et détourage
  de l'œuf passent par un effacement de l'alpha (`.clear` / `.destinationOut`), jamais par un
  trait. Il a son propre dessin à plat (rubans vus de face, feuilles trapues) : le volume ne
  se lit plus à 18 pt.

## Le signe Synseria — `Marque/SigneSynseria.swift`

- Signe de la maison, distinct de l'Œuf : `EmblemeSynseria.cercles` (pur, repère 64 × 64) reprend la
  géométrie de `Synseria-Design/marque/synseria-embleme-synfus.svg` ; le plus grand disque de la
  planète est la `primaire` courante, le reste `Couleurs.nuit` et blanc. Aucun fichier figé.
- `SigneSynseria(hauteur:)` = emblème + mot « syn » (`encre`) « seria » (`encreSecondaire`), Outfit 600
  si installée, sinon SF Pro Rounded 600. Il vit dans « À propos de Synfus » (`MiseAJour/APropos`) et
  la proposition de mise à jour ; jamais dans le rond, jamais sur la barre de menus (qui garde l'Œuf).
- Pas un visuel du jeu : autorisé dans le bundle. Toute géométrie du signe se change dans
  `EmblemeSynseria.cercles`, testée par `SigneSynseriaTests`.
