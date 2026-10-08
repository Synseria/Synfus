---
name: lecture-ocr
description: Lecture de l'écran par OCR Vision — position, état de combat (bouton « Fin de tour »), suivi de quêtes tant que son panneau est montré, chasse à la demande, calibrage par genre, coût maîtrisé, lecture au survol. Charger avant de toucher Lecture/ (LecteurEcran, ZoneEcran, PositionCarte, LectureCombat, LumaBitmap, MoteurOCR, Ressemblance, CapturesCalibrage), Quetes/SuiviQuetes, LectureSuivi, CalibrationZonesView, CombatBadge ou RealCaptureTests.
user-invocable: false
---

# Lecture de l'écran

`Sources/Synfus/Lecture/LecteurEcran.swift` lit, dans la fenêtre du perso au premier plan, la
**position** (haut gauche) et le **combat** (bas droite par défaut) une fois par seconde, le
**suivi de quêtes** toutes les trois secondes tant que le panneau des quêtes est montré ; la
chasse à la demande.
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
- L'OCR ne repasse que si le texte a changé (`SignatureZone`, `MesureSignature` par genre) :
  position, grille fixe 96 × 24 au seuil 225 ; combat, couleur sur la zone et empreinte du seul
  corps du bouton — le décompte ne relance rien, l'échéance est tenue localement
  (`EtatCombat.monTour(fin:)`, gardée à 1,5 s près) ; suivis, cadre des lignes lues (+1½ ligne
  vers le bas), grille fine 5 × 3 px au seuil 180 — la grille fixe d'une zone haute ne voit pas
  une ligne (mesuré). `auBord` : le texte touche le bas de la zone.
- Inventaire ScreenCaptureKit gardé (`captureData(…, inventaireGarde:)`).
- Le premier OCR `.accurate` charge le modèle, long à froid : `MoteurOCR.prechauffer()` le
  paie à l'activation.

## Genres — `GenreLecture`

Une seule table (`LecteurEcran.swift`) : par genre, `parDefaut` (`ZoneEcran.*ParDefaut`),
`reglage` (clé `zone…` des préférences, `nil` = défaut, qui suit ses corrections), `zone`.
Position et combat au tour ; **quêtes** au tour (`GenreLecture.intervalle`, 3 s) tant que le
panneau est montré et l'écran déjà autorisé (`QuetePanel` → `suivreQuetes`) ; chasse à la
demande (`lireUneFois`, même `capturer` et même `MoteurOCR`).

- Chasse : lignes → `EtapeChasse.ciblesLues` (bouton « Lire » et ouverture du panneau).
- Quêtes : le suivi de quêtes du jeu (`quetesParDefaut`, à gauche, estimé). Un seul chemin,
  `LectureSuivi.traiter` — `lire()` (bouton, ouverture), `recevoir` (tour, `.lue`), `confirmer`
  (tour, `.inchangee` : la lecture tient) — vers `SuiviQuetes.reconnaitre` (pur, hors main, sur
  `SuiviQuetes.Index` bâti une fois par jeu de quêtes) : une ligne de titre **est** un nom de quête
  (tolérance n/4, `surplusTitre` pour les icônes), pas seulement le contient ; ordre de
  l'écran, sans doublon, 10 au plus.
- Objectifs : `SuiviObjectifs` (pur). Le suivi montre les objectifs **actifs** de l'étape,
  dans son ordre, souvent sur deux lignes (fenêtres de 1 à 3 lignes), coupés par « VOIR
  PLUS… ». Affectation une fenêtre ↔ un objectif, la mieux lue d'abord (fautes n/5, débordement
  compté), doublons de texte départagés par l'ordre puis le plus tôt. L'étape : celle qui
  explique le plus de caractères, unique ; à défaut d'objectif lu en entier, les noms cités
  (`etapeParRenvois`). **Faits = ce qui précède le premier objectif montré** (« VOIR PLUS »
  coupe la fin, jamais le début), jamais ce qui suit ni les trous (pas encore ouverts :
  « Pense-bête » n'en montre qu'un sur neuf) ; seulement si l'écran suit l'ordre de l'étape et
  commence par un objectif reconnu. Les étapes d'avant aussi, si aucune autre étape ne lit mieux
  une ligne. Doublon ambigu : la première occurrence possible (prudent). Distance bornée
  (`distanceDansTexte(_:_:auPlus:)`, Ukkonen) : vingt étapes de vingt « Rapporter 1 âme… ».
- Panneau : tout vient de la lecture du **perso devant** (`persoDevant` publié), fraîche si
  l'écran l'a montrée — lue ou confirmée — il y a moins de 10 min. `aFaire` ambre ; `nonMontres`
  (ce que le suivi tait après le premier objectif montré, jusqu'à « VOIR PLUS… » ou `auBord`,
  seulement lignes toutes comprises et ordre suivi) en retrait « pas encore ouvert ».
  « Tu y es — fait ? » (`FicheQuete.Etape.suggeres`) : lecture fraîche de l'étape → seuls ses
  objectifs ouverts, tout ordre ; sans lecture et après la coupure → le prochain non coché ou
  celui en cours ; « Vaincre… » : un combat fini sur sa carte, à tout rang sauf si le suivi le
  tait. Une lecture passe par
  `Preferences.appliquer` (`CochesQuete`, seul chemin) : faits cochés si `quetesCocherSuivi`, jamais
  de décoche, jamais un objectif décoché à la main (`quetesDecoches`, oublié quand le suivi le
  remontre ouvert) ; une étape **sûre** (`Lecture.sure`) après celle du panneau l'y fait avancer.
- Par perso (`lireUneFois` rend le perso lu) : `HistoriqueSuivi` (pur, en mémoire). Persos lus à
  l'étape (moins de 24 h) à côté de son titre. « Terminée ? » : une quête sortie du suivi entre
  deux lectures du même perso, si la lecture voit le suivi dans le même ordre et que ni un titre
  mal lu (voisine du dessus ou en-tête plus longs) ni la zone (quête suivante encore lue, ou rien
  de nouveau ni de plus long au-dessus) ne l'expliquent. Suivi vide : rien n'est proposé (une
  fenêtre du jeu par-dessus ne s'en distingue pas).
- Objectifs ouverts ensemble (plusieurs `aFaire`) : ordre libre, numérotés au plus court
  (`Tournee`, coût `ItineraireZaap.cartes` par `ZaapClipboard.tournee`).
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
- `FinsDeCombat` (pur) : un combat **commencé** (pas le placement) fini sur sa carte de départ,
  où le perso est encore ; effacé au changement de carte (combat perdu) ou au retour en combat. Seul signal
  qui propose un objectif « Vaincre… » (`ObjectifQuete.typesCombat`, `typeId` DofusDB).

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
