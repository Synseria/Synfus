# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Langue

Le dépôt est intégralement en français : commentaires, libellés d'interface,
messages des scripts, documentation. Toute contribution doit s'y tenir, accents
compris.

## Commandes

```sh
swift build                        # compilation debug rapide (pas de bundle)
swift test                         # suite complète (Swift Testing)
swift test --filter PreferencesTests            # une suite
swift test --filter "migration"                 # un test par son nom
./build.sh                         # produit ./Synfus.app (release + signature)
./build.sh --install               # installe dans /Applications et relance
VERSION=0.0.3 ARCH=x86_64 ./build.sh
./make-dmg.sh Synfus.app dist/Synfus-0.0.3-arm64.dmg
./Tools/generate-app-icons.sh      # régénère Resources/Synfus.{icns,png}
./Tools/fetch-class-icons.sh       # remplit le dossier d'icônes de classes
```

Les tests portent sur la logique pure — analyse des titres de fenêtres, classes,
raccourcis, persistance. Tout ce qui dépend de l'API Accessibilité, du Dock ou
d'AppKit exige un environnement graphique et un client Dofus lancé : cela se
vérifie par un lancement réel (`./build.sh --install`) et l'onglet Diagnostic.

Les préférences se testent sur un stockage **en mémoire**
(`Preferences.forTesting(store:)`), jamais sur un `UserDefaults(suiteName:)` :
un domaine persistant survit à `removePersistentDomain` — `cfprefsd` réécrit le
fichier derrière — et chaque exécution sèmerait un plist dans
`~/Library/Preferences`. C'est la raison d'être du protocole `PreferencesStore`.

Mode diagnostic en ligne de commande, qui dump les attributs Accessibilité des
éléments du Dock — c'est ainsi qu'a été trouvée la détection de rebond :

```sh
/Applications/Synfus.app/Contents/MacOS/Synfus --dump-dock dofus 30
```

Il faut passer par le binaire du bundle installé et non par celui de `.build/` :
l'autorisation Accessibilité est liée à l'identité de code signée.

### Contraintes de compilation

- **SDK macOS 26 (Xcode 26) obligatoire** : `BarView` appelle `glassEffect`,
  absent des SDK antérieurs. Le deployment target reste `14.0`, la bascule vers
  `.ultraThinMaterial` se fait à l'exécution via `if #available(macOS 26.0, *)`.
- Le paquet est en **Swift 6, concurrence stricte**, sans dérogation. Le modèle
  est simple : tout vit sur le main thread. Les classes à état sont `@MainActor`
  (`Preferences` comprise), les callbacks Timer et notification repassent par
  `MainActor.assumeIsolated`, et le callback C de `HotKeyManager` — qui ne peut
  rien capturer — franchit la frontière via `DispatchQueue.main.async`.
  Toute nouvelle classe à état doit être `@MainActor` plutôt que d'obtenir une
  exemption.
- Les constantes `extern CFStringRef` de l'API Accessibilité (par ex.
  `kAXTrustedCheckOptionPrompt`) sont vues comme des `var` globales et refusées
  par la concurrence stricte : leur valeur littérale est citée directement.
- `build.sh` signe avec un certificat *Apple Development* s'il en trouve un dans
  le trousseau, sinon ad-hoc. Toucher à la signature ou au `BUNDLE_ID` change
  l'identité vue par TCC et **oblige à réautoriser l'Accessibilité** — et, le
  `BUNDLE_ID` nommant aussi le fichier de préférences, remet les réglages à zéro.
  Il vaut `fr.synseria.Synfus` : le reverse-DNS d'un domaine réellement détenu.

## Architecture

App AppKit `LSUIElement` (barre de menus, pas de Dock), point d'entrée
`SynfusMain` dans [App.swift](Sources/Synfus/App.swift). Tous les composants sont
des singletons `@MainActor` (`.shared`), la plupart `ObservableObject` observés
par les vues SwiftUI. `applicationDidFinishLaunching` les démarre dans cet ordre :
`WindowManager` → `HotKeyManager` → `MenuBarController` → `AttentionWatcher` →
`FloatingBarController`.

### Découverte des persos — le point central

[WindowManager.swift](Sources/Synfus/WindowManager.swift) est le cœur. Il énumère
toutes les fenêtres AX des processus dont le bundle ID contient `dofus`, puis
**dérive tout du titre de la fenêtre** (`« Nom - Classe - version - Release »`) :

- `isCharacterWindow` écarte les clients restés à l'écran de connexion (titre
  « Dofus » seul). C'est essentiel : les inclure décalerait la numérotation des
  slots, donc les raccourcis.
- `characterName` = premier segment, `characterClass` = deuxième segment.
- L'icône du Dock **ne peut pas** servir de repère : tous les clients partagent
  le même bundle `Dofus.app`, donc la même icône. C'est la raison d'être de
  toute l'approche par titre.

Aucune notification système ne signale un changement de titre (reconnexion,
changement de perso) : un `Timer` de 2 s rafraîchit, complété par les
notifications `NSWorkspace` (lancement / terminaison / activation).

L'identité d'un client est `slotKey` = `"<pid>#<index de fenêtre>"`. Le tri suit
`Preferences.characterOrder`, une liste de noms : les persos non lancés sont
simplement sautés, d'où des numéros de slot stables.

Tout ce qui est affiché n'est pas mémorisé pour autant : `isPersistableName`
écarte de `characterOrder` les noms qui ne désignent aucun perso — « Dofus
3.3.4.9 » (client resté au login, dont le titre n'annonce que la version, et qui
changerait à chaque mise à jour du jeu) et « Machin (2) » (le suffixe que
`refresh()` ajoute lui-même aux homonymes, selon l'ordre de découverte). Ces
clients restent dans la barre — on veut pouvoir cliquer dessus — mais, faute
d'entrée dans l'ordre, le tri les relègue en fin sans décaler personne.
`Preferences.purgeOrder` nettoie au démarrage les entrées enregistrées avant que
ce filtre n'existe.

### Détection d'attention

Aucune API publique ne dit qu'une *autre* app réclame l'attention.
[AttentionWatcher.swift](Sources/Synfus/AttentionWatcher.swift) contourne en
observant, via [DockInspector.swift](Sources/Synfus/DockInspector.swift), la
géométrie AX des icônes du Dock : `AXPosition.y` chute pendant le rebond. La
décision elle-même est isolée dans
[BounceDetector.swift](Sources/Synfus/BounceDetector.swift), une struct pure —
elle ne lit rien, on la nourrit d'un relevé par tour — donc testable sans Dock ni
écran ([BounceDetectorTests.swift](Tests/SynfusTests/BounceDetectorTests.swift)).

Deux règles y font tout le travail, et aucune n'est décorative :

- **Un rebond est un aller-retour.** Regarder la seule montée revenait à prendre
  la réapparition d'un Dock masqué pour un appel d'attention.
- **Un rebond a lieu Dock visible.** Un Dock en masquage automatique glisse hors
  écran ; le survol le fait remonter puis redescendre, ce qui est un aller-retour
  parfait. Seule la visibilité les sépare : une icône dont le cadre n'est pas
  entièrement contenu dans un écran est ignorée, position de repos comprise.

S'y ajoutent les garde-fous d'origine — la taille écarte la magnification, un
cooldown de 4 s évite les rafales — et le relevé est mis de côté tant que le
curseur survole le Dock.

L'appariement icône du Dock ↔ perso est une **hypothèse** : rang dans le Dock
(trié par abscisse) ↔ rang par pid croissant, les deux suivant l'ordre de
lancement. `dofusItems()` ne retient que les icônes de sous-rôle
`AXApplicationDockItem` appartenant à une app lancée : une fenêtre réduite ou une
entrée « récents » intitulée « Dofus » décalerait les rangs, donc l'appariement.
L'identité d'une icône est son **rang**, jamais son abscisse — la magnification
écarte les icônes sous le curseur, et chaque survol créait sinon une identité
neuve. C'est pour cette raison que l'appariement est exposé dans l'onglet
Diagnostic.
[AttentionProbe.swift](Sources/Synfus/AttentionProbe.swift) est l'outil
d'exploration qui a servi à établir ce mécanisme ; il journalise tout changement
d'attribut dans `~/Library/Logs/Synfus/attention.log`.

### Raccourcis globaux

[HotKeyManager.swift](Sources/Synfus/HotKeyManager.swift) utilise Carbon
`RegisterEventHotKey`, délibérément et non un `CGEventTap` : cela réserve une
combinaison auprès du système au lieu d'observer la frappe, donc aucune
permission de saisie et aucune visibilité sur ce qui est tapé ailleurs. Le
callback C ne pouvant rien capturer, il repasse par le singleton.

Le gestionnaire écoute `kEventHotKeyPressed` **et** `kEventHotKeyReleased` : les
raccourcis « à maintenir » — l'aperçu d'ensemble — en dépendent. Carbon n'émet pas
de répétition automatique, un appui prolongé ne donne donc qu'un appui et un
relâchement. Un modificateur seul reste hors de portée : `RegisterEventHotKey`
exige une touche, et l'observer demanderait un moniteur d'évènements, c'est-à-dire
exactement ce que l'on refuse de faire.

[HotKey.swift](Sources/Synfus/HotKey.swift) stocke des **keycodes de position
ANSI** et non des caractères : sur AZERTY la rangée du haut tape `& é " '`, mais
tout le monde l'appelle « 1 2 3 4 5 ». `rebind()` réenregistre tout après chaque
modification de préférence.

### Préférences

[Preferences.swift](Sources/Synfus/Preferences.swift) sérialise l'ensemble en
JSON sous une clé unique, `fr.synseria.synfus.preferences`, dans le stockage
fourni à l'initialisation (`UserDefaults.standard` en production).

Il n'y a **aucune migration** depuis les identifiants précédents
(`fr.dofusyn.DofuSyn`, `fr.synfus.Synfus`) : c'est un choix assumé. Comme
`UserDefaults.standard` range ses données dans un fichier nommé d'après le
`BUNDLE_ID`, changer celui-ci repart d'un plist vierge — les anciens
`~/Library/Preferences/fr.{dofusyn.DofuSyn,synfus.Synfus}.plist` sont orphelins
et peuvent être supprimés.

Chaque `@Published` déclenche `save()` dans son `didSet` ; le drapeau `loading`
évite les écritures pendant le chargement. Toute nouvelle clé doit être ajoutée
en `Optional` dans `Stored` avec un `?? défaut` à la lecture, pour rester
compatible avec les préférences déjà enregistrées — c'est ce que vérifie le test
« Une sauvegarde amputée des clés récentes se relit ».

Attention au `didSet` de `slotCount` : `@Published` transforme la propriété en
propriété calculée, donc s'y réassigner relance le `didSet` — d'où le drapeau
`clamping`.

### Interface

- [BarView.swift](Sources/Synfus/BarView.swift) — barre flottante, hébergée dans
  un `NSPanel` non activable (`canBecomeKey = false`) par
  [FloatingBarController.swift](Sources/Synfus/FloatingBarController.swift) :
  un overlay de jeu ne doit jamais capter le clavier. Le déplacement passe par
  `performDrag(with:)` d'AppKit (`WindowDragArea`), pas par un `DragGesture` —
  ce dernier reste toujours un cran derrière la souris.
  Le panneau est au niveau `.statusBar` et non `.floating` : un espace plein
  écran héberge la fenêtre du jeu à un niveau propre, sous lequel `.floating`
  disparaît. `.stationary` est délibérément absent du `collectionBehavior`, il
  brouille le suivi lors d'un passage en plein écran.
- La visibilité de la barre se décide sur `WindowManager.frontmostPID` /
  `frontmostIsDofus`, jamais en interrogeant `NSWorkspace` : au moment où l'on
  apprend qu'une app passe devant, `frontmostApplication` désigne encore la
  précédente. Le pid vient de la notification elle-même, la décision est prise
  **avant** `refresh()` — l'inventaire AX peut bloquer des centaines de
  millisecondes sur un client occupé —, et le timer de 2 s la réévalue en filet.
  La règle est isolée en fonction pure, `computeVisibility`, donc testée.
- [SettingsView.swift](Sources/Synfus/SettingsView.swift) — barre latérale à
  gauche, quatre sections (Raccourcis, Persos, Classes, Diagnostic) à droite +
  `SettingsWindowController`, qui doit appeler `NSApp.activate(ignoringOtherApps:)`
  car l'app est en mode accessory. À l'ouverture, la fenêtre se place centrée
  sous la barre flottante (`visibleBarFrame`), au centre de l'écran sinon.
- Le réordonnancement des persos dans la barre passe par un `DragGesture` en
  espace de coordonnées nommé, pas par `.onDrag`/`.onDrop` : le drag & drop
  système ne démarre pas de façon fiable depuis un `NSPanel` non activable.
- [MenuBarController.swift](Sources/Synfus/MenuBarController.swift) — le menu est
  reconstruit à chaque ouverture (`menuNeedsUpdate`). Les raccourcis y sont
  affichés en texte attribué, à titre indicatif : ce sont de vrais raccourcis
  globaux Carbon, pas des key equivalents de menu.
- [PreviewPanelController.swift](Sources/Synfus/PreviewPanelController.swift) —
  aperçus des fenêtres, dans un `NSPanel` **distinct** de la barre : celle-ci se
  dimensionne sur son contenu (`fixedSize` + `preferredContentSize`) et se
  recentre à chaque changement de taille, donc y greffer un aperçu la ferait
  sauter à chaque survol. Le panneau est `ignoresMouseEvents`.

### Aperçus des fenêtres

[WindowPreviewService.swift](Sources/Synfus/WindowPreviewService.swift) capture
via **ScreenCaptureKit** — `CGWindowListCreateImage` est déprécié depuis
macOS 14. Aucune API publique ne relie un `AXUIElement` à une fenêtre capturable :
l'appariement se fait sur `(pid, titre)`, avec repli sur le pid quand le processus
n'a qu'une fenêtre (le titre change à la reconnexion). C'est une hypothèse au même
titre que l'appariement du Dock, donc testée à part et exposée dans le Diagnostic.

La capture s'exécute hors du main actor et ne rend que du **PNG** : ni `SCWindow`
ni `CGImage` ne franchissent la frontière d'isolation, ce qui évite d'avoir à
plaider leur sendabilité.

C'est une **seconde autorisation TCC**, distincte de l'Accessibilité
(`NSScreenCaptureUsageDescription` dans l'Info.plist généré par `build.sh`). Les
deux réglages d'aperçu sont donc désactivés par défaut : une mise à jour ne doit
pas faire surgir une demande d'autorisation que personne n'a demandée. Limite
connue et documentée dans les réglages : une fenêtre d'un espace inactif est
capturable, mais macOS ne la redessine pas — l'image peut dater.

### Classes et icônes

[DofusClass.swift](Sources/Synfus/DofusClass.swift) est la **source unique** des
19 classes (clé sans accent, libellé, couleur) : y ajouter une entrée la fait
apparaître d'office dans la barre et les réglages. Une classe inconnue reçoit une
teinte dérivée par hachage du nom plutôt que du gris.

[ClassIconStore.swift](Sources/Synfus/ClassIconStore.swift) : Synfus **n'embarque
aucune image du jeu** — celles d'Ankama n'ont pas à être redistribuées. Les icônes
sont fournies par l'utilisateur dans
`~/Library/Application Support/Synfus/Classes/<clé>.png`. Ce dossier est l'unique
état ; les images importées sont réencodées en PNG 128 px. Ne pas ajouter d'assets
de classe au dépôt.

[Tools/fetch-class-icons.sh](Tools/fetch-class-icons.sh) automatise le
remplissage de ce dossier depuis l'API communautaire DofusDB (le CDN d'Ankama
répond 403). C'est **la seule forme acceptable** : l'article 13.2 des CGU de
Dofus interdit de distribuer les visuels du jeu sans accord écrit d'Ankama, donc
le dépôt ne transporte que des URL — la copie est faite par l'utilisateur, sur
sa machine, pour son usage personnel. Ne jamais convertir ce script en assets
embarqués, et conserver la mention « Certaines illustrations sont la propriété
d'Ankama Studio et de Dofus — Tous droits réservés », qui est la pratique
constante des sites communautaires tolérés.

La marque — un œuf cerné, abritant trois fenêtres — est décrite **une seule
fois**, dans [SynfusMark.swift](Sources/Synfus/SynfusMark.swift) : un moteur pur
CoreGraphics, sans AppKit ni SwiftUI, pour rester compilable hors de l'app. Cette
description sert trois usages :

| Usage | Par |
| --- | --- |
| Icône du bundle (`.icns`, `.png`) | [Tools/AppIconExport.swift](Tools/AppIconExport.swift) |
| Symbole de la barre de menus | `SynfusGlyph.menuBarImage()` |
| Poignée de la barre flottante | `SynfusGlyphView` |

```sh
./Tools/generate-app-icons.sh   # régénère Resources/Synfus.{icns,png}
```

Le script compile `SynfusMark.swift` **tel quel** avec l'exportateur : le bundle
et l'app dessinent donc rigoureusement la même marque. Ne jamais retoucher les
PNG à la main — modifier la marque veut dire modifier `SynfusMark` puis relancer
le script. C'est aussi pourquoi `SynfusMark` ne doit importer que CoreGraphics et
Foundation : un `import AppKit` casserait la compilation du générateur.

Deux réglages y gouvernent le cadrage : `defaultFillRatio` (0,90 — la part de la
tuile qu'occupe l'œuf) et `roundedInsetRatio` (la marge Apple, 824/1024). Le
repère de description est celui de la maquette, **280 × 280, y vers le bas**.

[Resources/Synfus.svg](Resources/Synfus.svg) est la maquette d'origine, gardée
comme référence. Elle n'est **plus la source** et diverge du rendu : son effet
néon (`feGaussianBlur`) a été retiré et son œuf agrandi.

`SynfusGlyph` s'écarte de la marque sur deux points, imposés par la taille de
lecture : monochrome (macOS teint lui-même les images *template*) et fenêtres
pleines à trait épaissi — sous 20 px, le contour de la maquette tombe sous le
pixel.

## Publication

Un tag `v*` poussé déclenche
[release.yml](.github/workflows/release.yml) : runner `macos-26`, compilation
arm64 + x86_64, DMG et release GitHub. Les builds de CI sont signés ad-hoc et non
notarisés, d'où le `xattr -dr com.apple.quarantine` documenté dans le README.
