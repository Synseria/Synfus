# Stream Deck

Guide de la fonction Stream Deck, **en pause depuis le 15/09/2026** : aucun
développement, le code doit seulement continuer de compiler. Détaché du
`CLAUDE.md` racine, qui ne garde que ce renvoi — Claude Code charge ce fichier
dès qu'il lit un fichier de ce dossier.

## Stream Deck — reconnaissance des sorts

Le Stream Deck doit afficher les sorts du perso actif ; encore faut-il savoir
lesquels. Plutôt qu'une configuration à la main, [StreamDeck/Sorts/](../../../Sources/Synfus/StreamDeck/Sorts/)
lit la barre de sorts sur une capture de la fenêtre — **à la demande**, comme
opération de configuration, jamais en continu.

- [LumaBitmap.swift](../../../Sources/Synfus/StreamDeck/Sorts/LumaBitmap.swift) : une
  image en gris 8 bits, valeur `Sendable`, fabricable en test sans CoreGraphics.
- [SpellBarLocator.swift](../../../Sources/Synfus/StreamDeck/Sorts/SpellBarLocator.swift)
  : pur. Cherche dans le tiers bas la grille des cases par un **réseau de
  pics** : sur chaque bande horizontale, les bords verticaux font des pics, et
  une rangée est une suite « gauche, droite, gauche, droite… » au même pas —
  le pas est estimé en **fraction** (83,4 px sur la capture de calibrage) et
  chaque case est cherchée à sa place à `tolerance` près, sans dérive. Un
  interstice minimal (`minGap`) écarte les lettres du tchat. Les rangées se
  trouvent de même à la verticale, ancrées sur la bande où les colonnes ont été
  vues, sur les seuls bords nets. Mesuré : 3 × 12 cases au pixel.
  `SpellBarLocatorTests` sur images fabriquées ; `RealCaptureTests`
  sur une capture locale via `SYNFUS_CAPTURE`.
- [SpellRecognizer.swift](../../../Sources/Synfus/StreamDeck/Sorts/SpellRecognizer.swift)
  : pur. Compare chaque case aux icônes **de la classe du perso et communes**
  (~57 candidats, index `sorts.json` d'`AnkamaAssets`) par corrélation
  normalisée sur le **picto seul** (`inset` 22 % — le cadre est commun à toute
  la classe, le garder c'était comparer des cadres), à 40 × 40, en tolérant un
  décalage de 2 px (`bestCorrelation`, sur les six meilleurs candidats du tri
  sans décalage). Une case sans contraste est **vide**, pas un sort. Mesuré
  sur la capture de calibrage : 30/36 sûres à 0,85-0,97, 2 vides, 4 objets.
  La **marge** entre le premier et le second candidat est la confiance
  (`isConfident`, seuils 0,7 / 0,12).
- [SpellRecognitionProbe.swift](../../../Sources/Synfus/StreamDeck/Sorts/SpellRecognitionProbe.swift)
  : le banc d'essai du Diagnostic — capture en résolution native (par
  `WindowPreviewService.capture(_:region:)`, le **même** moteur que les
  aperçus, étendu à une zone et à la résolution native), enregistrement dans
  `~/Library/Logs/Synfus/captures/` (jamais dans le dépôt), analyse avec les
  scores par case et les durées. C'est sur ce rapport que se prend la décision
  go/no-go de la reconnaissance automatique.

## Stream Deck — profils, liaison, plugin, combat

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
- **L'API locale n'est pas un port réseau.** [StreamDeckLink.swift](../../../Sources/Synfus/StreamDeck/Liaison/StreamDeckLink.swift)
  écoute sur un socket Unix `~/Library/Application Support/Synfus/streamdeck.sock`,
  `chmod 0600` dès qu'il existe, et seulement si `streamDeckEnabled` (faux par
  défaut). Le protocole, [DeckProtocol.swift](../../../Sources/Synfus/StreamDeck/Liaison/DeckProtocol.swift),
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
  [DeckComposer.swift](../../../Sources/Synfus/StreamDeck/Liaison/DeckComposer.swift)
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
- **Les dispositions** ([DeckLayout.swift](../../../Sources/Synfus/StreamDeck/Profils/DeckLayout.swift),
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
  `-port -pluginUUID -registerEvent -info` ; [Sources/SynfusDeck/](../../../Sources/SynfusDeck/)
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
  [Plugin/](../../../Plugin/). Le plugin journalise dans
  `~/Library/Logs/Synfus/synfusdeck.log`.

[Profils/](../../../Sources/Synfus/StreamDeck/Profils/) : `SpellProfile` (perso →
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

[Combat/](../../../Sources/Synfus/StreamDeck/Combat/) : aucune API ne dit l'état du
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
