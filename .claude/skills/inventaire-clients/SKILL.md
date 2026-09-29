---
name: inventaire-clients
description: Découverte des persos Dofus par l'Accessibilité — décodage du titre, inventaire hors main (ClientInventoryEngine), rafraîchissement, mémoire des dormants, titres à travers les espaces, ordre et slots, effectif d'équipe, invitations. Charger avant de toucher Clients/ (WindowManager*, ClientInventoryEngine, ClientMemory, WindowTitle, Equipes), Accessibilite/, Invitations/, ou du code qui lit `clients` / `effectif`.
user-invocable: false
---

# Inventaire des clients

Cœur : `Sources/Synfus/Clients/WindowManager.swift` (état, `start`, inventaire) et ses
extensions `+PremierPlan`, `+Effectif`, `+Focus`, `+Fermeture`.

| Sujet | Lire |
| --- | --- |
| Équipes (modèle) et invitations par presse-papiers | `reference/equipes-invitations.md` |
| Gel, fermeture, sonde de mutisme | skill `fermeture-gel` |

## Tout dérive du titre

- Titre « Nom - Classe - version - Release », décodé **uniquement** par `WindowTitle` (pur,
  `TitreDeFenetreTests`). Un client au login (titre « Dofus » seul) n'est pas un perso :
  l'inclure décalerait les slots, donc les raccourcis.
- L'icône du Dock ne distingue rien : tous les clients partagent `Dofus.app`. Un processus
  Dofus se reconnaît par `DofusProcesses` (`AccessibilityReader.swift`).
- Identité : `slotKey` = `"<pid>#<index de fenêtre>"`. Tri selon `Preferences.characterOrder`
  (des noms) ; un perso absent est sauté, les slots restent stables. `resort()` retrie sans
  inventaire, avec le même comparateur (`ClientOrderTests`).
- `isPersistableName` écarte de l'ordre « Dofus 3.3.4.9 » (client au login) et « Nom (2) »
  (suffixe d'homonyme posé par Synfus) : affichés et cliquables, relégués en fin, jamais
  enregistrés. `Preferences.purgeOrder` nettoie au démarrage.

## Rafraîchir sans geler

- Aucune notification de changement de titre : timer de 2 s dans `WindowManager.start`
  (qui réévalue aussi la visibilité de la barre) + notifications `NSWorkspace` via
  `refreshSoon()` — une activation en émet deux. Le timer saute son tour si un inventaire
  date de moins d'1 s.
- Bascule faite par Synfus : reconnue à `selfActivatedPID` ; l'inventaire attend 1 s
  (`refreshSoon(after:)` garde l'échéance la plus tardive), le temps de la transition d'espace.
- **Inventaire hors main, gestes sur main** — décision, pas oubli. `refresh()` ne lit rien :
  il compose une `InventoryRequest` pour `ClientInventoryEngine` (actor à exécuteur
  `DispatchSerialQueue`, aucun `await` dans `inventory(_:)` : un inventaire à la fois).
  `apply` tranche sur main avec l'état **courant** (`ClientMemory.consolidate`, pur).
  `InventoryScheduling` (pur) : au plus un en vol et un différé, résultat périmé jeté.
  `refreshed()` attend un inventaire lancé après l'appel. Focus, rangement et plein écran
  restent sur main ; `isReachable` leur épargne mourants et suspects.
- Un seul IPC par fenêtre (`AXUIElementCopyMultipleAttributeValues` : sous-rôle, taille,
  titre, `"AXFullScreen"` → `DofusClient.pleinEcran`). Rien n'est republié sans changement
  (`clients`, `frontmostPID`, `frontmostIsDofus`).
- **Borne AX de 1 s** (`AXUIElementSetMessagingTimeout` sur l'élément système, posée dans
  `start()`) : par processus, elle vaut pour l'acteur. Ne pas l'allonger (l'acteur est série,
  tous les persos attendraient) ; ne pas la raccourcir pour un suspect (`fermeture-gel`).
- `focus()` ne pose `kAXMain`/`kAXRaise` que s'il y a plusieurs fenêtres à départager.

## Dormants

- Un client dont l'espace plein écran est inactif rend `kAXWindows` **vide, sans erreur**.
  `rememberedClients` (par pid) le garde affiché, atténué, cliquable : `activate()` sur le
  processus suffit, son élément AX est périmé.
- `ClientMemory.withRemembered` (pur) ne ressuscite que les pids **silencieux** : un client
  revenu au login rend une fenêtre, le ressusciter montrerait un perso sorti du jeu.
- Client déjà sur un espace inactif au lancement : `CrossSpaceTitles` (CGWindowList, exige
  l'enregistrement de l'écran, **jamais demandé** par ce chemin) ; `discoveredAcrossSpaces`
  (pur) fabrique le dormant. Seulement pour les pids sans mémoire, au plus une fois par 10 s
  par pid (`crossSpaceChecked`).

## Deux listes

`clients` = tous les persos (inventaire, « Fermer tous », appariement Dock, réglages).
`effectif` = restreint à l'équipe active (barre, `focus(slot:)`, `cycle`, `lancerSession`,
rangement, aperçu d'ensemble, menu). Détail : `reference/equipes-invitations.md`.
