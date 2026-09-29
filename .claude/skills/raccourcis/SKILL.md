---
name: raccourcis
description: Raccourcis globaux Carbon, keycodes et libellés selon le clavier, jeu par défaut, enregistreur, conflits, enchaînement au fn-clic, signal de bascule et rotation entre persos. Charger avant de toucher Raccourcis/ (HotKeyManager, HotKey, ShortcutRecorder, HotKeyConflicts, ClickAdvanceWatcher, ClickModifier), Clients/Rotation.swift, un défaut de raccourci ou `focus`/`cycle`.
user-invocable: false
---

# Raccourcis et bascule

## Raccourcis globaux — `Sources/Synfus/Raccourcis/`

- `HotKeyManager` utilise Carbon `RegisterEventHotKey`, **jamais** un `CGEventTap` : il réserve
  une combinaison au lieu d'observer la frappe — aucune permission de saisie, rien de ce qui
  est tapé ailleurs n'est vu. Le callback C ne capture rien : il repasse par le singleton via
  `DispatchQueue.main.async`.
- Appui **et** relâchement sont écoutés (raccourcis « à maintenir » : aperçu d'ensemble).
  Carbon ne répète pas. Un modificateur seul est hors de portée, et le restera (il faudrait
  un moniteur de clavier).
- `rebind()` réenregistre tout après chaque modification de préférence.
- `HotKey` stocke des **keycodes de position**, pas des caractères.
- Deux territoires, règle du jeu par défaut : la rangée de chiffres (`digitRow`) est à
  l'accès direct (⌘1…⌘0) ; toute la navigation est sur la touche sous Échap
  (`escapeRowKey`), différenciée par les modificateurs. Aucun nouveau défaut dans `digitRow`.
- La touche sous Échap dépend du **type physique** du clavier (ANSI 50, ISO 10 — tous les
  claviers Apple européens), lu par `KBGetLayoutType`. Ne jamais la supposer à 50.
- Libellés : `keyName` demande le caractère à la **disposition active** (`UCKeyTranslate`),
  sauf rangée de chiffres (nommée par position) et touches qui ne tapent rien. Aucune table
  figée. Table résolue une fois dans un `static let` : `TISCopyCurrentKeyboardLayoutInputSource`
  abandonne s'il est appelé de plusieurs fils.
- Changer un défaut exige une nouvelle génération : voir skill `preferences`
  (`defaultsVersion`, `adoptDefaults`). « Rétablir les raccourcis par défaut » :
  `Preferences.resetShortcuts`.
- `ShortcutRecording` (dans `ShortcutRecorder.swift`) tient l'**unique** moniteur local et le
  champ qui a la parole : un seul champ enregistre à la fois.
- `HotKeyConflicts` (pur, testé) rend les combinaisons en double ; la ligne concernée porte un
  avertissement (`@Published`, il suit les modifications).

## Enchaîner au clic — `ClickAdvanceWatcher.swift`

- Clic avec la touche tenue (`advanceModifier`, `fn` par défaut) → perso suivant **après** le
  clic. Seul le changement de fenêtre est automatisé (règle transverse : aucun évènement émis).
- Moniteur global **passif**, sur `.leftMouseUp` : prendre le focus entre appui et relâchement
  laisserait au client un bouton jamais relâché. Souris seule ; la touche se lit sur les
  drapeaux du clic.
- `fn` parce que le jeu reçoit le clic **avec** le drapeau et traite autrement un clic à ⌘ ;
  Synfus ne peut pas retirer le modificateur sans `CGEventTap`. `ClickModifier.isHeldAlone`
  (pur, `ClickModifierTests`) : la touche choisie et elle seule, verrouillage majuscules
  ignoré. Les autres touches restent proposées avec avertissement.
- `settleDelay` est fixe, jamais randomisé.
- Diagnostic : `lastModifiers` (ce clavier fait-il voir `fn` ?) et `seenClicks` (à zéro après
  un clic, macOS ne livre rien — la permission requise n'est pas documentée par Apple).
- La clé `advanceArmHotKey` d'une ancienne sauvegarde est ignorée à la lecture (testé).

## Signal de bascule et rotation

- Chaque bascule par `focus()` fait clignoter la pastille atteinte dans la barre
  (`WindowManager.basculeSignalee`, `SwitchBlink`) ; rien ne se pose sur le jeu. Le clic sur
  une pastille passe `signaler: false`. Réglage `signalerBascule`.
- `cycle` passe par `Clients/Rotation.swift` (pur, testé), qui **saute les injoignables**
  (`unreachablePIDs` : fermeture en cours, suspects de gel). L'accès direct n'y passe pas.
