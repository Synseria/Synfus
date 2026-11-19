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

- Couleurs : `Jetons` (engendré par Synseria-Design, jamais retouché) est la seule source. Le thème
  courant (thème × nuance, `ThemeCourant`) se lit par chemin — `Color.jeton(\.plaque)` —, dynamique
  Jour/Pénombre quand l'app suit macOS, et lu dans un `body` : le changement (Réglages ▸ Thème : nuance,
  thème) se voit en direct. Aucune liste de rôles recopiée. Rôles : `accent` (aplat) + `texteSurAccent`,
  `accentTexte` (couleur écrite, « regarde ici »), `selection`/`survol` (le choix), `creux`, `filet`,
  `encre`/`encre2`/`encre3`, `avertissement` (ce qui réclame un geste), `danger` (un échec, le
  destructif) + `texteSurDanger`, `succes`, `info` ; `Color.suggestionSynfus` (propre à Synfus) ; une
  couleur de classe vient de `DofusClass`. Sur une image du jeu : `Color.jeton(_, en: .nuit)`.
- Polices : `.font(Jetons.typoCorps.font)`, un rôle `Jetons.typo*` (TitrePage, Section, TitreCarte,
  Corps, Lecture, Meta, Code, Micro), aucun texte sous `micro` ; ni graisse ni dessin à la carte :
  appuyer un texte, c'est changer de rôle ; un chiffre aligné, `.monospacedDigit()`. Racine de fenêtre,
  feuille et popover : `.racineSynfus()` (teinte = accent, couleurs de la trousse). `JetonsTests` et
  `CouleursTests` tiennent le tout.
- Lignes de réglage : `Ligne`, `LigneInterrupteur`, `RaccourciReglable`. `etat:` (en méta, avant le
  contrôle) ne prend qu'une valeur, un état, le résultat d'une action ou une mention légale ; une
  explication va en infobulle (`aide:`), jamais derrière un ⓘ. `LigneInterrupteur` n'a pas d'`etat:`.
  Une page n'a pas de titre : les onglets (`BarreDesOnglets`) disent où l'on est.
- En-têtes de panneau : `EnTetePanneau` ; tailles de la fiche : `MetriquesQuete`.
- Un libellé passe par `L()` et se vérifie dans les trois langues : l'espagnol et le français sont
  les plus longs, un nom du jeu peut l'être davantage.

## Dessin commun — `Interface/Composants.swift`

- États : `EtatVisuel` (repos, survol, presse, choisi, courant, désactivé) ; `fondEtat` pour un fond, `StyleEtat`
  pour une tuile ou une puce cliquable. **Plein** (`courant`) = où je suis, un par zone (perso devant, filtre
  de la palette, onglet des réglages, équipe active) ; **teinté** (`choisi`) = ce que j'ai choisi (mode
  allumé, rangée choisie de la palette, direction de la chasse).
- Boutons, segmenté, touche, badge, interrupteur, carte, confirmation : la trousse
  (`Interface/Trousse`, engendrée) — `BoutonPrincipal`, `BoutonBorde`, `BoutonTertiaire`,
  `BoutonDestructif`, `BoutonIcone` ; `SegmenteTexte` ; `ToucheDeClavier` (`surUnPlein` sur l'accent) ;
  `Badge` ; `.toggleStyle(.interrupteur)` ; `.carte(marge:)`. Jamais de « … » sur un bouton
  (`LocalisationTests`). Réglages : `BoutonBorde` posé par `PageReglages`.
- Tout geste qui détruit se confirme : dans une vue, `.confirmation($demande, annuler:)` (feuille de la
  trousse) ; hors de toute vue (menu, panneau sur le jeu), `ConfirmationHorsVue.demander` (l'alerte de la
  trousse, au premier plan). « Verbe + objet ? », Entrée ne détruit jamais.
- Ce qui flotte : `surfaceFlottante()`, le verre léger des flottants sans liseré ni ombre (`hasShadow =
  false`) ; verre refusé (transparence réduite, contraste augmenté, captures), plein et bordé d'un filet.
  Le texte long d'un flottant est sur `plaquePleine()` : liste de la palette, corps des panneaux.
- `Tests/ComposantsTests` refuse rayon, marge, espace, police, courbe ou encre du système chiffrés dans une vue.

## Écarts gardés

- Couleurs venues du jeu, hors thème : les classes (`DofusClass`), le rose de « Fin de tour »
  (`CombatBadge.rose`), `Color.texteSurClasse` (le blanc du sigle sur une couleur de classe).
- `MetriquesQuete.compact` : tout en méta, lignes collées, pour laisser voir le jeu.
- Voile de zone de `CalibrationZonesView`, opacité de glisser des pastilles. Jamais de texte sur une
  image du jeu : la carte d'un zaap est pleine, sa vue en vignette (`MiniatureCarte`).
- Battement de l'alerte et de la bascule (`Battement`) : l'opacité qui pulse est le signal.
- Largeurs de colonnes, de champs et de fenêtres (réglages, panneaux) : mises en page, pas des tailles de décor.

## Relevés dans le code

Un résultat se regarde, il ne vaut pas défaut à lui seul.

```sh
rg -t swift 'lineLimit\(1\)' Sources                             # troncatures à justifier
rg -t swift 'textCase' Sources                                   # capitales
rg -t swift 'etat:' Sources/Synfus/Interface/Reglages            # une valeur, pas une phrase
rg -t swift 'withAnimation|\.animation\(|repeatForever' Sources  # à croiser avec reduceMotion
rg -t swift 'accessibilityLabel|onTapGesture' Sources
```

## Captures

`SYNFUS_CAPTURES=$PWD/docs/screenshots sh test.sh CapturesTests` : à part, écran allumé, Dofus
fermé, aucun autre build en cours. Avec `SYNFUS_CAPTURES_TOUT=1`, tous les onglets des réglages. Rendu par `cacheDisplay` : le verre, le survol et l'accent des
interrupteurs ne s'y jugent pas, ils se voient en vrai (`sh run.sh --install --start`).

## Ce qui ne vaut pas ici

- Interdiction du verre : la barre le garde (`glassEffect`, repli `.ultraThinMaterial`), elle flotte sur le jeu.
- `@Observable` à la place d'`ObservableObject` : hors sujet d'une critique d'écran.
