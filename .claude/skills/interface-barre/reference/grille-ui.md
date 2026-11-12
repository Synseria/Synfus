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
  courant (réglage × clair/sombre, `ThemeCourant`) se lit par chemin — `Color.jeton(\.surface)` —, dynamique clair/sombre et lu dans un `body` : le changement
  (Réglages ▸ Thème : couleur de l'app, teinte des fonds, `nil` = Auto) se voit en direct. Aucune liste de jetons
  recopiée. `primaire` (trait, aplat) + `encreSurPrimaire`
  (texte posé dessus), `primaireEncre` (couleur écrite), `safran`/`safranTexte`/`safranFond` (« regarde
  ici », jamais un état), `suggestionSynfus`, `alerte`, `succes`, `danger`, `dangerPlein` + `encreSurDanger` (bouton destructif), neutres ; une couleur de
  classe vient de `DofusClass`.
- Polices : `.font(Jetons.Typo.corps.police)`, un rôle de `Jetons.Typo` (titrePage, titre, corps, corpsFort, note,
  petit, micro, chiffre, grandChiffre, code, codeInterface, raccourci), aucun texte sous `micro` ; ni graisse
  ni dessin à la carte : appuyer un texte, c'est changer de rôle. Racine de
  fenêtre : `.racineSynfus()` (teinte = primaire). `JetonsTests` (aucune couleur ni police construite hors de Jetons, aucun ancien point de passage) et `CouleursTests` tiennent le tout.
- Lignes de réglage : `Ligne`, `Interrupteur`, `RaccourciReglable`. Sous un libellé, `etat:` ne prend
  qu'une valeur, un état, le résultat d'une action ou une mention légale ; une explication va dans
  `aide:` (ⓘ). `Interrupteur` n'a pas d'`etat:`. Un titre de page n'a pas de phrase : `EnTetePage`
  prend un compte (`valeur:`) et une `aide:`.
- En-têtes de panneau : `EnTetePanneau` ; tailles de la fiche : `MetriquesQuete`.
- Un libellé passe par `L()` et se vérifie dans les trois langues : l'espagnol et le français sont
  les plus longs, un nom du jeu peut l'être davantage.

## Dessin commun — `Interface/Composants.swift`

- États : `EtatVisuel` (repos, survol, presse, choisi, courant, désactivé) ; `fondEtat` pour un fond, `StyleEtat`
  pour une tuile ou une puce cliquable. **Plein** (`courant`) = où je suis, un par zone (perso devant, filtre
  de la palette, onglet des réglages, équipe active) ; **teinté** (`choisi`) = ce que j'ai choisi (mode
  allumé, rangée choisie de la palette, direction de la chasse).
- Boutons : `StyleBouton` (`.bouton(.principal | .secondaire | .tertiaire | .destructif, dense:)`) — le
  destructif est plein `dangerPlein` ; `dense` (`cibleMin`) pour les panneaux posés sur le jeu. Jamais de « … »
  sur un bouton (`LocalisationTests`). Réglages : secondaire posé par `PageReglages`/`PageListe`.
- Tout geste qui détruit passe par `Confirmation.demander(DemandeConfirmation(titre:detail:verbe:))` : feuille
  « Verbe + objet ? », « Annuler » à gauche, le verbe en destructif à droite, Entrée ne détruit jamais.
- Une touche de clavier : `ToucheRaccourci`, nulle part ailleurs (palette, enregistreur de raccourci).
- Fenêtre : `carte()` (surface + filet, sans ombre), fonds `Color.jeton(\.fenetre)` (le formulaire natif laisse voir
  la teinte choisie). Ce qui flotte : `surfaceFlottante()` ; l'ombre `flottant` est celle de la fenêtre
  (`hasShadow`), une ombre SwiftUI serait coupée au cadre du panneau.
- `Tests/ComposantsTests` refuse rayon, marge, espace, police, courbe ou encre du système chiffrés dans une vue.

## Écarts gardés

- Couleurs venues du jeu, hors thème : les classes (`DofusClass`), le rose de « Fin de tour »
  (`CombatBadge.rose`), `Color.texteSurClasse` (le blanc du sigle sur une couleur de classe).
- `controleDense` (22) et `rangeeDense` (24) ne sont plus des jetons de Synfus : les panneaux posés sur le jeu
  prennent `Taille.cibleMin` (24) en attendant qu'ils reviennent.
- `MetriquesQuete.compact` : écarts de 1 et 2 pt, sous la grille, pour laisser voir le jeu.
- `FondCarte` : seul dégradé et seul voile d'opacité (`voileImage`, `voileTexte`) ; le texte d'une case
  passe sur une image du jeu. Voile de zone de `CalibrationZonesView`, opacité de glisser des pastilles.
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
