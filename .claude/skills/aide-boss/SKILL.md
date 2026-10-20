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
  `57%`, `3 450 / 4 200`, ou points seuls (pourcentage par un maximum déjà lu, jamais supposé).
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
