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
  posée ne se lit pas. La table **défile** : seules comptent les lignes vues des deux côtés, plus une
  ligne apparue quand aucune n'a disparu (exo). Gain sans perte → critique, sauf reliquat en baisse
  (le puits a payé) ; gain et perte → neutre ; perte seule → échec ; rien → pas de fusion.
- **Puits** : le jeu l'**affiche** (« reliquat : 0.1 ») ; l'historique ne dit que « + reliquat » /
  « - reliquat ». L'ordre des pertes n'est pas publié : il se constate.
- **Plafond** : over + exo d'une ligne ≤ 101 de poids (`ObjetFM`) ; par ligne ou par objet reste à
  vérifier en jeu (question 3 du plan).
- **Séance** (`SuiviFM`) : un autre objet (aucune ligne commune, ou un jet max qui change) repart de zéro.

## Lecture de l'atelier — `AtelierFM` (pur), `ForgemagieModele`

- Pas de zone calibrée ni de genre : la première lecture fait l'OCR du contenu entier
  (`LecteurEcran.textesDevant`), l'atelier se retrouve par l'en-tête « Min / Max / Effets / Carac. »
  (« Max » se lit parfois en lettres cyrilliques : c'est la case entre Min et les effets), et les
  suivantes se bornent à son cadre élargi. Toutes les 2 s, panneau ouvert et Dofus devant.
- L'OCR rend les cases **une à une et dans le désordre** : rangées par position. Colonne des effets
  entre « Max » et « Modif. » (l'infobulle d'une rune, à droite, n'y entre pas) ; min et max à
  mi-pas de leur en-tête. Historique : à gauche de « Min », sous « FUSIONNER », au-dessus de
  « VIDER L'HISTORIQUE » (le suivi de quêtes, plus à gauche, n'y entre pas).
- L'icône d'une ligne se lit en caractères parasites (« 3 46 Sagesse », « - 7% Critique »,
  « 9 190 Pods ») : le nombre retenu est le dernier avant le nom, son signe seulement s'il y est collé.
- Stocks de runes (Pa, Ra) trop mal lus (« 55.0 », « 870 ») : pas lus.
- Fixtures : `FixturesAtelierFM` (textes et cadres de quatre captures, sans image ni tchat).
