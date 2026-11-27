---
name: forgemagie
description: Assistant de forgemagie — poids des effets et des runes (DofusDB), atelier de Dofus 3 retrouvé dans l'OCR par l'en-tête de sa table, issue d'une fusion tirée de deux lectures, séance, panneau. Charger avant de toucher Forgemagie/ ou docs/plans/forgemagie.md.
user-invocable: false
---

# Forgemagie

Synfus lit l'atelier et l'affiche ; il ne pose ni ne fusionne jamais une rune (CGU). Plan et lots :
`docs/plans/forgemagie.md` ; sources et degré de confiance : `docs/plans/forgemagie-recherche.md`.

## Invariants

- **Poids** : `effectPowerRate` de DofusDB (`GET /effects`) est le poids par point, seule source
  (`CatalogueFM`, arrondi au millième : le flottant simple ferait dépasser 505 Vitalité du plafond).
  Poids d'une rune = puissance × poids par point ; son rang (simple, Pa, Ra) suit l'ordre des
  puissances de son effet (`GET /items?typeId=78`). Chasse et signature hors catalogue.
  Téléchargé et gardé par `CatalogueFMDofusDB` (`Forgemagie.json`, 30 jours).
- **Effet en %** (`5% Résistance Terre`) et fixe (`5 Résistances Terre`) : deux effets. Un nom à
  égale distance de deux effets ne lit rien. Une ligne non reconnue reste montrée (`inconnues`).
- **Malus** : une ligne en malus garde l'effet positif, à valeur négative.
- **Exo** : ni min ni max lus (« - »). Un min sans max est une case mal lue, pas une exo.
- **Issue** (`FusionFM.constater`) : de la différence de deux tables, jamais de la couleur ; la rune
  posée ne se lit pas. La table **défile** : seules comptent les lignes vues des deux côtés. Une ligne
  apparue n'est une exo gagnée que si aucune n'a disparu, qu'elle n'a ni min ni max et que sa valeur
  est la puissance d'une rune (sinon : une ligne revenue dans la vue). Deux lignes qui montent : pas
  une fusion ; un gain qui n'est la puissance d'aucune rune de l'effet (plusieurs runes entre deux
  lectures, « Fusionner tout ») non plus. Gain sans perte → critique, sauf reliquat en baisse (le puits a payé) ; gain et perte →
  neutre ; perte seule → échec ; rien → pas de fusion.
- **Séance** (`SuiviFM`, une par perso, oubliée à la fermeture du panneau) : une lecture ne compte que
  **confirmée** par la suivante, identique (animation du jeu, chiffre mal lu) — une image inchangée,
  sans OCR, rejoue la dernière lecture et la confirme ; les jets max lus restent connus (une case mal
  lue n'en fait pas une exo). Un autre objet ou un autre perso oublie la cible réglée.
- **Conseil** (`ConseilFM`) : pour chaque ligne sous sa cible (jet max par défaut, ou la cible réglée au
  survol de la ligne, par crans de la plus petite rune), chaque rune de son effet reçoit un score
  0–100 : avancer vers la cible (0,35), sans la dépasser (0,25), au bon palier (0,15 ; rang attendu :
  la ligne pèse plus de 20 fois le poids du rang précédent), en risquant peu (0,10 ; perte probable =
  poids × (1 − critique), critique d'après la 1.27 : 66 % sous 80 % du max, 34 % au max, 15 % au-delà,
  moins ce que le reliquat absorbe), ligne lourde d'abord (0,15) ; un over ×0,6 ; jamais au-delà du
  plafond. Une proposition par ligne (sa meilleure rune), trois montrées ; les raisons de la première
  restent en vue (les infobulles d'une app inactive se montrent mal). Les pondérations sont un choix,
  pas une mesure : les éprouver en jeu avant d'y toucher.
- **Puits** : le jeu l'**affiche** (« reliquat : 0.1 ») ; l'historique ne dit que « + reliquat » /
  « - reliquat ». L'ordre des pertes n'est pas publié : il se constate.
- **Plafond** : over + exo d'une ligne ≤ 101 de poids (`ObjetFM`) ; par ligne ou par objet reste à
  vérifier en jeu (question 3 du plan).
- **Séance** (`SuiviFM`) : un autre objet (aucune ligne commune, ou un jet max qui change) repart de zéro.

## Lecture de l'atelier — `AtelierFM` (pur), `ForgemagieModele`

- Pas de zone calibrée ni de genre : la première lecture fait l'OCR du contenu entier
  (`LecteurEcran.imageDevant` puis `textes`), l'atelier se retrouve par l'en-tête « Min / Max / Effets /
  Carac. » (le premier complet : une infobulle peut porter « Effets » ; « Max » se lit parfois en
  lettres cyrilliques : c'est la case entre Min et les effets), et les suivantes se bornent à son
  cadre élargi (stocks compris). Toutes les 1,5 s, panneau ouvert et Dofus devant ; 5 s atelier absent ;
  une image identique à la précédente ne repasse pas par l'OCR.
- L'historique est sur cinq pas et demi de colonne (pas Min–Max) à gauche de « Min » : il se lit aussi
  dans une lecture bornée, et le suivi de quêtes n'y entre pas. Il n'est pas encore recoupé avec la table.
- L'OCR rend les cases **une à une et dans le désordre** : rangées par position. Colonne des effets
  entre « Max » et « Modif. » (l'infobulle d'une rune, à droite, n'y entre pas) ; min et max à
  mi-pas de leur en-tête. Historique : à gauche de « Min », sous « FUSIONNER », au-dessus de
  « VIDER L'HISTORIQUE » (le suivi de quêtes, plus à gauche, n'y entre pas).
- L'icône d'une ligne se lit en caractères parasites (« 3 46 Sagesse », « - 7% Critique »,
  « 9 190 Pods ») : le nombre retenu est le dernier avant le nom, son signe seulement s'il y est collé.
- Stocks de runes (Pa, Ra) trop mal lus (« 55.0 », « 870 ») : leur nombre n'est pas lu, leur place
  si (`AtelierFM.runes`) : colonnes simple, Pa, Ra au milieu des stocks lus, sinon à un cinquième de
  pas à droite des en-têtes Pa et Ra ; rangée de chaque effet. Le calque (`CalqueForgemagie`, sur
  `CalqueSurJeu`) y entoure la case de la meilleure rune.
- **Après un clic** du joueur dans le cadre de l'atelier (observé par un moniteur global passif,
  jamais émis) : relecture à 250 ms puis toutes les 350 ms jusqu'à une lecture sûre
  (`SuiviFM.AttenteClic` : deux lectures égales et différentes d'avant le clic, ou égales depuis
  1,2 s, ou 4 s passées) ; pendant ce temps, « Lecture… », conseils voilés et calque retiré.
  Le conseil n'a qu'une source : `ForgemagieModele.propositions`.
- Fixtures : `FixturesAtelierFM` (textes et cadres de quatre captures, sans image ni tchat).
