# Exceptions de Synfus à la grille UI

La grille est le skill global `grille-ui`. Ici, seulement ce qui lui manque ou la corrige pour Synfus.

## Deux familles de surfaces

- **Réglages** : fenêtre activée, formulaire ou liste, on y passe peu de temps. Le système d'abord
  (`Form` groupé, `Ligne`, `Interrupteur`, `PageListe`).
- **Surfaces de jeu** (barre, palette, quêtes, chasse, boss, aperçus) : posées sur Dofus, Synfus
  reste inactif, regardées d'un coup d'œil entre deux tours, vues des centaines de fois par session.
  Lisibles sur n'importe quel décor du jeu, sans animation d'entrée, sans voler le clavier. Seules
  la palette et la chasse deviennent key : ailleurs ni ⎋ ni ⏎, une sortie à la souris.

## Jetons

- Couleurs : `Couleurs` (accent, ambre, suggestion) ; une couleur de classe vient de `DofusClass`.
- Lignes de réglage : `Ligne`, `Interrupteur`, `RaccourciReglable`. Sous un libellé, `etat:` ne prend
  qu'une valeur ou un état ; une explication va dans `aide:` (ⓘ). Un titre de page n'a pas de phrase :
  `EnTetePage` prend un compte (`valeur:`) et une `aide:`.
- En-têtes de panneau : `EnTetePanneau` ; tailles de la fiche : `MetriquesQuete`.
- Un libellé passe par `L()` et se vérifie dans les trois langues : l'espagnol et le français sont
  les plus longs, un nom du jeu peut l'être davantage.

## Relevés dans le code

Un résultat se regarde, il ne vaut pas défaut à lui seul (une icône de 8 pt n'est pas un texte).

```sh
rg -t swift '\.bold\(\)|weight: \.(bold|heavy)' Sources          # gras
rg -t swift -o '\.system\(size: [0-9.]+' Sources                 # tailles employées
rg -t swift 'accentColor|\.orange' Sources                       # hors `Couleurs`
rg -t swift 'lineLimit\(1\)' Sources                             # troncatures à justifier
rg -t swift 'textCase' Sources                                   # capitales
rg -t swift 'etat:' Sources/Synfus/Interface/Reglages            # une valeur, pas une phrase
rg -t swift 'withAnimation|\.animation\(|repeatForever' Sources  # à croiser avec reduceMotion
rg -t swift 'accessibilityLabel|onTapGesture' Sources
```

## Captures

`SYNFUS_CAPTURES=$PWD/docs/screenshots sh test.sh CapturesTests` : à part, écran allumé, Dofus
fermé, aucun autre build en cours. Rendu par `cacheDisplay` : le verre, le survol et l'accent des
interrupteurs ne s'y jugent pas, ils se voient en vrai (`sh run.sh --install --start`).

## Ce qui ne vaut pas ici

- Interdiction du verre : la barre le garde (`glassEffect`, repli `.ultraThinMaterial`), elle flotte sur le jeu.
- `@Observable` à la place d'`ObservableObject` : hors sujet d'une critique d'écran.
