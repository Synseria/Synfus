---
name: interface-barre
description: Interface de Synfus — barre flottante (NSPanel non activable), visibilité, glisser-déposer des pastilles et rangée d'équipes, fenêtre de réglages, menu de la barre de menus, aperçus ScreenCaptureKit, rangement des fenêtres. Charger avant de toucher Interface/ (Barre/, Reglages/, MenuBarController), Apercus/, Rangement/, ou d'ajouter un réglage à l'écran.
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
- Panneaux du jeu (quêtes, chasse, boss) : leur visibilité passe par `PanneauxJeu.revoir`, le
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

## Rangée d'équipes — `TeamRow.swift` (modèle : skill `inventaire-clients`)

- N'apparaît que s'il y a une équipe, ou pendant un glisser (pour en créer une sur « + »).
  Une équipe disparaît quand elle se vide.
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
  l'image entière) : `MiniatureCarte` (palette, listes des lieux et des PNJ, lignes de zaaps, panneau des quêtes),
  `FondCarte` (cases de zaaps), `ApercuCarte`. `ImagesDofusDB` décode hors main (ImageIO) et
  range les copies réduites dans un `NSCache` borné à 64 Mo décodés ; seules les images sans
  `cote` — emblèmes, pictogrammes, petits et en nombre fini — restent à vie. Masquée par
  `vuesCartes` (clé de sauvegarde `zaapsVueCarte`, qui masque aussi le fond des zaaps), agrandie
  au survol par `ApercuCarte` — panneau sans bordure, jamais clé, `ignoresMouseEvents`, posé à
  côté de la fenêtre sous la souris. Un survol sans vignette (ligne d'objectif des quêtes) passe
  par le même `apercuCarteAuSurvol`. Une fenêtre qui se cache sans détruire ses vues (palette,
  réglages, quêtes) appelle `ApercuCarte.shared.cacher()`, sans compter sur `onDisappear`.
- Pictogramme d'un lieu : `PictogrammeLieu` (`Lieu.gfx`), le symbole en repli.
- Palette : un trajet affiche `itineraire` (`ItineraireZaap.trajet`, « via X · N cartes »), le tri
  garde la distance à pied ; `EtiquetteInterieur` (cartes `CarteStore.interieurs`) ; almanax en
  tête de la grille sans saisie (`AlmanaxVue`).

## Réglages et menu

- `Reglages/SettingsView.swift` : barre latérale de dix entrées (`SettingsSection`) sous quatre petits
  titres non repliables (`GroupeReglages`) : Synfus (Général + Statistiques, Thème), Personnages
  (Personnages + Classes, Barre, Raccourcis + Enchaîner + Attention), En jeu (Palette + Invitations,
  Carte = Trajets + Zaaps + Lieux, Quêtes + PNJ, Aides = Chasse + Boss), Avancé (Lecture de l'écran +
  Diagnostic). Une page fusionnée est une suite de `Bloc`, jamais des onglets dans l'onglet. Chaque page est
  une `PageReglages` (titre, défilement) de `Bloc` : une carte (`carte()`), un filet entre les lignes ; une
  ligne est `Ligne` (libellé à gauche, contrôle à droite, valeur ou état en gris par `etat:`, explication en
  `aide:`), `Interrupteur`, `RaccourciReglable`, ou toute vue passée par `.rangee()` — jamais un `HStack`
  maison, jamais une carte dans une carte. Une longue liste (zaaps, lieux, quêtes, PNJ) est un
  `Bloc(paresseux: true)` : ses lignes ne se construisent qu'à l'écran ; tri et textes cherchés gardés par
  `ListeCherchable`. Un état vide, en attente ou en erreur est un `EtatDeBloc` qui prend le bloc entier
  (« Nom indisponible » + « Réessayer », sans la cause). Aucune phrase à l'écran ; ⓘ au dernier recours
  (`aide:` du bloc), sinon `infobulle:`. Libellés sans deux-points ni « / », jamais abrégés (« Personnage »,
  pas « Perso »). Couleurs : `Color.jeton(\.chemin)` (jetons du design system ; l'onglet Thème règle la couleur de l'app et la teinte des fonds, Auto par défaut ; les icônes de l'app et de la barre de menus sont dans Général) ; dessin commun (états, boutons, touche, cartes, surface flottante) : `Interface/Composants.swift`, détail dans `reference/grille-ui.md`. `SettingsWindowController` doit appeler
  `NSApp.activate(ignoringOtherApps:)` (app accessory) ; la fenêtre s'ouvre sous la barre
  (`visibleBarFrame`), au centre sinon.
- Un message qui dit « Réglages › … » s'accompagne d'un bouton qui y mène :
  `SettingsWindowController.show(section:)` (`OngletReglages`, l'onglet montré).
- Le menu applicatif a un menu Édition : sans lui, aucun champ (palette, chasse, réglages) ne
  reçoit ⌘C, ⌘V, ⌘A, ⌘Z. « Fermer tous » : Entrée annule.
- `MenuBarController` reconstruit le menu à chaque ouverture (`menuNeedsUpdate`), sur
  `effectif` (les numéros de la barre). Les raccourcis y sont du texte attribué : ce sont des raccourcis Carbon
  globaux, pas des key equivalents.
