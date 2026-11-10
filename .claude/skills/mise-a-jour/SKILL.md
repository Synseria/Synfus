---
name: mise-a-jour
description: Mise à jour de Synfus depuis les releases GitHub — vérification quotidienne, proposition, téléchargement contrôlé, remplacement par un script détaché, autorisations TCC effacées (releases ad hoc), message après mise à jour, essai local par --simuler-version ; et le rafraîchissement quotidien des données DofusDB. Charger avant de toucher MiseAJour/, App/DonneesDuJeu.swift, Tools/publier-release.sh ou le format des assets d'une release.
user-invocable: false
---

# Mise à jour — `Sources/Synfus/MiseAJour/`

## Comportement

- **Vérification** au lancement puis toutes les 24 h tant que `verifierMisesAJour` (Réglages ›
  Général, allumé par défaut) : `GET api.github.com/repos/Synseria/Synfus/releases/latest`, qui
  écarte brouillons et préversions. Un binaire nu (sans `CFBundleShortVersionString`) ne vérifie
  rien. GitHub muet → état `inconnu`, rien d'affiché, on réessaie au tour suivant.
- **Proposition, jamais d'installation seule** : « Installer Synfus X.Y.Z… » en tête du menu et
  bouton sur la ligne Version, puis une `NSAlert` (Installer et relancer · Annuler · Nouveautés).
- **Installation** (`InstallateurMiseAJour`, acteur sans état) : DMG `Synfus-X.Y.Z-<arch>.dmg`
  téléchargé (arch du binaire qui tourne : sous Rosetta, x86_64), empreinte comparée à
  `SHA256SUMS.txt` de la même release, `hdiutil attach -nobrowse -readonly`, app copiée par
  `ditto`, puis contrôlée : même `CFBundleIdentifier`, `CFBundleShortVersionString` = numéro du
  tag, `codesign --verify --deep --strict`. Téléchargée par `URLSession`, l'app n'a **pas** de
  quarantaine.
- **Remplacement** : une app ne se remplace pas en marche. Un script `bash -c` détaché attend la
  fin du PID (une minute au plus, sinon abandon sans rien toucher), déplace l'ancienne dans le
  dossier de travail, copie la nouvelle (l'ancienne revient si la copie échoue), lance
  `tccutil reset Accessibility|ScreenCapture fr.synseria.Synfus`, puis `open`. Dossier parent ou
  bundle non inscriptible (app traduite, volume en lecture seule) → `echec(.ecriture)` et bouton
  « Télécharger » vers la page de la release.
- **Pourquoi effacer les autorisations** : les releases sont signées **ad hoc** (pas de Developer
  ID). TCC lie alors l'autorisation à l'empreinte du binaire : l'entrée de l'ancienne version
  resterait cochée sans effet. Effacée, macOS la redemande proprement.
- **Après une mise à jour** (`apresMiseAJour`, pur et testé) : `derniereVersionLancee` différente
  de la version qui tourne, ou absente d'une sauvegarde existante (version d'avant ce réglage) —
  jamais au premier lancement. Tant qu'une autorisation manque, l'onglet Général affiche
  « Mis à jour en X.Y.Z : autorisations à redonner » avec le pourquoi en ⓘ. Vaut aussi pour une
  mise à jour faite à la main par DMG.

## Essayer en local

`--simuler-version X.Y.Z` remplace la version comparée (pas celle inscrite ni celle de
`derniereVersionLancee`) et force une vérification, même recherche éteinte :

```sh
# Quitter Synfus d'abord (une seule instance), puis :
open -n -a /Applications/Synfus.app --args --simuler-version 0.0.1
```

La dernière release réelle est alors proposée : toute la chaîne se joue (téléchargement,
empreinte, montage, contrôle, remplacement, `tccutil`, relance). Après l'essai, `/Applications`
contient la release ad hoc : `sh run.sh --install` remet le build local, et ses autorisations
sont à redonner (elles ont été effacées). Le message « après mise à jour » de la version
installée ne s'y voit que si cette release le contient déjà.

## Publication — ce que l'app attend d'une release

`Tools/publier-release.sh` produit exactement ce que `VersionPubliee.lire` exige : tag `vX.Y.Z`,
assets `Synfus-X.Y.Z-arm64.dmg`, `Synfus-X.Y.Z-x86_64.dmg`, `SHA256SUMS.txt` (format `shasum`),
l'app à la racine du DMG sous le nom `Synfus.app`. Changer un nom ou le format casse la mise à
jour de **toutes** les versions déjà installées : jamais sans garder l'ancien en parallèle.

## Statistiques d'utilisation

Une release envoie les statistiques (`Usage/UsageStore`) : `publier-release.sh` lit l'adresse du
collecteur et le jeton de Synfus dans le coffre (`secret run`, `domus:telemetrie/prod/URL` et
`…/SYNFUS`, Touch ID) ou dans l'environnement (`TELEMETRIE_URL`, `TELEMETRIE_JETON` : secrets de la
CI), et refuse de construire sans eux ; `build.sh` les inscrit dans l'Info.plist. Un build local
n'en a pas : il compte sans envoyer. Pour l'essayer de bout en bout :
`secret run TELEMETRIE_URL=domus:telemetrie/prod/URL TELEMETRIE_JETON=domus:telemetrie/prod/SYNFUS -- sh run.sh --install --start`.
Les plantages et blocages (MetricKit, `Usage/DiagnosticsUsage`) partent un par envoi ; chaque
release publie aussi `Synfus-X.Y.Z-dSYM.zip` (asset ignoré par la mise à jour), dont
`Tools/symboliser.sh <diagnostic.json>` tire les noms de fonctions. Contrat d'envoi et
collecteur : `docs/` de Flux-Domus. Un compteur ajouté à `EvenementUsage` est
gardé par le collecteur tant qu'il suit `usage.[a-z0-9_]+` (de même `reglage.*`).

## Données du jeu — `App/DonneesDuJeu.swift`

Carte, cartes intérieures, quêtes et classes : lues au lancement par leurs stores, puis
`DonneesDuJeu` les revoit chaque jour ; chacune ne se retélécharge que passée
`DofusDB.peremption` (30 jours). Indices de chasse et fiches « Où trouver » : à la demande,
30 jours ; almanax : le jour. Une nouvelle source DofusDB gardée sur disque s'ajoute à
`DonneesDuJeu.rafraichir`.
