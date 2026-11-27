---
name: aide-boss
description: Aide aux boss dont la mécanique demande de réfléchir — Comte Harebourg (confusion des sorts, lue au cœur de vie et au canal combat), Kimbo, Toxoliath, Ilyzaelle, Tal Kasha —, tour du combat compté, panneau posé sur le jeu. Charger avant de toucher Boss/ (Boss, Harebourg, SuiviConfusion, ToursCombat, AideBoss, BossPanel, BossVue, VuesBoss), les genres de lecture vie et tchat, `EtatCombat.nouveauTour`, ou d'ajouter un boss.
user-invocable: false
---

# Aide aux boss

Synfus lit l'écran et affiche ; viser et lancer restent au joueur (CGU : aucun évènement émis).

## Comte Harebourg — `Boss/Harebourg.swift` (pur)

- **Confusion** : à chaque début de tour, le sort tombe sur la case visée tournée autour du
  lanceur de `quarts` quarts de tour **horaires** (`Confusion`, 0…3). Viser : la cible tournée à
  rebours (`caseVisee`, `visee` : 1 → gauche, 2 → opposée, 3 → droite). La projection isométrique
  garde le sens de rotation.
- **Corps à corps** : chaque ligne de dégâts tourne d'un quart **contre-horaire** (`apres(coups:)`).
- **Vie** : tranches relevées par les joueurs (Papycha, Dofus pour les noobs) — 100–91 horaire,
  90–75 contre-horaire, 74–46 demi-tour, 45–31 contre-horaire, 30–1 horaire ; à moins d'un point
  d'un plancher (`margeFrontiere`), la voisine est signalée (`ParVie.voisine`). Cœur lu :
  `57%`, `3 450 / 4 200` (ou à cheval sur deux lignes), courant puis maximum sur deux lignes
  (maximum ≥ `maxPlancher` : les PA et PM sous le cœur n'en sont pas ; les milliers ne passent
  jamais d'une ligne à l'autre), ou points seuls (pourcentage par un maximum lu **dans ce combat**,
  jamais supposé). Le maximum (`SuiviConfusion`) : le dernier écrit fait foi, un saut de plus de
  30 % attend une seconde lecture (le douteux ne sert pas au pourcentage), des points au-delà
  l'invalident. Un nouveau combat (`SuiviConfusion.nouveauCombat`, appelé par `AideBoss` au premier
  placement vu après un tour — `combatEngage` : un autre perso lu en placement avant tout tour, c'est
  le même combat) oublie vie et maximum de **tous** les persos, et les pivots.
- **Vie du Comte** : lue au survol, dans le panneau qui remplace la barre de sorts (genre `survol`,
  `Harebourg.vieDuComte` : un nom qui porte « Harebourg », puis `a / b` d'abord — l'OCR rend aussi
  résistances et « 10% » dans le désordre —, le pourcentage entre parenthèses, un nombre seul),
  gardée pour le combat (`SuiviConfusion.comte`) ; sans maximum lu, la part se dit par rapport au
  maximum DofusDB du plus haut grade (« ≈ »). « a / b » : chaque nombre borné au motif des milliers.
- **Grille** : la conversion case ↔ point est `GrilleIso` (`Lecture/`), seule source ; la grille du
  combat en fractions du contenu — origine, demi-largeur `a` en fraction de la **hauteur**, rapport
  largeur/hauteur (±1 %, sinon invalide) —, **jamais réglée à la main** : un état de `ViseePanel`,
  retrouvé sur l'écran à chaque tour (plus de feuille de calibrage ni de réglage). Mesuré sur une
  fenêtre de 2000 × 1234 px : `a` = 53 px (0,043 de la hauteur) ; une capture zoomée donnait 75 px.

## Visée sur le plateau — `ViseeHarebourg` (pur), `ViseePanel`

- Réglage `harebourgVisee`, éteint par défaut. Le calque ne fait que dessiner : `CalqueSurJeu`
  (commun avec la forgemagie), posé sur le contenu de la fenêtre du perso devant (`FenetreJeu`).
- **Relevé du plateau** (`PlateauCombat`, `PorteeSort`, purs ; `ViseePanel.relever`, deux captures par
  seconde au plus, pendant le tour) : la grille est retrouvée à chaque tour par la périodicité des joints (énergie des
  bords projetée sur `x + 2y` et `2y − x`, autocorrélation, repli lissé sur la portée de la mesure —
  un joint répond par deux pics ; demi-période vérifiée). Une grille qui coïncide avec celle en place
  (`GrilleIso.coincide` : l'origine retrouvée tombe sur une autre case) la laisse, pivots compris ;
  une autre la remplace et oublie les pivots ; non retrouvée, pas de pivot cherché. Le pivot : la
  case dont le losange porte le liseré blanc et creux du perso actif (côtés du bas surtout, que le
  perso masque moins ; intérieur et pourtour non blancs ; points bordés de rouge écartés — le liseré
  de la case visée ; cases du plateau seulement, `grilleLocale` ; nette avance sur la suivante),
  retenue à la seconde lecture identique, et seulement sans sort préparé (il masque le liseré).
- **Portée** (`PorteeSort`) : le jeu teinte de bleu les cases à portée, foncé avec ligne de vue,
  clair sans. Le sol change d'une carte à l'autre : une case n'est bleuie que comparée à elle-même
  sans sort (la référence, reprise à chaque lecture sans sort). Cinq taches par case (centre, près
  des sommets) ; bleuie si le bleu monte devant le rouge **et** le vert (le vert d'un déplacement
  monte aussi devant le rouge) sur trois taches ; couverte (perso, marque rouge de la visée du jeu) :
  elle garde ce qu'on en savait. Foncé / clair : coupe d'Otsu sur la luminance, une seule teinte si
  les moyennes sont à moins de 15. Moins de trois cases bleuies : pas de sort. Banc :
  `SYNFUS_PORTEE=<sans sort>:<sort préparé> sh test.sh porteeSurCapturesReelles`.
  Mesuré : une case de 52 px sur 2000 × 1234 (deux monstres voisins le confirment ; le motif du sol trompe l'œil).
  Banc : `SYNFUS_PLATEAU=<capture> sh test.sh plateauSurCaptureReelle` ; les captures de calibrage
  (`combat.png`, `vie.png`…) donnent 0,0433 de la hauteur, la mesure à la main.
- Pivot à la main : raccourci « Marquer ma case » (`marquerLanceurHotKey`, sans défaut) → la case sous le
  pointeur (pas sur une fenêtre de Synfus), rangée sous le perso au premier plan ; tous les pivots
  sont oubliés au nouveau combat (`AideBoss.combats`). Le calque ignore les fenêtres de Synfus qui
  laissent passer les clics (`ignoresMouseEvents`) et celles d'un autre bureau. Rien à marquer : bip. Le Diagnostic garde la raison
  vue en jeu quand Dofus passe derrière (`raisonAffichee`).
- Arrivée : `arrivee = pivot + caseAtteinte(survolée − pivot)`, la voisine en pointillés à une
  limite de tranche ; l'estimation compte déjà les coups. `Confusion.caseAtteinte` est l'inverse
  exact de `caseVisee`. Hors des cases bleuies (ni foncée, ni claire, ni couverte) : `dansLaZone`
  faux, le sort part dans le vide.
- Actif pendant le tour du perso devant (`ViseeHarebourg.inactive`, raison au Diagnostic et dans le
  panneau) : réglage, Comte suivi, `BossPanel.montre`, son tour, grille lue et valable pour le
  rapport de la fenêtre, pivot, confusion connue, **sort préparé**, pointeur sur le jeu (pas sur une
  fenêtre de Synfus), **case visée foncée ou couverte** (`visable` ; le bleu clair n'a pas de ligne de vue).
- Coûts : veille à 2 Hz réglage allumé contre le Comte (cadre de la fenêtre par le serveur de
  fenêtres, `CrossSpaceTitles.cadreAffiche` — un client gelé ne bloque rien) ; relevé du plateau à
  2 Hz pendant son tour ; pointeur à 30 Hz seulement calque possible, sur la portée gardée.
- Dessin en Nuit (`CalqueVisee`) : arrivée `succes` pleine et « Tombe ici » — `danger` et « Tombe
  hors zone » hors de la zone —, voisine `avertissement` en pointillés, case visée d'un filet,
  pivot cerclé, chaque trait sur un halo.
- Non vu en jeu à l'écriture : plein écran, changement de rapport, clic qui traverse, caméra zoomée.
- **Canal combat** : `[14:04] Nom : …` ; un angle en degrés ou en Pi (`3Pi/2`, `1/2 pi`, `π`) **et**
  un sens (`horaire`, `contre horaire`, en/es aussi) — sans sens, rien (le jeu l'écrit toujours,
  demi-tour compris). Une ligne repliée se recolle à celle du dessus (sans heure). Le nom avant
  les deux-points, à une faute près, parmi les persos connus.

## Tours — `ToursCombat` (pur), `EtatCombat.nouveauTour`

Le tour du combat = le nombre de débuts de tour du perso devant (chaque perso joue une fois par
tour) ; le placement remet à zéro, la sortie efface, ±1 à la main. Un début de tour : entrer
dans `monTour`, **ou** un `monTour` dont l'échéance change — le bouton gris entre deux tours du
même perso est souvent manqué (passage automatique ailleurs). Pour que le décompte soit relu,
`LecteurEcran.tour` jette la signature du combat d'un perso dont l'échéance est passée.

## Autres boss — `Boss.swift` (pur), `VuesBoss`

- **Kimbo** : Terre/Eau → « Glyphe impaire » (glyphes du Disciple à distance impaire) ; Air/Feu →
  paire. Se tenir à l'autre parité, y amener Kimbo, le frapper dans les éléments de l'état
  (+800 % dans les autres). Lu au canal combat (`Kimbo.etat`, mots entiers), ou choisi d'un clic.
- **Toxoliath** : vagues aux tours 1/6/11/16/21, Poison Volatile au 6 puis tous les 4 ;
  Toxmose deux tours après un coup (bouton « Je l'ai touché »).
- **Ilyzaelle** : seuils 75 % et 50 % notés d'un clic (vie du boss non lue), deux tours alliée
  après chacun ; Vers les ténèbres aux tours multiples de 3.
- **Tal Kasha** : compteur I–III des glyphes où elle a commencé son tour.
- `SessionBoss` : ce qui est noté pendant un combat, remis à zéro au **placement** seulement
  (chaque perso est lu quand il passe devant : une première lecture en combat n'est pas un
  nouveau combat). `Boss.lectures` : ce qui se lit en plus du combat.

## Boss suivi, salle, fiche, guide — `CibleBoss` (pur), `Donjons.donjon(zone:)`

- **Tous les boss de donjon** : `CibleBoss` = `.special(Boss)` (mécanique connue) ou
  `.donjon(monstre:donjon:)` (fiche, éléments, conseils, tour). `CibleBoss.boss(_:donjon:)` rend
  à sa mécanique un boss qui en a une : un seul chemin, palette ou entrée dans le donjon.
  Sauvegardé en chaîne (`harebourg`, `donjon:1045:28`) : l'ancienne sauvegarde `Boss` se relit.
- **Salle** : `Donjons.donjon(zone:)` cherche le nom du donjon (fr/en/es, DofusDB) dans la zone
  lue au-dessus de la position, à `fautesTolerees` près, le nom le plus long d'abord (une
  expédition l'emporte sur son donjon). `AideBoss` choisit son premier boss **en entrant** (un
  choix à la main dedans tient) ; jamais d'ouverture du panneau d'office. Il faut la lecture de
  la position et la liste des donjons (`DonjonsStore.charger`, demandée à la première zone lue).
- **Fiche** : `CibleBoss.monstre` → `FicheCombat` du plus haut grade, demandée une fois par
  lancement, muette en cas d'échec ; éléments à frapper et à éviter (`FicheCombat.elements`).
- **Guide et conseils** : par le donjon du boss (`AideBoss.donjon`, `Donjon.nomFrancais`,
  `DonjonsStore.conseils`).
- **Compteurs d'usage** : seuls les boss à mécanique sont comptés (`EvenementUsage` est une liste
  fermée : rien d'autre ne part).
- Ajouter un boss à mécanique : ses règles pures, `monstre`, sa vue, ses rappels, ses libellés.

## Suivi — `SuiviConfusion` (pur)

Par perso : début et fin de tour (bouton de combat), vie au début du tour (la première lecture
dans `delaiVieDebut` après le bouton), annonces, coups, choix à la main. Priorité :
**main** (jusqu'à la fin du tour, coups repartis de zéro) › **annonce du tour** (nommée et plus
récente que la fin de son dernier tour, ou anonyme vue au plus `toleranceDebut` avant le bouton ;
elle compte déjà les coups, le jeu en annonce chaque changement) › **vie au début du tour** +
coups › hors du tour, **prévision** sur la vie actuelle. Une annonce est nouvelle si son texte
change ou si une ligne pareille paraît plus bas (`Repere` par fenêtre : la même ligne ne fait
que monter).

## Lecture et panneau

- Genres `vie` (`.zone`) et `tchat` (`.lignes`), zones mesurées sur une fenêtre 1728 × 1084
  (`ZoneEcran.vieParDefaut`, `tchatParDefaut`), calibrables. Lus au tour, chaque seconde,
  **seulement** panneau montré, écran déjà autorisé (`LecteurEcran.suivreBoss`) et perso devant
  en combat ; le combat est lu dès que le panneau est montré, `lireCombat` éteint ou non.
- `AideBoss` (main) : reçoit les lectures, suit `LecteurEcran.$combats` (changement de genre
  seulement), sert le perso devant.
- `BossPanel` : **jamais clé** — la frappe reste aux raccourcis de sorts. Visibilité par
  `PanneauxJeu.revoir`, le seul endroit qui énumère les panneaux du jeu.

## Ajouter un boss

Un cas de `Boss` (nom, `lectures`, rappels dans `BossVue`), ses règles pures dans `Boss.swift`
testées (`BossTests`), sa vue dans `VuesBoss`, ce qu'il retient dans `SessionBoss`. La palette
en tire une entrée (`ActionPalette.toutes`), l'onglet Boss une ligne. Un nouveau genre de lecture
passe par la table `GenreLecture`.
