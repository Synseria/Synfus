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
notifications `NSWorkspace` (lancement / terminaison / activation). Celles-ci
passent par `refreshSoon()` et non `refresh()` : un changement d'application en
émet deux, et enchaîner deux inventaires AX double le gel au moment précis où
l'utilisateur bascule.

**Un client peut cesser de rendre ses fenêtres.** Mesuré au `--dump-windows` :
un client dont l'espace plein écran n'est pas actif retire sa fenêtre de l'ordre
d'affichage, et `kAXWindows` — qui ne liste que ce qui s'y trouve — rend alors
une liste **vide**, sans erreur. Le perso disparaissait donc de la barre, et son
icône du Dock restant en place, l'appariement de la détection d'attention se
décalait avec lui.

D'où `rememberedClients`, une mémoire par **pid** : le processus vit aussi
longtemps que le client, alors que la fenêtre va et vient au gré des espaces. Un
perso mémorisé reste affiché, atténué, et reste cliquable — `activate()` sur le
processus suffit à basculer vers son espace, l'élément AX ne sert qu'à départager
plusieurs fenêtres d'un même client, et celui d'un perso mémorisé est périmé.

La règle de fusion, `withRemembered`, est pure et testée. Elle ne ressuscite que
les processus **silencieux** — ceux qui ne rendent aucune fenêtre. Un client
revenu à l'écran de connexion en rend une, simplement sans perso : le
ressusciter afficherait un perso qui n'est plus en jeu.

Un client déjà sur un espace inactif au démarrage de Synfus n'a jamais livré son
titre à l'Accessibilité. Quand l'enregistrement de l'écran est accordé (celui
des aperçus), [CrossSpaceTitles.swift](Sources/Synfus/CrossSpaceTitles.swift)
lève cette limite : `CGWindowListCopyWindowInfo` voit à travers les espaces, et
`discoveredAcrossSpaces` — pure, testée — fabrique le dormant à partir du titre
lu. La lecture n'a lieu que pour les pids sans aucune mémoire (le tour de toutes
les fenêtres du système n'est pas payé à chaque inventaire), et l'autorisation
n'est **jamais demandée** par ce chemin : sans elle, la limite demeure,
documentée dans les réglages.

Tous les appels AX du processus sont bornés à 1 s
(`AXUIElementSetMessagingTimeout` sur l'élément système, posé dans `start()`) :
un client gelé ne répond jamais, et sans borne chaque inventaire resterait
suspendu plusieurs secondes sur lui — barre comprise.

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

- **Un rebond est un aller-retour — sauf quand l'aller suffit.** Regarder une
  montée modeste revenait à prendre la réapparition d'un Dock masqué pour un
  appel d'attention. Mais attendre l'arc entier coûte **une seconde de latence**,
  ce qui se sent à l'usage : sur le relevé du 03/08, la montée commence à
  15:00:51 et le retour ne s'achève qu'à 15:00:52. Au-delà de `certaintyRatio`
  (0,45 de la hauteur de l'icône, atteint dès le premier tour de la montée), on
  conclut donc sur l'aller. En deçà, ou faute de bandeau pour repère — la mesure
  redevenant alors absolue —, le retour reste exigé.
- **Un rebond se mesure par rapport au Dock, pas à l'écran.** Une icône qui
  rebondit se détache du bandeau ; un Dock qui se masque ou se dévoile emporte
  l'un et l'autre. `DockInspector.Inventory.strip` donne le cadre du bandeau, et
  le détecteur suit l'**écart** icône ↔ bandeau. C'est une hypothèse — que le
  bandeau ne bouge pas pendant un rebond —, d'où son affichage dans le
  Diagnostic, comme l'appariement des rangs.

  Elle remplace une règle antérieure, « un rebond a lieu Dock visible », qui
  exigeait que le cadre de l'icône tienne entièrement dans un écran. Un relevé
  réel l'a mise en défaut : **en masquage automatique, les icônes reposent sous
  le bord de l'écran** — sur un 1728 × 1117, à `y = 1117` pile. Aucune position
  de repos n'était donc jamais retenue, et un rebond parfaitement net —
  61 points de montée — ne déclenchait rien. La règle protégeait des faux
  positifs en rendant la détection impossible pour qui masque son Dock.
  `BounceDetectorTests` rejoue ce relevé tel quel.

Le survol reste écarté à part, par `mouseInDock`. Sa zone est celle du **bandeau
entier**, pas des seules icônes Dofus : un Dock masqué se dévoile dès que le
curseur touche le bord de l'écran, fût-ce à l'autre bout du Dock, et les icônes
de Dofus remontent alors sans que le curseur soit au-dessus d'elles.

S'y ajoutent les garde-fous d'origine — la taille écarte la magnification, un
cooldown de 4 s évite les rafales — et le relevé est mis de côté tant que le
curseur survole le Dock.

Le relevé passe dix fois par seconde : rien de ce qu'il produit ne doit être
republié sans avoir changé. `pairing` l'était sans condition, et la barre
flottante — qui observe ce watcher — se recalculait donc en permanence à cette
cadence. C'est aussi pourquoi le tour de boucle sort avant d'interroger le Dock
quand aucun perso n'est connecté.

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

Le jeu par défaut sépare deux territoires, et cette séparation est une règle :
la **rangée de chiffres** (`digitRow`) appartient à l'accès direct — ⌘1…⌘0
numérotent les emplacements, ⌘0 étant celui du dixième —, tandis que toute la
navigation tient sur la **touche sous Échap** (`escapeRowKey`), différenciée par
les modificateurs : ⌘@ suivant, ⇧⌘@ précédent, ⌥⌘@ aperçu d'ensemble, ⌃⌘@
bascule du passage auto. Aucun nouveau défaut ne doit piocher dans `digitRow`,
sous peine de se heurter au slot du même rang.

**Le keycode de la touche sous Échap dépend du type physique du clavier**, et
non de la disposition : un ANSI y place `kVK_ANSI_Grave` (50), un ISO — donc
tous les claviers Apple européens, clavier interne français compris —
`kVK_ISO_Section` (10), et relègue le 50 à côté de la touche Majuscule gauche,
là où AZERTY tape `<`. `escapeRowKey` interroge donc `KBGetLayoutType`. Le
supposer à 50 partout est ce qui rendait ces quatre raccourcis muets sur un
clavier français : ils étaient bien enregistrés — `RegisterEventHotKey` rendait
`noErr` —, simplement sur une autre touche que celle annoncée.

De là une règle sur les **libellés** : hormis la rangée de chiffres, nommée par
sa position parce que ce sont les numéros d'emplacement, et les touches qui ne
tapent rien (⇥ ⎋ ↩ flèches…), `keyName` demande le caractère à la **disposition
active** via `UCKeyTranslate`. Aucune table figée : c'en était une qui affichait
« @ » pour le keycode 50, et « A » pour la touche marquée Q d'un AZERTY. La
table est résolue **une seule fois**, dans un `static let` — appelée de
plusieurs fils à la fois, `TISCopyCurrentKeyboardLayoutInputSource` abandonne
sur SIGABRT, ce que la suite de tests parallèle a mis au jour.

Changer un défaut ne suffit pas : les préférences déjà enregistrées ne repassent
jamais par la branche « premier lancement ». D'où `Preferences.defaultsVersion`
et `adoptDefaults(from:)`, qui ne réécrit que les valeurs **encore identiques à
l'ancien défaut** — un raccourci personnalisé est un choix. La génération est
inscrite dans la sauvegarde, ce qui donne au passage la seule façon de
distinguer « jamais eu ce réglage » de « effacé exprès ».

### Enchaîner les persos au clic

[ClickAdvanceWatcher.swift](Sources/Synfus/ClickAdvanceWatcher.swift) : un clic
modifié sur un client de jeu passe au perso suivant, une fois le clic délivré.

La limite est nette et ne doit pas bouger. **Synfus n'émet, ne rejoue et ne
duplique aucun évènement.** Un clic reste un clic, et il en faut toujours autant
que de persos ; la seule chose automatisée est le changement de fenêtre, que
`cycleNext` fait déjà au clavier. Rejouer une même action sur plusieurs clients
serait un multiplicateur, c'est-à-dire exactement ce que les conditions
d'utilisation de Dofus interdisent — et ce que le dépôt refuse au même titre
qu'il refuse d'embarquer les visuels d'Ankama. Aucun délai n'est randomisé :
`settleDelay` est fixe et n'existe que pour laisser le client traiter le clic
avant de perdre le focus.

**Le clic est nu, et c'est le résultat d'une correction.** La première version
demandait un clic modifié — ⌘-clic — pour n'agir que sur ces clics-là. Mesuré en
jeu : le client reçoit bien ces clics, mais avec le drapeau dessus, et ne les
traite pas comme des clics ordinaires. Déplacer un perso passait, parler à un
PNJ non. Synfus ne peut rien y faire — il observe, il ne réécrit pas ; retirer
le modificateur de l'évènement demanderait exactement le `CGEventTap` que le
projet refuse. D'où l'inversion : c'est le **mode** qui porte l'intention, et le
jeu reçoit le clic qu'il attend.

La bascule est franche : le mode reste ce qu'on en a fait jusqu'à ce qu'on le
rebascule, par `advanceArmHotKey` ou par la flèche de la barre. Pas de
désactivation automatique en fin de tour — c'est une bascule, pas une amorce à
usage unique. La flèche verte est ce qui empêche de l'oublier.

Son raccourci a un défaut (⌘< sur un clavier ISO) alors que `toggleBar` n'en a
pas, et ce n'est
pas une incohérence : il n'est **réservé auprès du système que lorsque
`advanceOnClick` est vrai**, donc il ne confisque rien à qui n'utilise pas la
fonction.

L'observation passe par `addGlobalMonitorForEvents`, **passif** — rien n'est
intercepté ni modifié —, et sur `.leftMouseUp` plutôt que `.leftMouseDown` : à
l'appui, le relâchement n'est pas encore parti, et prendre le focus entre les
deux laisse le client avec un bouton jamais relâché. Elle porte sur la souris
seule, ce qui préserve la règle posée pour les raccourcis : l'app ne voit pas ce
qui est tapé. Reste une inconnue que la documentation d'Apple ne tranche pas —
un moniteur de souris réclame-t-il « Surveillance de la saisie » ? — d'où le
compteur `seenClicks` affiché dans les réglages : à zéro après un clic, c'est
que macOS ne livre rien.

Aucun repère « déjà passé » n'est affiché, et c'est un choix après essai : le
mode suit l'ordre de la barre et le surlignage du perso courant dit déjà où l'on
en est. Une coche par perso visité n'ajoutait qu'un clignotement de plus dans un
mode où l'on clique en continu. Le seul témoin est la flèche de la barre, qui
dit si le mode est actif — et il le faut, puisqu'il ne s'éteint pas tout seul.

### Fermer les clients

Le client gèle systématiquement à la fermeture chez certains joueurs, qui
finissaient chaque session dans « Forcer à quitter ». `WindowManager.close`
automatise l'escalade : `terminate()` (Quit Apple Event — un client gelé
l'ignore), puis `forceTerminate()` si le processus est toujours là après 2 s.
C'est une opération de **processus**, pas une saisie — la règle « Synfus n'émet
aucun évènement » reste entière. Points d'entrée : clic droit sur une pastille
(« Fermer “Nom” »), « Fermer tous les persos » dans le menu contextuel de la
barre et la barre de menus.

**L'envoi du Quit Apple Event peut bloquer plusieurs secondes** quand le client
est déjà gelé — c'est ce qui figeait Synfus au moment de fermer. `terminate()`
part donc d'une `Task.detached` ; le `forceTerminate()`, un signal, ne bloque
jamais et reste sur le main actor. Pendant la fermeture, le pid est dans
`closingPIDs` : l'inventaire ne l'interroge plus (questionner l'Accessibilité
d'un mourant, c'est payer la borne d'une seconde à chaque tour), `FreezeWatcher`
ne le sonde pas, et sa pastille — maintenue par la mémoire — porte un indicateur
d'attente jusqu'à la mort du processus.

[FreezeWatcher.swift](Sources/Synfus/FreezeWatcher.swift) rattrape en plus les
fermetures qui ne sont **pas** passées par Synfus. Un client gelé après
fermeture est, vu d'ici, un processus vivant sans aucune fenêtre — exactement
comme un dormant sain sur un espace plein écran inactif. Ce qui les distingue
est la **réponse** : un dormant sain répond à l'Accessibilité (une liste vide
est une réponse), un gelé laisse la sonde expirer
(`AXUIElementSetMessagingTimeout` par élément, 0,3 s). La règle d'abattage est
volontairement stricte — sans fenêtre **et** muet à trois sondes consécutives
espacées de 5 s — pour ne jamais viser un vivant : un client qui charge a une
fenêtre, un dormant répond en quelques millisecondes. Chaque abattage est
consigné dans le Diagnostic ; la bascule `killFrozenClients` (onglet Persos)
est active par défaut.

### Rangement des fenêtres

[WindowArranger.swift](Sources/Synfus/WindowArranger.swift) applique une
disposition — côte à côte, mosaïque, un grand + vignettes — aux fenêtres des
clients en posant `kAXPosition`/`kAXSize`, et rien d'autre : la règle « aucun
évènement synthétisé » vaut ici aussi. Le calcul des cadres est isolé dans
[LayoutComputer.swift](Sources/Synfus/LayoutComputer.swift), une logique pure
(zone + nombre → cadres, repère AX y vers le bas) testée dans
[LayoutComputerTests.swift](Tests/SynfusTests/LayoutComputerTests.swift) — la
conversion Cocoa → AX (`zoneAX`) comprise, multi-écrans inclus.

Les exclusions sont des décisions : un perso `dormant` (élément AX périmé) et
une fenêtre en plein écran (lue sur l'attribut littéral `"AXFullScreen"` — on ne
sort jamais personne du plein écran d'autorité) sont écartés, avec leur raison
dans le `Rapport` publié, affiché dans l'onglet Diagnostic. Tout est ramené sur
**un seul** écran — celui du perso au premier plan — et la pose se fait
**taille → position → taille** : certains clients plafonnent la taille tant que
la fenêtre chevauche son ancien écran.

Quatre dispositions : côte à côte, mosaïque, un grand + vignettes, et
**empilés plein cadre** (`.empilee`, la seule où les cadres se recouvrent —
chaque client occupe tout l'écran, la barre fait tourner la pile). S'y ajoutent
deux bascules hors `LayoutComputer` : **tout en plein écran** (un espace par
perso, attribut littéral `"AXFullScreen"` posé y compris sur les dormants —
le basculement passe par l'objet fenêtre, hypothèse rapportée au Diagnostic)
et son inverse. « Rapatrier les fenêtres des autres bureaux » a été étudié et
écarté : aucune API publique ne déplace une fenêtre entre espaces.

Points d'entrée : le **bouton de la barre flottante** (`ArrangeMenuButton`,
dans la zone des modes — le seul clic droit s'était avéré introuvable), le
sous-menu de la barre de menus, le clic droit, et un raccourci optionnel
**sans défaut** (modèle `toggleBar`) qui rejoue `Preferences.lastArrangement`.

Le geste **« Lancer la session »** (`WindowManager.lancerSession`) compose des
gestes existants : ranger selon la dernière disposition, basculer sur le
perso 1, armer l'enchaînement si `advanceOnClick` — raccourci optionnel sans
défaut (`sessionHotKey`).

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

L'inventaire `SCShareableContent` fait le tour de toutes les fenêtres du système
et coûte bien plus que la capture elle-même : il est fait **une fois par
rafraîchissement**, pour tous les persos demandés, et non une fois par perso. Les
captures qui suivent restent séquentielles, faute de pouvoir faire traverser un
`SCWindow` — non `Sendable` — vers une tâche fille.

L'appariement écarte les candidats trop petits pour être une fenêtre de jeu,
avec le seuil de `WindowManager.isGameWindow`. Sans ce filtre, les info-bulles
et panneaux hors écran que ScreenCaptureKit expose au nom du même processus
faisaient passer un client parfaitement ordinaire pour ambigu, et son aperçu
restait vide. Deux vraies fenêtres de jeu dans un même processus restent, elles,
un cas où l'on renonce : mieux vaut aucun aperçu que celui du mauvais perso.

La vignette a une **taille fixe**, hauteur comprise. Laisser le panneau se
dimensionner sur l'image revenait à le faire dépendre de l'instant où la capture
arrive : le premier perso survolé avait le temps d'être capturé, les suivants
s'ouvraient sur le cadre d'attente puis se redimensionnaient et se replaçaient.

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

La marque — **la Couvée** : trois œufs de dragon, l'émeraude écaillé devant, la
turquoise mouchetée et le pourpre ondé qui dépassent derrière ; un œuf par
compte, le perso actif au premier plan — est décrite **une seule fois**, dans
[SynfusMark.swift](Sources/Synfus/SynfusMark.swift) : un moteur pur
CoreGraphics, sans AppKit ni SwiftUI, pour rester compilable hors de l'app. Le
dessin suit la grammaire visuelle d'Ankama (contour unique sombre, volume par
dégradé, détails ton sur ton, brillance en croissant) sans reprendre aucun
asset du jeu — chaque tracé est original, la règle de l'article 13.2 reste
entière. Cette description sert deux usages :

| Usage | Par |
| --- | --- |
| Icône du bundle (`.icns`, `.png`) | [Tools/AppIconExport.swift](Tools/AppIconExport.swift) |
| Symbole de la barre de menus | `SynfusGlyph.menuBarImage()` |

La poignée de la barre flottante a porté le glyphe un temps ; elle est redevenue
un grip de points — le glyphe n'y disait rien du déplacement. `SynfusGlyphView`,
la version SwiftUI du dessin, reste disponible pour le prochain usage.

```sh
./Tools/generate-app-icons.sh   # régénère Resources/Synfus.{icns,png}
```

Le script compile `SynfusMark.swift` **tel quel** avec l'exportateur : le bundle
et l'app dessinent donc rigoureusement la même marque. Ne jamais retoucher les
PNG à la main — modifier la marque veut dire modifier `SynfusMark` puis relancer
le script. C'est aussi pourquoi `SynfusMark` ne doit importer que CoreGraphics et
Foundation : un `import AppKit` casserait la compilation du générateur.

Le repère de description est **256 × 256, y vers le bas** — celui de la maquette
validée sur la planche d'exploration (artifact « L'Œuf de Synfus »).
`roundedInsetRatio` porte la marge Apple (824/1024), `eggAspect` fixe la
silhouette (0,772 — entre l'œuf de poule et le galet aplati, tous deux essayés
et rejetés), et `texturesBelow` (96 px) abandonne les peaux — écailles,
mouchetures, ondes — aux tailles où leurs traits ne survivraient pas.

[Resources/Synfus.svg](Resources/Synfus.svg) est la maquette du **logo
précédent** (l'œuf filaire aux trois fenêtres), gardée comme archive : elle ne
correspond plus au rendu.

`SynfusGlyph` réduit la couvée à sa silhouette : les trois œufs en aplat,
l'œuf de tête détouré par un mince **jour transparent** — dans une image
*template*, seule l'opacité compte, le détourage passe par un effacement de
l'alpha (`.clear` / `.destinationOut`), jamais par un trait de couleur. Aucune
peau n'y survit : la matière reste sur l'icône.

## Publication

Un tag `v*` poussé déclenche
[release.yml](.github/workflows/release.yml) : runner `macos-26`, compilation
arm64 + x86_64, DMG et release GitHub. Les builds de CI sont signés ad-hoc et non
notarisés, d'où le `xattr -dr com.apple.quarantine` documenté dans le README.
