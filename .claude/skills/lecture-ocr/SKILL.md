---
name: lecture-ocr
description: Lecture de l'écran par OCR Vision — position sur la carte et état de combat (bouton « Fin de tour »), zones calibrées, coût maîtrisé, lecture au survol. Charger avant de toucher Lecture/ (LecteurEcran, ZoneEcran, PositionCarte, LectureCombat, LumaBitmap, MoteurOCR), CalibrationZonesView, CombatBadge ou RealCaptureTests.
user-invocable: false
---

# Lecture de l'écran

`Sources/Synfus/Lecture/LecteurEcran.swift` lit une fois par seconde, dans la fenêtre du perso
au premier plan, la **position** (haut gauche) et le **combat** (bas droite par défaut).
Réglages `lirePosition` / `lireCombat` éteints par défaut : l'enregistrement de l'écran n'est
demandé que par leur bascule, dans le Diagnostic.

## Coût

- Zones en **fractions du contenu** (`ZoneEcran`, pur) : l'interface du jeu suit la taille de
  la fenêtre. Contenu et non fenêtre : en fenêtré, la barre de titre (hauteur AppKit,
  `NSWindow.frameRect(…, .titled)`) décale tout ; le plein écran se sait par
  `DofusClient.pleinEcran`.
- Échelle fixe : contenu ramené à `ZoneEcran.hauteurReference` (plafonné au natif).
- Vision `.accurate` seulement (`.fast` ne lit pas la police du jeu), image posée sur une
  **marge noire** (`encadree`) : un glyphe collé au bord se lit mal.
- L'OCR ne repasse que si la zone a changé (`SignatureZone`, `EmpreinteTexte`). Le décompte,
  vert, ne relance pas l'OCR : il est lu au changement d'état et l'échéance est tenue
  localement (`EtatCombat.monTour(fin:)`).
- Inventaire ScreenCaptureKit gardé (`captureData(…, inventaireGarde:)`).
- Le premier OCR `.accurate` charge le modèle, long à froid : `MoteurOCR.prechauffer()` le
  paie à l'activation.

## Chasse — lecture à la demande

`GenreLecture.chasse` (suivi de chasse, `ZoneEcran.chasseParDefaut`, à gauche sous la position)
n'est jamais lu au tour : `LecteurEcran.lireUneFois` (bouton « Lire » et ouverture du panneau),
même capture (`capturer`) et même `MoteurOCR`, sans signature. Lignes → `EtapeChasse.ciblesLues`.

## Combat — `LectureCombat.swift` (pur)

- « Fin de tour » (fr, en, es, tolérant à l'OCR) sur bouton **en couleur** = son tour ; bouton
  **gris** = tour d'un autre ; « Prêt » = placement ; rien = hors combat.
- Aucune teinte supposée : la couleur change avec les thèmes du jeu, le gris jamais — c'est
  lui qui fait foi. `ratioColore` se mesure sur le seul corps du bouton (`corpsDuBouton`), la
  zone entière contenant aussi le décompte vert. Seuils : `seuilBouton`, `seuilSignature`.
- En plein écran seul le perso devant est lisible : l'état des autres date de leur dernier
  passage. Affichage : `CombatBadge`.

## Zones et autres persos

- Calibrées d'un tracé (`CalibrationZonesView`, depuis le Diagnostic). `nil` en préférences =
  défaut, qui suit ainsi ses corrections futures.
- Les autres persos sont lus au **survol** de leur pastille (relevé de plus de 10 s) et par
  « Tout lire ». La position s'affiche dans l'aperçu, sinon dans une étiquette
  (`PreviewPanelController`, mode `.etiquette`) : `.help` n'est pas fiable pour une app inactive.
- `DiagnosticLecture` (compteurs, zones lues) n'est observé que par les réglages.

## Banc de calibrage

`RealCaptureTests` rejoue la chaîne sur une capture : `SYNFUS_CAPTURE` (obligatoire, sinon
ignoré), `SYNFUS_PLEIN_ECRAN=1`, `SYNFUS_COMBAT_ATTENDU=monTour`, `SYNFUS_ZONE_ENTIERE=1`
(capture déjà recadrée sur le bouton).
