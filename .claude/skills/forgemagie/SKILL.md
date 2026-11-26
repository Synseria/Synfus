---
name: forgemagie
description: Assistant de forgemagie — poids des effets et des runes (DofusDB), puits recompté, issue d'une fusion tirée de deux lectures de la table, texte de l'atelier de Dofus 3 (historique, reliquat). Charger avant de toucher Forgemagie/ ou docs/plans/forgemagie.md.
user-invocable: false
---

# Forgemagie

Synfus lit l'atelier et recommande ; il ne pose ni ne fusionne jamais une rune (CGU). Plan et lots :
`docs/plans/forgemagie.md` ; sources et degré de confiance : `docs/plans/forgemagie-recherche.md`.

## Invariants

- **Poids** : `effectPowerRate` de DofusDB (`GET /effects`) est le poids par point, seule source
  (`CatalogueFM`). Poids d'une rune = puissance × poids par point ; son rang (simple, Pa, Ra) suit
  l'ordre des puissances de son effet (`GET /items?typeId=78`). Rune de chasse (puissance 0) et de
  signature (sans effet) hors catalogue.
- **Malus** : une ligne en malus garde l'effet positif, à valeur négative ; l'effet opposé ne sert pas.
- **Issue** (`FusionFM.constater`) : de la différence de deux tables, jamais de la couleur. Ligne visée
  montée sans perte → succès critique, sauf reliquat lu en baisse (le puits a payé) ; montée avec
  perte → neutre ; pas montée → échec.
- **Puits** : un succès critique n'y touche pas ; sinon `puits + poids perdu − poids de la rune`,
  jamais sous 0, décimales gardées. **L'ordre des pertes n'est pas publié** : il se constate.
- **Plafond** : over + exo d'une ligne ≤ 101 de poids (`ObjetFM.depasseraitPlafond`) ; par ligne ou par
  objet reste à vérifier en jeu (question 3 du plan).

## Atelier de Dofus 3 (captures du 25/11/2026)

- En-tête : « reliquat : N » (le puits est **affiché**, en italique), trois cases, « FUSIONNER TOUT »,
  « FUSIONNER ».
- Historique à gauche, le plus récent en bas : « Échec », un gain **sans « + »** (« 3 Chance », vert),
  une perte « -10 Chance » (rouge) — `TexteFM`.
- Table : Min, Max, Effets / Carac. (« 16 Chance »), Modif. (pastille « +3 »), puis le **stock de
  runes** par rang (Pa, Ra ; trois pastilles, une sans nombre quand le stock est inconnu). La ligne
  d'arme (« 9 à 11 dommages Eau ») est sur fond plein, non modifiable.
- Prix d'une rune : le prix estimé de l'infobulle au survol (arbitrage de l'utilisateur).
