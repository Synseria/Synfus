---
name: localisation
description: Interface en français, anglais et espagnol — L("clé"), tables JSON de Resources/Localisation, choix de langue, LocalisationTests. Charger avant d'ajouter ou modifier un libellé visible, une vue, une clé de fr/en/es.json, Localisation/ (Localisation.swift, LangueReglage) ou un test qui compare un libellé.
user-invocable: false
---

# Localisation

`Sources/Synfus/Localisation/Localisation.swift` tient tout ; les textes vivent dans
`Resources/Localisation/{fr,en,es}.json` (objet plat trié).

## Règles

- Le code ne porte que des **clés** : `L("barre.aucunPerso")`, `L("raccourcis.perso", slot + 1)`.
  Jamais de libellé en dur dans une vue.
- Français = langue source et repli : clé absente d'une traduction → français ; absente de tout
  → la clé telle quelle (visible, donc corrigeable).
- Arguments `String(format:)` : `%@` pour un texte, `%lld` pour un entier (jamais un `Int32` :
  convertir `pid_t` en `Int`).
- **Une seule chaîne par libellé** : une aide composée en `"…" + "…"` se traduit mal et casse
  l'ordre des arguments.
- `SynfusMark`, que `Tools/AppIconExport.swift` compile seul, n'appelle pas `L()`.
- Restent en français : journaux et sorties `--dump-*`.

## Mécanique

- Pas de `.lproj` ni de `Bundle.module` : `build.sh` copie le dossier dans
  `Contents/Resources/Localisation` ; sans bundle (tests, `swift run`), `L10n.dossier` retombe
  sur le dépôt via `#filePath`.
- Table chargée une fois (`static let`, sûr quel que soit le fil) : changer de langue = relancer.
- Langue : `Locale.preferredLanguages` (`Langue.choisir`, pur, testé : première reconnue,
  français à défaut), qui suit le choix par app de Réglages Système grâce à
  `CFBundleLocalizations` (Info.plist de `build.sh`). Le réglage « Langue » de l'onglet Général
  écrit `AppleLanguages` dans le domaine de l'app (`LangueReglage`) et propose de relancer.
- Les noms de classe viennent de DofusDB (table intégrée hors ligne), pas des tables : voir
  skill `marque-assets`.

## Tests

`LocalisationTests` : mêmes clés et mêmes spécificateurs dans les trois tables, et chaque clé
du code existe dans `fr.json` **et réciproquement** — une clé morte casse la suite. Un test qui
touche un libellé compare à `L("clé")`, jamais à un mot.
