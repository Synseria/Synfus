---
name: lecture-ocr
description: Lecture de l'écran par OCR Vision — position, état de combat (bouton « Fin de tour »), suivis de chasse et de quêtes à la demande, calibrage par genre, coût maîtrisé, lecture au survol. Charger avant de toucher Lecture/ (LecteurEcran, ZoneEcran, PositionCarte, LectureCombat, LumaBitmap, MoteurOCR, Ressemblance, CapturesCalibrage), Quetes/SuiviQuetes, LectureSuivi, CalibrationZonesView, CombatBadge ou RealCaptureTests.
user-invocable: false
---

# Lecture de l'écran

`Sources/Synfus/Lecture/LecteurEcran.swift` lit une fois par seconde, dans la fenêtre du perso
au premier plan, la **position** (haut gauche) et le **combat** (bas droite par défaut) ; les
suivis de chasse et de quêtes à la demande.
Réglages `lirePosition` / `lireCombat` éteints par défaut : l'enregistrement de l'écran n'est
demandé que par leur bascule et par la capture du calibrage, jamais par un panneau.

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

## Genres — `GenreLecture`

Une seule table (`LecteurEcran.swift`) : par genre, `parDefaut` (`ZoneEcran.*ParDefaut`),
`reglage` (clé `zone…` des préférences, `nil` = défaut, qui suit ses corrections), `zone`.
Position et combat sont lus au tour ; **chasse** et **quêtes** seulement à la demande
(`LecteurEcran.lireUneFois`, sans signature, même `capturer` et même `MoteurOCR`).

- Chasse : lignes → `EtapeChasse.ciblesLues` (bouton « Lire » et ouverture du panneau).
- Quêtes : le suivi de quêtes du jeu (`quetesParDefaut`, à gauche, estimé). `LectureSuivi`
  (bouton « Lire le suivi » et ouverture du panneau des quêtes si l'écran est déjà autorisé) →
  `SuiviQuetes.reconnaitre` (pur, hors main) : une ligne de titre **est** un nom de quête
  (tolérance n/4, `surplusTitre` pour les icônes), pas seulement le contient ; ordre de
  l'écran, sans doublon, 10 au plus. L'étape : celle dont les noms cités (PNJ, objet,
  monstre) et objectifs se retrouvent sous le titre, seulement si une seule l'emporte — le
  texte du suivi n'est pas celui de DofusDB.
- Comparaison tolérante commune (chasse, quêtes) : `Ressemblance` (normalisation, distance de
  Sellers, `Forme` préparée et borne `tropLoin` — deux mille noms par ligne lue).

## Calibrage — `CalibrationZonesView(genre:)`

Onglet Lecture de l'écran, une ligne par genre (défaut / calibrée). Chaque genre a sa capture
(l'élément n'est visible qu'en combat, en chasse, suivi ouvert) : prise après 5 s de compte à
rebours sur le perso devant, contenu entier à l'échelle de la lecture, gardée dans
`~/Library/Caches/Synfus/Calibrage/<genre>.png` (`CapturesCalibrage`, jamais le dépôt). Un tracé
pose la zone ; l'essai (`LecteurEcran.lire(png:genre:)`) relit la zone découpée et l'interprète.

## Combat — `LectureCombat.swift` (pur)

- « Fin de tour » (fr, en, es, tolérant à l'OCR) sur bouton **en couleur** = son tour ; bouton
  **gris** = tour d'un autre ; « Prêt » = placement ; rien = hors combat.
- Aucune teinte supposée : la couleur change avec les thèmes du jeu, le gris jamais — c'est
  lui qui fait foi. `ratioColore` se mesure sur le seul corps du bouton (`corpsDuBouton`), la
  zone entière contenant aussi le décompte vert. Seuils : `seuilBouton`, `seuilSignature`.
- En plein écran seul le perso devant est lisible : l'état des autres date de leur dernier
  passage. Affichage : `CombatBadge`.

## Autres persos

- Les autres persos sont lus au **survol** de leur pastille (relevé de plus de 10 s) et par
  « Tout lire ». La position s'affiche dans l'aperçu, sinon dans une étiquette
  (`PreviewPanelController`, mode `.etiquette`) : `.help` n'est pas fiable pour une app inactive.
- `DiagnosticLecture` (compteurs, zones lues) n'est observé que par les réglages.

## Banc de calibrage

`RealCaptureTests` rejoue la chaîne sur une capture : `SYNFUS_CAPTURE` (obligatoire, sinon
ignoré), `SYNFUS_PLEIN_ECRAN=1` (aussi pour une capture du calibrage), `SYNFUS_ZONE=x,y,l,h`,
`SYNFUS_ZONE_ENTIERE=1` (capture déjà recadrée), `SYNFUS_COMBAT_ATTENDU=monTour`,
`SYNFUS_QUETES_ATTENDUES="Pense-bête|…"` (quêtes de `Quetes.json` de l'app).
