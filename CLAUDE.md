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
./build.sh                         # produit dist/Synfus.app (plugin et profil embarqués) + dist/fr.synseria.synfus.sdPlugin
./build.sh --install               # installe dans /Applications et relance
VERSION=0.0.3 ARCH=x86_64 ./build.sh
./make-dmg.sh dist/Synfus.app dist/Synfus-0.0.3-arm64.dmg
./Tools/generate-app-icons.sh      # régénère Resources/Synfus.{icns,png}
./Tools/fetch-ankama-assets.sh     # télécharge emblèmes et icônes de sorts dans Resources/Ankama (gitignoré)
SYNFUS_ANKAMA_DIR=$PWD/Resources/Ankama SYNFUS_CAPTURE=~/Library/Logs/Synfus/captures/x.png swift test --filter RealCapture   # calibrage sur une vraie capture
nc -U ~/Library/Application\ Support/Synfus/streamdeck.sock   # lire l'état poussé au plugin
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
  est simple : l'état vit sur le main thread. Les classes à état sont `@MainActor`
  (`Preferences` comprise), les callbacks Timer et notification repassent par
  `MainActor.assumeIsolated`, et le callback C de `HotKeyManager` — qui ne peut
  rien capturer — franchit la frontière via `DispatchQueue.main.async`.
  Toute nouvelle classe à état doit être `@MainActor` plutôt que d'obtenir une
  exemption. Les deux exceptions sont des **acteurs sans état partagé** qui
  font du travail bloquant : `PreviewCaptureEngine` (captures) et
  `ClientInventoryEngine` (inventaire Accessibilité). Il n'y entre et n'en sort
  que des valeurs `Sendable`.
- **Un seul foyer par logique.** Pas deux fonctions qui font à peu près la même
  chose : la lecture AX est dans `AccessibilityReader`, la reconnaissance d'un
  processus Dofus dans `DofusProcesses`, l'escalade de fermeture dans
  `ClientTerminator`, le décodage des titres dans `WindowTitle`. Avant d'écrire
  une fonction, chercher celle qui existe ; quand une correction touche un
  chemin, vérifier que son jumeau en bénéficie — le gel à la fermeture externe
  venait exactement de là : `close()` déportait ce que l'inventaire refaisait
  sur main.
- Les constantes `extern CFStringRef` de l'API Accessibilité (par ex.
  `kAXTrustedCheckOptionPrompt`) sont vues comme des `var` globales et refusées
  par la concurrence stricte : leur valeur littérale est citée directement.
- `build.sh` signe avec le certificat local **« Synfus Dev »** s'il existe
  (`./Tools/make-signing-identity.sh` le crée une fois : auto-signé, approuvé
  pour la signature de code dans le trousseau de session — macOS demande le
  mot de passe à cette étape, sans elle `codesign` refuse l'identité), sinon
  avec un certificat *Apple Development*, sinon ad-hoc — et là, l'identité
  change à chaque build et l'Accessibilité est à réautoriser à chaque fois. Toucher à la signature ou au `BUNDLE_ID` change
  l'identité vue par TCC et **oblige à réautoriser l'Accessibilité** — et, le
  `BUNDLE_ID` nommant aussi le fichier de préférences, remet les réglages à zéro.
  Il vaut `fr.synseria.Synfus` : le reverse-DNS d'un domaine réellement détenu.

## Architecture

App AppKit `LSUIElement` (barre de menus, pas de Dock), point d'entrée
`SynfusMain` dans [App.swift](Sources/Synfus/App/App.swift). Tous les composants sont
des singletons `@MainActor` (`.shared`), la plupart `ObservableObject` observés
par les vues SwiftUI. `applicationDidFinishLaunching` les démarre dans cet ordre :
`WindowManager` → `HotKeyManager` → `MenuBarController` → `AttentionWatcher` →
`FloatingBarController`.

### Arborescence

`Sources/Synfus/` est rangé par domaine — SwiftPM compile les sous-dossiers
sans rien déclarer dans `Package.swift`. Un nouveau fichier va dans le dossier
de son domaine ; un fichier qui n'en a pas est le signe d'un domaine à créer.

| Dossier | Contenu |
| --- | --- |
| `App/` | Point d'entrée, intégrité du bundle, démarrage automatique, `PressePapiers` (l'unique écriture presse-papiers) |
| `Accessibilite/` | Lecture AX partagée, `--dump-windows`, titres à travers les espaces |
| `Clients/` | `DofusClient`, `WindowTitle` (titres, pur), `ClientMemory` (mémoire et tri, pur), `Equipes` (équipes, pur), `WindowManager`, `FreezeWatcher` |
| `Invitations/` | `/invite Nom` par presse-papiers : `InvitationComposer` (pur) et `InvitationClipboard` |
| `Attention/` | Détection du rebond du Dock |
| `Raccourcis/` | Raccourcis globaux, enregistreur, enchaînement au clic |
| `Rangement/` | Dispositions de fenêtres, `LayoutComputer` (pur) |
| `Apercus/` | Captures ScreenCaptureKit et panneau d'aperçu |
| `Preferences/` | `Preferences` et son protocole de stockage |
| `Classes/` | Classes du jeu et icônes fournies par l'utilisateur |
| `Marque/` | La Couvée : `SynfusMark` (CoreGraphics pur) et `SynfusGlyph` |
| `Interface/` | `MenuBarController` ; `Barre/` (barre flottante et ses contrôles) ; `Reglages/` (une vue par onglet + contrôleur de fenêtre) |
| `StreamDeck/` | L'interface physique contextuelle : `Sorts/` (reconnaissance de la barre), `Profils/` (sorts par perso, touches), `Liaison/` (protocole et socket), `Combat/` (détection combat) |
| `../SynfusDeck/` | Le plugin Elgato — second target, binaire séparé, sans code partagé : le protocole JSON est le contrat |

Les logiques pures ont leur fichier propre (`WindowTitle`, `ClientMemory`,
`LayoutComputer`, `BounceDetector`, `FreezeStrikes`…) : c'est ce qui les rend
testables sans écran, et c'est là que les tests pointent.

### Découverte des persos — le point central

[WindowManager.swift](Sources/Synfus/Clients/WindowManager.swift) est le cœur. Il énumère
toutes les fenêtres AX des processus dont le bundle ID contient `dofus`, puis
**dérive tout du titre de la fenêtre** (`« Nom - Classe - version - Release »`) :

- `isCharacterWindow` écarte les clients restés à l'écran de connexion (titre
  « Dofus » seul). C'est essentiel : les inclure décalerait la numérotation des
  slots, donc les raccourcis.
- `characterName` = premier segment, `characterClass` = deuxième segment.
  Tout le décodage du titre vit dans `WindowTitle` (Clients/), pur et testé
  (`TitreDeFenetreTests`).
- L'icône du Dock **ne peut pas** servir de repère : tous les clients partagent
  le même bundle `Dofus.app`, donc la même icône. C'est la raison d'être de
  toute l'approche par titre.

Aucune notification système ne signale un changement de titre (reconnexion,
changement de perso) : un `Timer` de 2 s rafraîchit, complété par les
notifications `NSWorkspace` (lancement / terminaison / activation). Celles-ci
passent par `refreshSoon()` et non `refresh()` : un changement d'application en
émet deux, et enchaîner deux inventaires AX double le gel au moment précis où
l'utilisateur bascule. Le timer, lui, saute son tour si un inventaire date de
moins d'une seconde. Une bascule faite par Synfus est reconnue à
`selfActivatedPID`, posé dans `focus()` : la notification d'activation qui en
découle n'apprend rien, et l'inventaire attend 1 s (`refreshSoon(after:)`, qui
ne garde qu'une échéance, la plus tardive) — le temps que la transition
d'espace s'achève. `focus()` ne pose `kAXMain`/`kAXRaise` que s'il y a
plusieurs fenêtres à départager dans le processus.

**L'inventaire tourne hors du main thread.** `refresh()` ne lit plus rien :
il compose une `InventoryRequest` avec l'état de l'instant (pids vivants dans
l'ordre de lancement, pids à sauter, candidats cross-space) et l'envoie à
`ClientInventoryEngine`, un `actor` à **exécuteur dédié** (`DispatchSerialQueue`
— des IPC bloquants d'une seconde n'ont rien à faire sur le pool coopératif)
dont `inventory(_:)` ne contient aucun `await` : un inventaire à la fois, par
construction. Le résultat, des valeurs (`InventoryResult`, `DofusClient` est
`Sendable` grâce à `AXHandle`), revient sur main dans `apply`, qui décide avec
l'état **courant** : `ClientMemory.consolidate` (pur, testé) pour la mémoire et
les découvertes cross-space, puis veilleur de gel, préférences, tri,
publication. La politique de lancement, `InventoryScheduling` (pure, testée),
garantit au plus un inventaire en vol et un différé, quelle que soit la
rafale, et jette un résultat d'une génération dépassée. `refreshed()` attend
qu'un inventaire lancé après l'appel soit appliqué — c'est ce que l'arrangeur
utilise. Les **gestes** AX (focus, rangement, plein écran) restent sur main :
ce sont des actions utilisateur sur un client à la fois, et `isReachable`
leur épargne les processus en fermeture ou suspects. Cette séparation —
inventaire hors main, gestes sur main — est une décision, pas un oubli.

Chaque fenêtre est lue en **un seul IPC** (`AXUIElementCopyMultipleAttributeValues`
pour sous-rôle, taille et titre), et rien n'est republié sans avoir changé :
`frontmostPID`, `frontmostIsDofus` et `clients` ne sont réaffectés qu'en cas
de différence. Réordonner les persos passe par `resort()`, un simple retri de
`clients` selon `characterOrder` — pas un inventaire —, avec le même
comparateur pur que `refresh()` (`sorted(_:by:)`, testé dans
`ClientOrderTests`). Le menu de la barre de menus se construit sur `clients`
tel quel et ne demande qu'un `refreshSoon()`.

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

La règle de fusion, `ClientMemory.withRemembered`, est pure et testée. Elle ne ressuscite que
les processus **silencieux** — ceux qui ne rendent aucune fenêtre. Un client
revenu à l'écran de connexion en rend une, simplement sans perso : le
ressusciter afficherait un perso qui n'est plus en jeu.

Un client déjà sur un espace inactif au démarrage de Synfus n'a jamais livré son
titre à l'Accessibilité. Quand l'enregistrement de l'écran est accordé (celui
des aperçus), [CrossSpaceTitles.swift](Sources/Synfus/Accessibilite/CrossSpaceTitles.swift)
lève cette limite : `CGWindowListCopyWindowInfo` voit à travers les espaces, et
`discoveredAcrossSpaces` — pure, testée — fabrique le dormant à partir du titre
lu. La lecture n'a lieu que pour les pids sans aucune mémoire, et au plus une
fois par 10 s pour un même pid (`crossSpaceChecked` — un client au login sur
un autre bureau n'a rien à livrer et le resterait à chaque tour), et
l'autorisation n'est **jamais demandée** par ce chemin : sans elle, la limite
demeure, documentée dans les réglages.

Tous les appels AX du processus sont bornés à 1 s
(`AXUIElementSetMessagingTimeout` sur l'élément système, posé dans `start()`) :
un client gelé ne répond jamais, et sans borne chaque inventaire resterait
suspendu plusieurs secondes sur lui. La borne posée sur l'élément système est
**par processus** (header SDK), elle vaut donc pour l'acteur ; elle reste à
1 s même hors main — l'acteur est série, l'allonger retarderait la fraîcheur
de tous les autres persos. Le Diagnostic affiche la durée du dernier
inventaire : ~1 s pendant qu'un client gèle, barre fluide, c'est le déport qui
fait son travail.

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
[AttentionWatcher.swift](Sources/Synfus/Attention/AttentionWatcher.swift) contourne en
observant, via [DockInspector.swift](Sources/Synfus/Attention/DockInspector.swift), la
géométrie AX des icônes du Dock : `AXPosition.y` chute pendant le rebond. La
décision elle-même est isolée dans
[BounceDetector.swift](Sources/Synfus/Attention/BounceDetector.swift), une struct pure —
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
republié sans avoir changé, et rien de ce qui ne change pas ne doit être relu.
Deux mesures en découlent :

- **Cache de structure.** Retrouver les icônes Dofus — enfants du Dock, titre
  de chaque icône, sous-rôle, état de lancement — coûtait trente à cinquante
  allers-retours Accessibilité par tour, alors que seules position et taille
  varient. [DockGeometryReader.swift](Sources/Synfus/Attention/DockGeometryReader.swift)
  garde les éléments AX (`DockInspector.Structure`) et, en régime permanent,
  ne lit que la géométrie, en **un** IPC par élément
  (`AXUIElementCopyMultipleAttributeValues`). Le tour complet ne revient qu'au
  premier tour, quand le nombre de pids Dofus distincts diffère du nombre
  d'icônes en cache, quand une lecture légère échoue (élément invalidé), et au
  plus tard toutes les 2 s en filet. La décision, `DockRefreshPolicy`, est pure
  et testée. `BounceDetector` reçoit exactement le même relevé qu'avant.
- **`AttentionDiagnostics`.** `pairing` et `dockReading` vivent dans cet objet
  séparé, observé par les seuls réglages : sur `AttentionWatcher`, ils
  réévaluaient la barre flottante — qui n'a besoin que d'`alerting` — à chaque
  mouvement du Dock. Les chaînes de diagnostic ne sont recomposées que si le
  relevé a numériquement changé, et la liste des persos triée par pid est tenue
  par abonnement à `$clients`, pas retriée à chaque tour.

C'est aussi pourquoi le tour de boucle sort avant d'interroger le Dock
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
[AttentionProbe.swift](Sources/Synfus/Attention/AttentionProbe.swift) est l'outil
d'exploration qui a servi à établir ce mécanisme ; il journalise tout changement
d'attribut dans `~/Library/Logs/Synfus/attention.log`.

### Raccourcis globaux

[HotKeyManager.swift](Sources/Synfus/Raccourcis/HotKeyManager.swift) utilise Carbon
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

[HotKey.swift](Sources/Synfus/Raccourcis/HotKey.swift) stocke des **keycodes de position
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

[ClickAdvanceWatcher.swift](Sources/Synfus/Raccourcis/ClickAdvanceWatcher.swift) : un clic
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

[FreezeWatcher.swift](Sources/Synfus/Clients/FreezeWatcher.swift) rattrape en plus les
fermetures qui ne sont **pas** passées par Synfus. Un client gelé après
fermeture est, vu d'ici, un processus vivant sans aucune fenêtre — exactement
comme un dormant sain sur un espace plein écran inactif. Ce qui les distingue
est la **réponse** : un dormant sain répond à l'Accessibilité (une liste vide
est une réponse), un gelé laisse la sonde expirer. La règle d'abattage est
volontairement stricte — sans fenêtre **et** muet à trois sondes consécutives
espacées de 5 s — pour ne jamais viser un vivant : un client qui charge a une
fenêtre, un dormant répond en quelques millisecondes. Chaque abattage est
consigné dans le Diagnostic ; la bascule `killFrozenClients` (onglet Persos)
est active par défaut.

**La sonde, c'est l'inventaire.** `refresh()` interroge déjà `kAXWindows` sur
chaque client : c'est lui qui constate le mutisme (`.cannotComplete`) et le
transmet en `mutePIDs`. Le veilleur ne sonde plus rien lui-même — la double
sonde coûtait 1 s de borne globale plus 0,3 s, toutes les 2 s pendant quinze
secondes. Un pid pris en défaut (`suspects`) n'est réinterrogé qu'à l'échéance
(`shouldProbe`), avec la **même** borne d'une seconde que les autres : une
borne plus courte lui ôterait tout moyen de se blanchir, et un client vivant
mais lent — chargement, combat chargé — finirait abattu. Entre deux
échéances, l'inventaire le saute et la mémoire l'affiche atténué. Un pid
silencieux mais non sondé garde son ardoise : la sonde est un **fait
rapporté** par l'inventaire (`probedPIDs`), pas déduit de l'échéance — entre
le départ de l'inventaire et son retour, une échéance a pu passer, et un
suspect sauté au départ serait sinon blanchi sur une réponse jamais demandée.
La comptabilité est une struct pure, `FreezeStrikes`, testée dans
`FreezeStrikesTests` ; les strikes sont comptés même quand `killFrozenClients`
est désactivé, seul le coup de grâce en dépend — et un condamné qu'on n'achève
pas n'est plus resondé que toutes les 30 s (`condemnedInterval`). Le coup de
grâce lui-même, comme celui de `close()`, passe par `ClientTerminator`.

### Rangement des fenêtres

[WindowArranger.swift](Sources/Synfus/Rangement/WindowArranger.swift) applique une
disposition — côte à côte, mosaïque, un grand + vignettes — aux fenêtres des
clients en posant `kAXPosition`/`kAXSize`, et rien d'autre : la règle « aucun
évènement synthétisé » vaut ici aussi. Le calcul des cadres est isolé dans
[LayoutComputer.swift](Sources/Synfus/Rangement/LayoutComputer.swift), une logique pure
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

### Équipes

À huit comptes, on joue rarement tout le monde d'un coup. Les équipes
([Equipes.swift](Sources/Synfus/Clients/Equipes.swift), pur, testé dans
`EquipesTests`) sont une **appartenance, pas un ordre** : une `Equipe` est
une liste de noms, sous-ensemble de `characterOrder`, et l'effectif garde
l'ordre de la barre. Jusqu'à `Equipes.maximum` (4). Ni nom ni couleur : un
secteur montre son numéro et un point par membre à la couleur de sa classe.

`WindowManager` publie deux listes. `clients`, **tous** les persos — c'est
la liste de l'inventaire, de « Fermer tous les persos », de la détection
d'attention (appariement Dock par pid) et des réglages. `effectif`,
`clients` restreint à l'équipe active — c'est ce que voient la barre (pastilles
et numéros), `focus(slot:)` (⌘1 = premier de l'équipe), `cycle(by:)` (donc
suivant/précédent et l'enchaînement au clic), `lancerSession`, le rangement
des fenêtres (le rapport dit l'équipe), l'aperçu d'ensemble et le menu de la
barre de menus. Un seul foyer de calcul, `republierEffectif`, appelé à chaque
publication de `clients` et par un abonnement `CombineLatest` aux préférences
— qui reçoit les valeurs émises, car `@Published` publie **avant**
d'affecter. Rien n'est republié sans avoir changé.

L'équipe active (`equipeActive`) est un **état de session**, jamais
persisté : Synfus démarre toujours sur « Tous ». Les compositions, elles,
sont dans `Preferences.equipes`, gardées ⊆ `characterOrder` par `forget` et
`purgeOrder`. Un index d'équipe devenu orphelin ramène à « Tous »
(`activeValide`). Un perso au premier plan hors de l'équipe n'a pas de
`currentIndex` : `cycle` va au premier de l'effectif. Les noms non
persistables (« Dofus 3.3.4.9 », « Nom (2) ») n'ont jamais d'équipe et
n'apparaissent que sous « Tous ».

Il n'y a **pas de bascule** : la fonction n'existe que par ses équipes. La
seconde rangée de la barre ([TeamRow.swift](Sources/Synfus/Interface/Barre/TeamRow.swift))
n'apparaît que s'il y a une équipe — ou le temps d'un glisser, pour en créer
une : « Tous », un secteur par équipe, et « + » tant qu'on peut en créer une.
Une équipe naît d'un dépôt sur « + » et disparaît quand elle se vide, rien à
configurer. Pendant le glisser les secteurs **s'agrandissent** (`agrandi`) :
une cible se vise, un onglet se lit. Le **même** `DragGesture` que le
réordonnancement sert au dépôt : au-dessus d'un secteur, on surligne sans
permuter (`dropTarget`), et l'affectation se fait au relâchement — jamais en
cours de geste, chaque écriture de préférence étant un JSON et un redessin.
Le début du glisser ferme l'aperçu au survol et `hover` l'ignore tant que
`dragging` est posé : il cachait la rangée visée. `coordinateSpace` est posé
sur le `VStack` pour que cadres de pastilles et de secteurs se comparent dans
un seul repère. L'onglet Persos offre le même geste par un `Picker` par ligne.
Le raccourci « Équipe suivante » est sans défaut et n'apparaît qu'avec une
équipe. La rangée change la hauteur du panneau en plein geste : AppKit
gardant l'origine en bas à gauche, `FloatingBarController.topEdge` tient le
**bord haut** en place — sinon les pastilles descendaient sous la souris.

### Invitations par presse-papiers

Inviter sept persos à la main, c'est sept `/invite Nom` tapés. Synfus les
**compose**, il ne les envoie pas : la règle « aucun évènement émis » reste
entière, [PressePapiers.swift](Sources/Synfus/App/PressePapiers.swift) est
l'unique écriture dans `NSPasteboard`, et le joueur colle lui-même (⌘V ↩) —
un geste par invité, comme un clic par perso dans le mode « enchaîner ».
Envoyer la commande au tchat serait exactement la saisie synthétisée que le
dépôt refuse.

[InvitationComposer.swift](Sources/Synfus/Invitations/InvitationComposer.swift)
(pur, `InvitationComposerTests`) choisit qui : l'effectif sans le **chef** —
le perso devant, par pid —, les noms **du titre** (`characterName(fromTitle:)`,
jamais « Nom (2) », que le jeu ne connaît pas), dédoublonnés, clients au
login exclus, dormants inclus. Le raccourci `inviteHotKey` — **⌘: par
défaut** (keycode 47, la touche « : » d'un AZERTY ; c'est aussi
« Orthographe et grammaire » dans les apps de texte, un choix de
l'utilisateur, posé à la génération 6 des défauts) tourne en boucle. Le
**chef est fixé au premier appui** et le reste jusqu'au dernier invité
(`tourTermine`) ou s'il quitte l'effectif : avec le passage automatique,
l'invité rebondit et Synfus bascule dessus — sans cela, le tour reprendrait du
point de vue du nouveau perso et réinviterait le chef. Le clic droit d'une
pastille copie l'invitation de ce perso-là sans toucher au tour.
`inviteFormat` (`/invite %nom`) est un réglage texte : le jour où la commande
change, personne ne recompile. La pastille copiée porte `CopiedBadge` 1,2 s,
en overlay — la barre ne change pas de taille. « Rétablir les raccourcis par
défaut » (`Preferences.resetShortcuts`) remet chaque raccourci à son défaut,
efface ceux qui n'en ont pas, garde le nombre d'emplacements.

### Préférences

[Preferences.swift](Sources/Synfus/Preferences/Preferences.swift) sérialise l'ensemble en
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

- **Un réglage n'apparaît que s'il sert.** Les options d'une fonction coupée
  sont masquées, pas grisées : l'onglet Sorts n'existe qu'avec le Stream Deck
  activé, l'onglet Stream Deck se réduit à sa bascule tant qu'elle est
  fausse, les options de la barre à « Afficher la barre », le raccourci
  d'enchaînement au mode disponible. Une nouvelle option suit la règle.
- [BarView.swift](Sources/Synfus/Interface/Barre/BarView.swift) — barre flottante, hébergée dans
  un `NSPanel` non activable (`canBecomeKey = false`) par
  [FloatingBarController.swift](Sources/Synfus/Interface/Barre/FloatingBarController.swift) :
  un overlay de jeu ne doit jamais capter le clavier. Le déplacement passe par
  `performDrag(with:)` d'AppKit (`WindowDragArea`), pas par un `DragGesture` —
  ce dernier reste toujours un cran derrière la souris. `didMove` arrive en
  continu pendant le geste : `panelMoved` ne coupe `autoCenterBar` que s'il est
  encore vrai et garde la position dans `pendingOrigin`, écrite dans
  `barOrigin` 250 ms après le dernier mouvement (`flushPendingOrigin`, aussi
  appelé à la fermeture de l'app). Écrire à chaque évènement, c'était un JSON
  et un redessin de toutes les vues qui observent `Preferences` par pixel.
  Le timer de 2 s appelle `updateVisibility(force: false)` — il ne touche au
  panneau que si son état est faux —, les notifications gardent `force: true` :
  c'est ce qui remonte la barre au-dessus d'un espace plein écran fraîchement
  activé.
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
- [SettingsView.swift](Sources/Synfus/Interface/Reglages/SettingsView.swift) — barre latérale à
  gauche, quatre sections (Raccourcis, Persos, Classes, Diagnostic) à droite +
  `SettingsWindowController`, qui doit appeler `NSApp.activate(ignoringOtherApps:)`
  car l'app est en mode accessory. À l'ouverture, la fenêtre se place centrée
  sous la barre flottante (`visibleBarFrame`), au centre de l'écran sinon.
- Le réordonnancement des persos dans la barre passe par un `DragGesture` en
  espace de coordonnées nommé, pas par `.onDrag`/`.onDrop` : le drag & drop
  système ne démarre pas de façon fiable depuis un `NSPanel` non activable.
- [MenuBarController.swift](Sources/Synfus/Interface/MenuBarController.swift) — le menu est
  reconstruit à chaque ouverture (`menuNeedsUpdate`). Les raccourcis y sont
  affichés en texte attribué, à titre indicatif : ce sont de vrais raccourcis
  globaux Carbon, pas des key equivalents de menu.
- [PreviewPanelController.swift](Sources/Synfus/Apercus/PreviewPanelController.swift) —
  aperçus des fenêtres, dans un `NSPanel` **distinct** de la barre : celle-ci se
  dimensionne sur son contenu (`fixedSize` + `preferredContentSize`) et se
  recentre à chaque changement de taille, donc y greffer un aperçu la ferait
  sauter à chaque survol. Le panneau est `ignoresMouseEvents`.

### Aperçus des fenêtres

[WindowPreviewService.swift](Sources/Synfus/Apercus/WindowPreviewService.swift) capture
via **ScreenCaptureKit** — `CGWindowListCreateImage` est déprécié depuis
macOS 14. Aucune API publique ne relie un `AXUIElement` à une fenêtre capturable :
l'appariement se fait sur `(pid, titre)`, avec repli sur le pid quand le processus
n'a qu'une fenêtre (le titre change à la reconnexion). C'est une hypothèse au même
titre que l'appariement du Dock, donc testée à part et exposée dans le Diagnostic.

La capture s'exécute hors du main actor et ne rend que du **PNG** : ni `SCWindow`
ni `CGImage` ne franchissent la frontière d'isolation, ce qui évite d'avoir à
plaider leur sendabilité.

L'inventaire `SCShareableContent` fait le tour de toutes les fenêtres du système
et coûte bien plus que la capture elle-même. Il appartient à
`PreviewCaptureEngine`, un `actor` qui le garde en mémoire et ne le refait que
s'il date de plus de 3 s ou si un perso demandé n'y trouve pas sa fenêtre — et
toujours **une fois par rafraîchissement**, pour tous les persos restants, non
une fois par perso. Il n'entre dans l'acteur que des requêtes `Sendable`, il
n'en sort que du PNG. Les captures restent séquentielles, faute de pouvoir
faire traverser un `SCWindow` — non `Sendable` — vers une tâche fille.

Le survol d'une pastille **préchauffe** la capture : `BarView.hover` appelle
`refresh` dès l'entrée, en parallèle des 400 ms d'attente, si aucune vignette
n'est connue pour ce perso et si l'autorisation est déjà accordée — `refresh`
ne la demande jamais, un survol ne doit pas faire surgir une invite.

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

[DofusClass.swift](Sources/Synfus/Classes/DofusClass.swift) est la **source unique** des
19 classes (clé sans accent, libellé, couleur) : y ajouter une entrée la fait
apparaître d'office dans la barre et les réglages. Une classe inconnue reçoit une
teinte dérivée par hachage du nom plutôt que du gris.

[ClassIconStore.swift](Sources/Synfus/Classes/ClassIconStore.swift) : le dépôt
**n'embarque aucune image du jeu** — celles d'Ankama n'ont pas à être
redistribuées. Les icônes sont fournies par l'utilisateur dans
`~/Library/Application Support/Synfus/Classes/<clé>.png` (l'unique état
modifiable ; les images importées sont réencodées en PNG 128 px), ou
téléchargées pour son propre build — voir ci-dessous. Ne jamais ajouter
d'assets de classe au dépôt.

[Tools/fetch-ankama-assets.sh](Tools/fetch-ankama-assets.sh) — un wrapper qui
compile [Tools/FetchAnkamaAssets.swift](Tools/FetchAnkamaAssets.swift) avec
`DofusClass.swift`, pour que les clés soient celles de l'app — télécharge
depuis l'API communautaire DofusDB (le CDN d'Ankama répond 403) les emblèmes
des classes **et** les icônes de sorts — ceux de la fiche de classe, leurs
**variantes** (`spell-variants`, le jeu affiche l'un ou l'autre dessin) et les
**sorts communs** (type 21 : Libération, Cawotte, invocations…) sous la clé
`communs` —, dans `Resources/Ankama/` :
`Classes/<clé>.png`, `Sorts/<clé>/<Nom>.png` (le nom du sort, l'id seulement en cas d'homonymie) et un index `sorts.json`
(`{id, nom, classe, fichier}`). Ce dossier est **ignoré par Git** ; `build.sh`
l'embarque dans `Contents/Resources/Ankama` s'il existe, et
[AnkamaAssets.swift](Sources/Synfus/Classes/AnkamaAssets.swift) le résout —
**Application Support d'abord, bundle ensuite** : ce que l'utilisateur dépose
garde la priorité. La CI n'a pas le dossier, les releases restent sans visuel
du jeu. Un pare-feu applicatif (LuLu) demandera l'accès réseau au programme
compilé, une fois. C'est **la seule forme acceptable** : l'article 13.2 des CGU de
Dofus interdit de distribuer les visuels du jeu sans accord écrit d'Ankama, donc
le dépôt ne transporte que des URL — la copie est faite par l'utilisateur, sur
sa machine, pour son usage personnel. Ne jamais convertir ce script en assets
embarqués, et conserver la mention « Certaines illustrations sont la propriété
d'Ankama Studio et de Dofus — Tous droits réservés », qui est la pratique
constante des sites communautaires tolérés.

La marque — **la Couvée** : trois œufs de dragon, l'émeraude écaillé devant, la
turquoise mouchetée et le pourpre ondé qui dépassent derrière ; un œuf par
compte, le perso actif au premier plan — est décrite **une seule fois**, dans
[SynfusMark.swift](Sources/Synfus/Marque/SynfusMark.swift) : un moteur pur
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

### Stream Deck — reconnaissance des sorts

Le Stream Deck doit afficher les sorts du perso actif ; encore faut-il savoir
lesquels. Plutôt qu'une configuration à la main, [StreamDeck/Sorts/](Sources/Synfus/StreamDeck/Sorts/)
lit la barre de sorts sur une capture de la fenêtre — **à la demande**, comme
opération de configuration, jamais en continu.

- [LumaBitmap.swift](Sources/Synfus/StreamDeck/Sorts/LumaBitmap.swift) : une
  image en gris 8 bits, valeur `Sendable`, fabricable en test sans CoreGraphics.
- [SpellBarLocator.swift](Sources/Synfus/StreamDeck/Sorts/SpellBarLocator.swift)
  : pur. Cherche dans le tiers bas la grille des cases par un **réseau de
  pics** : sur chaque bande horizontale, les bords verticaux font des pics, et
  une rangée est une suite « gauche, droite, gauche, droite… » au même pas —
  le pas est estimé en **fraction** (83,4 px sur la capture de calibrage) et
  chaque case est cherchée à sa place à `tolerance` près, sans dérive. Un
  interstice minimal (`minGap`) écarte les lettres du tchat. Les rangées se
  trouvent de même à la verticale, ancrées sur la bande où les colonnes ont été
  vues, sur les seuls bords nets. Mesuré : 3 × 12 cases au pixel. Ce qui a
  été essayé et écarté : la ligne horizontale la plus forte (c'est le tchat),
  l'autocorrélation sur toute la largeur (noyée), la luminance (le décor est
  clair). `SpellBarLocatorTests` sur images fabriquées ; `RealCaptureTests`
  sur une capture locale via `SYNFUS_CAPTURE`.
- [SpellRecognizer.swift](Sources/Synfus/StreamDeck/Sorts/SpellRecognizer.swift)
  : pur. Compare chaque case aux icônes **de la classe du perso et communes**
  (~57 candidats, index `sorts.json` d'`AnkamaAssets`) par corrélation
  normalisée sur le **picto seul** (`inset` 22 % — le cadre est commun à toute
  la classe, le garder c'était comparer des cadres), à 40 × 40, en tolérant un
  décalage de 2 px (`bestCorrelation`, sur les six meilleurs candidats du tri
  sans décalage). Une case sans contraste est **vide**, pas un sort. Mesuré
  sur la capture de calibrage : 30/36 sûres à 0,85-0,97, 2 vides, 4 objets.
  La **marge** entre le premier et le second candidat est la confiance
  (`isConfident`, seuils 0,7 / 0,12).
  L'OCR est écarté : le nom d'un sort n'apparaît qu'au survol, et Synfus ne
  déplace pas la souris.
- [SpellRecognitionProbe.swift](Sources/Synfus/StreamDeck/Sorts/SpellRecognitionProbe.swift)
  : le banc d'essai du Diagnostic — capture en résolution native (par
  `WindowPreviewService.capture(_:region:)`, le **même** moteur que les
  aperçus, étendu à une zone et à la résolution native), enregistrement dans
  `~/Library/Logs/Synfus/captures/` (jamais dans le dépôt), analyse avec les
  scores par case et les durées. C'est sur ce rapport que se prend la décision
  go/no-go de la reconnaissance automatique.

### Stream Deck — profils, liaison, plugin, combat

**En pause depuis le 15/09/2026** : l'appareil a été renvoyé, plus aucun
développement n'y est fait, le code reste pour la communauté. Il doit
continuer de compiler ; il suit l'équipe active de fait, par `cycle` et
`focus(slot:)`, sans avoir été touché.

Le Stream Deck est une **interface physique contextuelle** : il montre les
sorts du perso que Synfus voit devant, et frappe la touche que le jeu attend.
Trois règles tiennent l'ensemble :

- **Synfus n'émet toujours aucun évènement.** C'est le plugin, `SynfusDeck`,
  qui pose la frappe (`CGEvent`, appui puis relâchement, `Keystroke.press`) —
  un périphérique d'entrée de plus, une pression = une frappe, rien n'est
  rejoué ni multiplié. Il ne frappe que si `dofusDevant` est vrai : jamais
  dans une autre app.
- **L'API locale n'est pas un port réseau.** [StreamDeckLink.swift](Sources/Synfus/StreamDeck/Liaison/StreamDeckLink.swift)
  écoute sur un socket Unix `~/Library/Application Support/Synfus/streamdeck.sock`,
  `chmod 0600` dès qu'il existe, et seulement si `streamDeckEnabled` (faux par
  défaut). Le protocole, [DeckProtocol.swift](Sources/Synfus/StreamDeck/Liaison/DeckProtocol.swift),
  est du JSON par ligne, **descriptif** : Synfus pousse des `DeckPage` (une
  par grille : les touches composées, icônes en base64, actions), et
  n'accepte que `DeckCommand` — `persoSuivant`, `persoPrecedent`,
  `perso(slot)`, `barreSuivante`, `barrePrecedente`, `barrePremiere`, `menu`,
  `pageMenuSuivante`, `activer`, `appareil` — tout ce que la barre flottante
  sait déjà faire, plus l'état de page du deck. Une commande inconnue est
  journalisée et ignorée. La barre active est un état de session, pas une
  préférence.
- **Synfus compose, le plugin rend.** L'action « Touche Synfus »
  (**dynamique**) se place sur toutes les touches ; sa position (ligne puis
  colonne) est son index, et c'est tout ce que le plugin sait d'elle. Les
  actions **classiques** (Sort, Perso suivant, Barre suivante, Menu, Fin de
  tour…) cohabitent : posées n'importe où sur n'importe quel profil, elles
  suivent la touche de leur **rôle** (`DeckTouche.role`, `ActionID.roles`)
  dans la même page composée — le n-ième « Sort » de l'appareil est la
  n-ième case de sort de la page. Deux façons de poser, une seule
  composition.
  [DeckComposer.swift](Sources/Synfus/StreamDeck/Liaison/DeckComposer.swift)
  — **pur, testé** (`DeckComposerTests`) — produit une `DeckPage` par taille
  de grille annoncée (`appareil`) : pour chaque index, l'icône ou le symbole,
  le titre, l'atténuation, et ce qu'un appui court et un appui long font
  (`DeckAction` : une touche du jeu **ou** une commande). Le menu, sa
  pagination, la barre active sont des états de session de `StreamDeckLink`
  (`page`, `menuOuvert`, `pageMenu`), changés par les commandes du plugin —
  et par les boutons du miroir des réglages, par `execute`, le même chemin.
  Le miroir de l'onglet Stream Deck dessine la même `DeckPage` que
  l'appareil : ce qu'on y voit est ce qu'il montre. Toute logique de
  disposition qui apparaîtrait dans le plugin est au mauvais endroit.
- **Les dispositions** ([DeckLayout.swift](Sources/Synfus/StreamDeck/Profils/DeckLayout.swift),
  pur) : une grille de `DeckTile` (source courte, source longue) ;
  `DeckSettings` (mode, pages retenues, `sortLong`, grille personnalisée —
  décodage tolérant, chaque clé a son défaut) est **générique**
  (`Preferences.deck`) ou **propre au perso** (`SpellProfile.deck`,
  prioritaire). `parBarre` : la barre active sur les touches, « barre
  suivante » tourne les barres ; `parRangee` : une barre par rangée, par
  fenêtres de la largeur (1-5, 6-10, 11-12, puis les barres suivantes), et
  `pages` dit lesquelles et dans quel ordre ; `personnalisee` : n'importe
  quelle case de n'importe quelle barre, une commande — c'est là qu'on saute
  et réordonne des sorts sans toucher au jeu. `pages` vaut pour les deux
  modes générés : les barres (ou fenêtres) que « barre suivante » parcourt,
  dans l'ordre. `sortLong` (`deuxNiveaux` par défaut) met en appui long le
  sort **d'en face** — même case de la barre suivante (`sortBarreDecalee`,
  décalage 1) ou de la fenêtre suivante — et en appui très long celui
  d'après (décalage 2) : les trois barres sous dix touches, sans page. Les
  vignettes sont dessinées en bas à gauche (long) et à droite (très long) de
  la touche (`iconeLong`/`iconeTresLong`, `Images.framed(cornerLeft:cornerRight:)`) ;
  une case inconnue de Synfus joue quand même sa touche — le profil peut être
  vide, pas la barre du jeu —, simplement sans vignette. Pendant l'appui, la
  touche montre en grand le seul sort du niveau atteint. **La fin de tour n'a jamais d'action longue** : elle ne doit
  partir que d'un geste voulu. Rien n'est réimporté dans le logiciel Elgato :
  le profil livré ne contient que des touches Synfus, et le paquet comme le
  profil sont embarqués dans l'app (`Contents/Resources`), ouverts d'un
  bouton de l'onglet Stream Deck.
- **Sans client**, la page garde le dernier perso vu, atténué ; les noms des
  sorts ne s'affichent que pendant l'appui (réglage `deckTitres`) ; à une
  seule page, « barre suivante » devient le corps à corps ; l'appui long sur
  « Menu » relit la barre à l'écran (`.reconnaitre` →
  `SpellProfileStore.recognize`, le même foyer que l'onglet Sorts).
- **Gestes** : le SDK ne livre qu'enfoncé / relâché, le plugin mesure. Trois
  niveaux : court, long (`appuiLongMs`, 100 ms), très long
  (`appuiTresLongMs`, 200 ms) — ces seuils valent pour les sorts ; une
  touche ordinaire (menu, perso, relecture des sorts) exige au moins
  350 / 700 ms, un appui long y est un geste voulu. Une touche dont tous les niveaux sont des
  sorts est **progressive** (`DeckTouche.progressif`, réglage
  `appuiProgressif`) : chaque niveau joue **à son seuil** — sélectionner un
  sort dans le jeu ne lance rien, le joueur voit la sélection changer
  pendant qu'il tient et lâche sur la bonne ; le fond de la touche passe au
  bleu puis à l'orange. Les autres touches jouent au relâchement le niveau
  atteint (le dernier dès son seuil) : deux commandes d'affilée se
  contrediraient. Une touche sans niveau au-delà du court joue à
  l'enfoncement. **Pas de double-clic**, décision : il retarderait chaque
  appui et empêcherait de lancer deux fois le même sort — deux appuis sont
  deux frappes, comme au clavier. Aucune répétition au maintien.
- **Le plugin est en Swift, pas en TypeScript.** Le logiciel Elgato lance
  n'importe quel exécutable déclaré en `CodePathMac` avec
  `-port -pluginUUID -registerEvent -info` ; [Sources/SynfusDeck/](Sources/SynfusDeck/)
  s'enregistre sur son WebSocket (`URLSessionWebSocketTask`), se connecte au
  socket de Synfus (reconnexion à délai croissant : il peut être lancé avant
  Synfus), annonce ses grilles, et redessine à chaque `page`. Il ne partage
  **aucun code** avec l'app — `DeckMessages.swift` est le miroir du
  protocole, et c'est voulu : pas de target commun à maintenir pour cinq
  structs. Les **modificateurs sont pressés comme des touches**
  (`Keystroke`), pas seulement posés en drapeau : le client Unity lit l'état
  des touches, et ⌃1 en drapeau jouait la touche 1 nue. Sans Dofus devant,
  Synfus atténue tout et une touche du jeu ramène Dofus (`activer`) ; sans
  Synfus, les touches le disent et une pression le lance. Le plugin bascule
  vers son profil livré (`Plugin/make-profile.sh` → `Synfus.streamDeckProfile`,
  quinze touches Synfus) quand Dofus passe devant, et le rend quand il s'en
  va — `switchToProfile` n'accepte qu'un profil **installé avec le plugin**,
  d'où le paquet `dist/fr.synseria.synfus.streamDeckPlugin`, **embarqué dans
  l'app** et ouvert par le bouton « Installer » de l'onglet Stream Deck — un
  `.sdPlugin` copié à la main ne l'enregistre pas, et `build.sh --install`
  n'installe jamais le plugin : le Stream Deck est optionnel, tout passe par
  Synfus. Le logiciel Elgato n'accepte un paquet que plus récent que
  l'installé (sinon « AlreadyInstalled », rien n'est touché — mesuré dans
  `StreamDeck.log`), d'où la version de build `VERSION.<commits>` dans le
  manifeste. `build.sh` assemble le tout depuis
  [Plugin/](Plugin/). Le plugin journalise dans
  `~/Library/Logs/Synfus/synfusdeck.log`.

[Profils/](Sources/Synfus/StreamDeck/Profils/) : `SpellProfile` (perso →
3 barres × 10 cases, `sortId` DofusDB + nom, `normalize()` complète une
sauvegarde ancienne sans la tronquer), un fichier JSON par perso dans
`Application Support/Synfus/Profils/` (`SpellProfileStore`, exportable,
versionnable par l'utilisateur). `SpellKeyMap` (dans `Preferences`) porte les
touches du jeu par barre — des keycodes de position, la rangée du haut
entière (douze touches, `&…-` sur AZERTY) nue / `⌃` / `⌃⇧`, **jamais ⌘**,
réservé aux emplacements de Synfus — plus `finDeTour` et `corpsACorps`, sans
défaut tant qu'ils ne sont pas confirmés en jeu. Une case qui n'est pas un
sort connu — objet, emote, sort inconnu — garde sa **vignette d'écran**
(`SpellSlot.vignette`, PNG découpé dans la capture, rangé avec le profil) :
c'est ce que le Stream Deck affiche. Une case vide reste vide. L'onglet **Sorts** remplit
un profil au clic, ou par « Reconnaître la barre affichée », qui passe par
`SpellRecognition` — le même foyer que le banc d'essai du Diagnostic — et ne
retient que les cases `isConfident`.

[Combat/](Sources/Synfus/StreamDeck/Combat/) : aucune API ne dit l'état du
combat, et une signature figée du jeu casserait à chaque mise à jour. La
détection se **calibre** : deux captures de la bande basse de la fenêtre
(`CombatDetector.region`, 22 % du bas, réduite à 64 × 14), l'une en combat,
l'autre hors combat, faites par l'utilisateur dans l'onglet Sorts et gardées
dans `Application Support/Synfus/Combat/`. `CombatDetector` est pur (comme
`BounceDetector`) : chaque relevé est corrélé aux deux références, le verdict
ne bascule qu'après deux relevés concordants et une marge minimale ; testé
dans `CombatDetectorTests`. `CombatWatcher` relève à 1 Hz, seulement liaison
active + Dofus devant + autorisation d'écran + références présentes, par
`WindowPreviewService.capture(_:region:)` — quelques milliers de pixels, coût
affiché dans l'onglet. Tant qu'il n'y a pas de verdict, `enCombat` est `nil`
et le plugin garde sa page.

## Publication

Un tag `v*` poussé déclenche
[release.yml](.github/workflows/release.yml) : runner `macos-26`, compilation
arm64 + x86_64, DMG et release GitHub. Les builds de CI sont signés ad-hoc et non
notarisés, d'où le `xattr -dr com.apple.quarantine` documenté dans le README.
