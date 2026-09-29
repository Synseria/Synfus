---
name: attention-dock
description: Détection d'un perso qui réclame l'attention par le rebond de son icône dans le Dock — géométrie AX du Dock, BounceDetector, cache de structure, appariement icône ↔ processus ↔ perso. Charger avant de toucher Attention/ (AttentionWatcher, BounceDetector, DockInspector, DockGeometryReader, DockPairing, AttentionProbe), le passage automatique ou le Diagnostic d'attention.
user-invocable: false
---

# Détection d'attention

Aucune API publique ne dit qu'une *autre* app réclame l'attention : `AttentionWatcher`
observe la géométrie AX des icônes du Dock (`DockInspector`), dix fois par seconde.

## Décision — `Sources/Synfus/Attention/BounceDetector.swift`

- Struct pure, nourrie d'un relevé par tour : les deux règles (aller-retour sauf au-delà de
  `certaintyRatio` ; mesure de l'**écart icône ↔ bandeau**, pas de la position à l'écran)
  sont expliquées en tête du fichier. `BounceDetectorTests` rejoue des relevés réels —
  toute retouche d'un seuil passe par eux.
- En masquage automatique, les icônes reposent **sous** le bord de l'écran : une position de
  repos n'a pas à tenir dans l'écran.
- Le survol est écarté par `mouseInDock`, sur le **bandeau entier** : un Dock masqué se
  dévoile dès que le curseur touche le bord, n'importe où. La taille écarte la
  magnification ; un cooldown évite les rafales.

## Coût — rien ne se relit s'il ne change pas

- `DockGeometryReader` garde la structure (`DockInspector.Structure`) et, en régime
  permanent, ne lit que position et taille en **un** IPC par icône. Le tour complet revient
  au premier tour, quand le nombre de pids Dofus diffère du cache, quand une lecture échoue,
  et en filet périodique : `DockRefreshPolicy` (pur, testé).
- `AttentionDiagnostics` (appariement, relevé) est un objet séparé observé par les seuls
  réglages : sur `AttentionWatcher`, il réévaluerait la barre, qui n'a besoin que
  d'`alerting`, à chaque mouvement du Dock. Chaînes recomposées seulement si le relevé change.
- Le tour sort avant d'interroger le Dock quand aucun perso n'est connecté.

## Appariement — une hypothèse, exposée au Diagnostic

- Rang de l'icône (triée par abscisse) ↔ rang du **pid croissant**
  (`WindowManager.liveDofusPIDs`), puis pid → perso : les icônes appartiennent à des
  **processus**, `clients` porte un perso par **fenêtre** — un client au login décalerait
  tout. `DockPairing` (pur, testé) ; `fiable` dit si le compte d'icônes égale celui des
  processus, sinon le Diagnostic prévient.
- Seules les icônes de sous-rôle `AXApplicationDockItem` d'une app lancée comptent (une
  fenêtre réduite ou une entrée « récents » « Dofus » décalerait les rangs).
- L'identité d'une icône est son **rang**, jamais son abscisse (la magnification la déplace).

## Outils

`AttentionProbe` journalise tout changement d'attribut dans
`~/Library/Logs/Synfus/attention.log` ; `--dump-dock` (voir `CLAUDE.md`).
