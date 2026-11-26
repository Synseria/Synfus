---
name: interface-barre
description: Interface de Synfus — barre flottante (NSPanel non activable), visibilité, glisser-déposer des pastilles, pilule et cibles d'équipe, fenêtre de réglages, menu de la barre de menus, aperçus ScreenCaptureKit, rangement des fenêtres. Charger avant de toucher Interface/ (Barre/, Reglages/, MenuBarController), Apercus/, Rangement/, ou d'ajouter un réglage à l'écran.
user-invocable: false
---

# Interface

| Sujet | Lire |
| --- | --- |
| Aperçus des fenêtres (ScreenCaptureKit, appariement, préchauffe) | `reference/apercus.md` |
| Rangement des fenêtres, plein écran, « Lancer la session » | `reference/rangement.md` |
| Revoir ou refaire un écran (avec le skill global `grille-ui`) | `reference/grille-ui.md` |

**Un réglage n'apparaît que s'il sert** : les options d'une fonction coupée sont masquées, pas
grisées (options de la barre sous « Afficher la barre », touche de l'enchaînement au clic sous
sa bascule). Toute nouvelle option suit la règle.

## Barre flottante — `Interface/Barre/`

- `NSPanel` non activable (`canBecomeKey = false`, `FloatingBarController`) : un overlay de jeu
  ne capte jamais le clavier. Seules exceptions, la palette (`Palette/PalettePanel`) et le
  panneau de chasse (`Chasse/ChassePanel`) : `.nonactivatingPanel` qui **peuvent** devenir key,
  pour taper sans activer Synfus.
- Boutons après les persos : `BoutonBarre` (pur) est le seul endroit qui les liste, dans
  l'ordre de la barre ; masqués par `Preferences.boutonsMasques` (Réglages → Barre, ou clic droit
  « Masquer ce bouton »). L'engrenage n'est jamais masquable.
- Panneaux du jeu (quêtes, chasse, boss, recette épinglée) : leur visibilité passe par `PanneauxJeu.revoir`, le
  seul endroit qui les énumère. Panneau d'aide aux boss (`Boss/BossPanel`) : jamais clé, taille
  de son contenu (skill `aide-boss`).
- Panneau des quêtes (`Quetes/QuetePanel`) : sans bordure, jamais clé, jamais zoomé. Pas de
  barre de titre, même transparente : elle mange les clics du haut et zoome au double-clic.
  Pas `.resizable` : les bords du système, invisibles et sans curseur pour une app inactive,
  chevauchaient nos poignées et le haut de l'en-tête. Bords et coins par `PoigneeRedimension`
  seule ; cadre relu par `setFrameUsingName(_:force: true)`. En-tête des panneaux de jeu :
  `EnTetePanneau` (quêtes, chasse) — `WindowDragArea` **par-dessus** l'icône, le titre et l'espace
  libre (une image ou un texte au-dessus d'une `NSView` lui prend le clic), jamais sur un bouton.
  Avec `menu` (titre des quêtes) : un clic ouvre un `NSMenu` en `popUp`, un glisser de plus de
  3 pt (`estUnGlisser`) remet l'appui d'origine à `performDrag`.
  Tailles de la fiche : `MetriquesQuete` (confort ou compact), aucune taille en dur dans `QueteVue`.
- Calque de visée du Comte (`Boss/ViseePanel`) : **pas** un `PanneauDeJeu` — `NSPanel` nu, sans
  place gardée, au cadre du contenu de Dofus, `ignoresMouseEvents`, caché dès que le pointeur est
  sur une fenêtre de Synfus. Revu par `PanneauxJeu.revoir`. Sa grille se calibre à deux clics dans
  Réglages ▸ Aides (`CalibrationGrilleView`, ses lignes seulement visée allumée).
- Niveau `.statusBar`, pas `.floating` (qui disparaît sous un espace plein écran) ;
  `.stationary` volontairement absent du `collectionBehavior`.
- Déplacement par `performDrag(with:)` (`WindowDragArea`), pas par `DragGesture` (en retard sur
  la souris). La position va dans `pendingOrigin`, écrite dans `barOrigin` après un temps mort
  (`flushPendingOrigin`, aussi appelé à la fermeture) : chaque écriture de préférence est un
  JSON et un redessin.
- Curseur de la poignée : `CurseurArrierePlan` (propriété privée `SetsCursorInBackground` par
  `dlsym`, repli sur la flèche) — macOS ignore `NSCursor.set()` d'une app inactive.
- **Visibilité** : décidée sur `WindowManager.frontmostPID` / `frontmostIsDofus`, jamais sur
  `NSWorkspace.frontmostApplication` (encore l'ancienne app au moment de la notification) ;
  décidée **avant** l'inventaire. Règle pure `computeVisibility` (`BarVisibilityTests`).
  `WindowManager` la déclenche par le rappel `visibiliteARevoir`, posé par `AppDelegate` — le
  modèle ne connaît pas la barre : notifications en `force: true` (remonte la barre sur un
  espace fraîchement activé), timer de 2 s du `WindowManager` en `force: false` (ne corrige
  qu'un état faux).
- Réordonner les pastilles : `DragGesture` en espace de coordonnées nommé ; le drag & drop
  système ne démarre pas de façon fiable depuis un panneau non activable.
- Badges en overlay (`CopiedBadge`, `CombatBadge`) : la barre ne change pas de taille.
- Une pastille dit le nom et la classe (`showClasses` ne règle que l'emblème) ; son numéro est une
  `ToucheDeClavier` portant le raccourci réel du rang (`BarView.toucheDuPerso`), le numéro à défaut.
- **Clavier des groupes** : tout groupe à choix unique (segments, barre latérale, pastilles de couleur, icônes
  de l'app) passe par `groupeSelection` — Tab entre et sort, les flèches déplacent la sélection, aucun anneau —
  et ses boutons par `elementDeGroupe()`. Les filtres de la palette suivent Tab/⇧Tab (le panneau garde le
  clavier du champ, ←/→ y restent au texte). Un choix multiple garde l'anneau système et Espace.
- Palette : la portée de la recherche se dit dans le filtre choisi, jamais par un mot de genre sur la rangée
  (pas de « Monstre », « Objet », « Quête » en sous-titre) ; l'icône de la rangée est dans un carré
  `primaireFond`, celle d'une commande ou d'une variable est la sienne (`symbole`).

## Équipes dans la barre — pilule et `TeamRow.swift` (modèle : skill `inventaire-clients`)

- Une seule rangée. La **pilule d'équipe** (`BarView.piluleEquipe`, devant les pastilles) dit
  l'effectif et ouvre un `Menu` (jamais un popover : il activerait Synfus) — Tous, les équipes
  cochées, « Créer une équipe… » (Réglages ▸ Personnages). Elle se montre dès qu'une équipe existe : avec
  une seule, passer de « Tous » à elle reste un choix que seule la barre offre sans raccourci.
- Les secteurs de `TeamRow` (Tous, chaque équipe, « + ») ne sont que des **cibles de dépôt** : ils
  n'apparaissent que pendant le glisser d'une pastille. Une équipe disparaît quand elle se vide.
- Le **même** `DragGesture` que le réordonnancement : au-dessus d'un secteur on surligne
  (`dropTarget`) sans permuter ; l'affectation se fait au relâchement, jamais en cours de geste.
  Les secteurs s'agrandissent pendant le glisser (`agrandi`).
- Le glisser ferme l'aperçu et `hover` l'ignore tant que `dragging` est posé.
  `coordinateSpace` sur le `VStack` : pastilles et secteurs dans un seul repère.
- La rangée change la hauteur du panneau : `FloatingBarController.topEdge` tient le **bord
  haut** (AppKit garde l'origine en bas à gauche).
- L'onglet Personnages offre la même affectation par un `Picker` par ligne.

## Vues des cartes — `Interface/ImagesCarte.swift`

- Toute vue de carte passe par `VueCarte` (deux pixels par point de son plus grand côté, jamais
  l'image entière) : `MiniatureCarte` (lignes de la palette, listes des lieux et des PNJ, lignes de zaaps,
  panneau des quêtes), `FondCarte` (fond des cartes de la palette, sous un voile continu ; en grand au
  survol de sa loupe `LoupeCarte`, jamais de la carte), `ApercuCarte`. `ImagesDofusDB` décode hors main (ImageIO) et
  range les copies réduites dans un `NSCache` borné à 64 Mo décodés ; seules les images sans
  `cote` — emblèmes, pictogrammes, petits et en nombre fini — restent à vie. Masquée par
  `vuesCartes` (clé de sauvegarde `zaapsVueCarte`, qui masque aussi le fond des zaaps), agrandie
  au survol par `ApercuCarte` — panneau sans bordure, jamais clé, `ignoresMouseEvents`, posé à
  côté de la fenêtre sous la souris. Un survol sans vignette (ligne d'objectif des quêtes) passe
  par le même `apercuCarteAuSurvol`. Une fenêtre qui se cache sans détruire ses vues (palette,
  réglages, quêtes) appelle `ApercuCarte.shared.cacher()`, sans compter sur `onDisappear`.
- Pictogramme d'un lieu : `PictogrammeLieu` (`Lieu.gfx`), le symbole en repli.
- Palette : un trajet affiche `itineraire` (`ItineraireZaap.trajet`, « via X · N cartes »), le tri
  garde la distance à pied ; `EtiquetteInterieur` (cartes `CarteStore.interieurs`).
- Palette, une seule rangée (`FiltrePalette.allCases`), la même avec ou sans texte tapé (une
  rangée qui bouge à la frappe déroute) : Accueil · Zaaps · Lieux · Donjons · PNJ · Quêtes ·
  Créatures · Objets · Almanax, chacune vue au repos et portée de la recherche (Créatures = monstres,
  sans PNJ ni boss) ; taper ne change jamais la capsule choisie, Tab parcourt la rangée, la palette s'ouvre toujours sur l'Accueil (`ouvrir(requete:vue:)`). L'almanax
  (`AlmanaxSemaineVue`, sept jours) n'est que sa vue, par Tab ou par l'outil « Almanax » de la barre
  (`PalettePanel.basculerAlmanax`) ; le tri ne se montre que là où il range (`triAgit`).

## Réglages et menu

- `Reglages/SettingsView.swift` : la fenêtre de toutes les apps Synseria — `BarreDesOnglets` en haut (dix
  onglets `SettingsSection`, sans titre : ils disent où l'on est), fenêtre sans titre affiché, sous tout le
  contenu le matériau du système voilé de la page (`FondDeFenetre`, pas le verre nu), une seule taille
  (`SettingsView.taille`, barre de titre comprise, que la vue remplit) ; la page sur
  une plaque pleine. Une page fusionnée est une suite de `Bloc`, jamais des onglets dans l'onglet. Chaque page est une
  `PageReglages` (`FormulaireCompact` de la trousse, colonne de `largeur-colonne`) de `Bloc` — le dessin de
  `SectionCompacte`, plus `paresseux` et `entete` qu'elle n'a pas : une carte, un filet entre les lignes ;
  une ligne est `Ligne` (libellé à gauche, état en méta puis contrôle à droite), `LigneInterrupteur`,
  `RaccourciReglable` (`EnregistreurDeRaccourci`), ou toute vue passée par `.rangee()` — jamais un
  `HStack` maison, jamais une carte dans une carte. Un choix dans une liste fermée : `MenuEnChamp` ;
  deux à quatre options : `SegmenteTexte`. Une longue liste (zaaps, lieux, quêtes, PNJ) est un
  `Bloc(paresseux: true)` ; tri et textes cherchés gardés par `ListeCherchable`. Un état vide, en attente
  ou en erreur est un `EtatDeBloc` qui prend le bloc entier (« Nom indisponible » + « Réessayer », sans
  la cause). Aucune phrase à l'écran, aucun ⓘ : l'explication est l'infobulle (`aide:`). Libellés sans
  deux-points ni « / », jamais abrégés (« Personnage », pas « Perso »). Couleurs : `Color.jeton(\.chemin)` (nuancier du design system ; l'onglet Thème règle la nuance et le thème, Système et Lagon par défaut ; les icônes de l'app et de la barre de menus sont dans Général) ; composants communs : la trousse `Interface/Trousse` ; dessin propre (états, surface flottante) : `Interface/Composants.swift`, détail dans `reference/grille-ui.md`. `SettingsWindowController` doit appeler
  `NSApp.activate(ignoringOtherApps:)` (app accessory) ; la fenêtre s'ouvre sous la barre
  (`visibleBarFrame`), au centre sinon.
- Un message qui dit « Réglages › … » s'accompagne d'un bouton qui y mène :
  `SettingsWindowController.show(section:)` (`OngletReglages`, l'onglet montré).
- Le menu applicatif a un menu Édition : sans lui, aucun champ (palette, chasse, réglages) ne
  reçoit ⌘C, ⌘V, ⌘A, ⌘Z. « Fermer tous » : Entrée annule.
- `MenuBarController` reconstruit le menu à chaque ouverture (`menuNeedsUpdate`), sur
  `effectif` (les numéros de la barre). Les raccourcis y sont du texte attribué : ce sont des raccourcis Carbon
  globaux, pas des key equivalents.
