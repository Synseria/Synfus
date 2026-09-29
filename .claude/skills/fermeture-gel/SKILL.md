---
name: fermeture-gel
description: Fermeture des clients Dofus (escalade Quit puis kill) et abattage des clients gelés après une fermeture externe — FreezeWatcher, sonde de mutisme portée par l'inventaire, VeilleFermeture. Charger avant de toucher Clients/WindowManager+Fermeture.swift, ClientTerminator, FreezeWatcher, FreezeStrikes, CrossSpaceTitles.affiches, closingPIDs ou Interface/ConfirmationFermeture.swift.
user-invocable: false
---

# Fermeture et gel

Certains clients gèlent systématiquement à la fermeture. Fermer est une opération de
**processus**, pas une saisie : la règle « aucun évènement émis » reste entière.

## Fermer — `WindowManager+Fermeture.swift`

- Escalade unique dans `ClientTerminator` : `terminate()` (Quit Apple Event), puis
  `forceTerminate()` si le processus vit encore après le délai de grâce. `FreezeWatcher`
  passe par le même foyer.
- Le Quit Apple Event peut bloquer plusieurs secondes sur un client gelé : `terminate()` part
  d'une `Task.detached` ; `forceTerminate()` (un signal) reste sur main.
- Pendant la fermeture, le pid est dans `closingPIDs` : l'inventaire ne l'interroge plus,
  `FreezeWatcher` ne le sonde pas, sa pastille (tenue par la mémoire) montre une attente.
- `closeAll` ferme **un processus à la fois** (`processusAFermer`) : deux persos d'un même
  client ne donnent pas deux escalades.
- « Fermer tous » est le seul geste qui demande confirmation ; l'alerte vit dans l'interface
  (`Interface/ConfirmationFermeture.swift`, commune aux deux menus). Le modèle n'expose que
  `close`, `closeAll`, `processusAFermer`, sans UI.

## Abattre un gelé — `FreezeWatcher.swift`

- Gelé et dormant sain sont tous deux « vivant sans fenêtre ». Ce qui les distingue est la
  **réponse** : un dormant répond à l'Accessibilité (une liste vide est une réponse), un gelé
  laisse expirer la borne.
- Règle stricte, pour ne jamais viser un vivant : sans fenêtre **et** muet à trois sondes
  consécutives espacées de 5 s. Chaque abattage est consigné au Diagnostic ; bascule
  `killFrozenClients` (active par défaut).
- Voie rapide : deux fois par seconde, `CrossSpaceTitles.affiches` (CGWindowList, sans
  permission, non bloquable par un gelé) liste les fenêtres de jeu à l'écran. Une fenêtre qui
  disparaît sans changement d'espace (`VeilleFermeture`, pur, garde après
  `activeSpaceDidChange`) signale une fermeture probable : inventaire immédiat, et **une**
  sonde muette suffit (`requisFermeture`). Le soupçon s'éteint après 5 s ; une fenêtre réduite
  ou changée d'espace répond et est blanchie.
- **La sonde, c'est l'inventaire** : il constate le mutisme (`.cannotComplete` sur
  `kAXWindows`) et le rapporte en `mutePIDs`. Pas de sonde séparée (elle doublerait la borne).
- Un suspect n'est réinterrogé qu'à l'échéance (`shouldProbe`), avec la **même** borne d'1 s :
  plus courte, un client vivant mais lent (chargement, combat chargé) serait abattu. Entre
  deux échéances, l'inventaire le saute et la mémoire l'affiche atténué.
- Une sonde est un **fait rapporté** (`probedPIDs`), jamais déduit de l'échéance : un suspect
  sauté au départ d'un inventaire ne se blanchit pas sur une réponse jamais demandée.
- Comptabilité pure : `FreezeStrikes` (`FreezeStrikesTests`). Les strikes comptent même
  bascule coupée ; seul le coup de grâce en dépend, et un condamné épargné n'est resondé
  qu'à `condemnedInterval`.
