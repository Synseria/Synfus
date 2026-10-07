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

**Un réglage n'apparaît que s'il sert** : les options d'une fonction coupée sont masquées, pas
grisées (options de la barre sous « Afficher la barre », touche de l'enchaînement au clic sous
sa bascule). Toute nouvelle option suit la règle.

## Barre flottante — `Interface/Barre/`

- `NSPanel` non activable (`canBecomeKey = false`, `FloatingBarController`) : un overlay de jeu
  ne capte jamais le clavier. Seule exception, le panneau de chasse (`Chasse/ChassePanel`) :
  `.nonactivatingPanel` qui **peut** devenir key, pour taper l'indice sans activer Synfus.
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
- L'onglet Persos offre la même affectation par un `Picker` par ligne.

## Réglages et menu

- `Reglages/SettingsView.swift` : barre latérale en groupes (`GroupeReglages`), un
  onglet par sujet et peu de réglages par onglet — mieux vaut un onglet de plus qu'un onglet
  chargé —, une vue par onglet, chacune une `PageReglages` (titre, une
  phrase, `Form` groupé). Toute ligne passe par `Ligne` (libellé à gauche, contrôle à droite,
  précision grise, ⓘ), `Interrupteur` ou `RaccourciReglable` (doublons et réenregistrement) : c'est ce qui tient l'alignement — jamais un `HStack`
  maison. Libellés sans deux-points ni « / ». Couleurs : `Couleurs` (accent vert d'eau, ambre). `SettingsWindowController` doit appeler
  `NSApp.activate(ignoringOtherApps:)` (app accessory) ; la fenêtre s'ouvre sous la barre
  (`visibleBarFrame`), au centre sinon.
- `MenuBarController` reconstruit le menu à chaque ouverture (`menuNeedsUpdate`), sur
  `clients` tel quel. Les raccourcis y sont du texte attribué : ce sont des raccourcis Carbon
  globaux, pas des key equivalents.
