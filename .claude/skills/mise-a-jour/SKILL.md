---
name: mise-a-jour
description: Mise à jour de Synfus depuis les releases GitHub — vérification quotidienne, proposition, téléchargement contrôlé, canal Stable/Bêta, remplacement atomique et relance, autorisations TCC effacées (releases ad hoc), message après mise à jour, essai local par --simuler-version ; et le rafraîchissement quotidien des données DofusDB. Charger avant de toucher MiseAJour/, App/DonneesDuJeu.swift, Tools/publier-release.sh ou le format des assets d'une release.
user-invocable: false
---

# Mise à jour — `Sources/Synfus/MiseAJour/`

## Comportement

Le déroulé est celui de `SynseriaKit` ▸ `MiseAJour` (skill globale `synseriakit`), au geste
(`.auGeste`) ; `ReleasesDeSynfus` en est la part propre à Synfus.

- **Vérification** au lancement puis toutes les 24 h tant que `verifierMisesAJour` (Réglages ›
  Général, allumé par défaut) : `GET api.github.com/repos/Synseria/Synfus/releases?per_page=30`
  (brouillons écartés par l'API). **Canal** (`canalDeMiseAJour`, Stable par défaut) : Stable prend
  la plus haute release finale, Bêta la plus haute de toutes, `-rc.N` comprises
  (`ReleasePubliee.plusHaute`) ; changer de canal relance la recherche ; jamais de retour en
  arrière. La release choisie sans le DMG de ce Mac ou sans `SHA256SUMS.txt` ne se propose pas
  (rien ne se dit : `repos`, comme avant). Un binaire nu (sans `CFBundleShortVersionString`) ne vérifie rien. GitHub muet →
  `echec(.reseau, nil)`, « Réessayer ».
- **Proposition, jamais d'installation seule** : « Installer Synfus X.Y.Z… » en tête du menu et
  bouton sur la ligne Version, puis une `NSAlert` au premier plan (Installer et relancer · Annuler ·
  Nouveautés, qui ouvre la page et laisse l'alerte en place). Une notification système annonce une version une seule fois (`derniereVersionNotifiee`) ; au premier lancement après une mise à jour, le menu offre « Nouveautés de la X.Y.Z » sous À propos.
- **macOS minimum** : le nom du DMG le porte (`Synfus-X.Y.Z-macos26-arm64.dmg`, `MACOS_MINIMUM`
  de build.sh, lu dans `platforms` de Package.swift, seule source). Une release plus récente qui exige
  un macOS que ce Mac n'a pas passe à l'état `incompatible` : « Synfus X nécessite macOS N », ni
  bouton, ni notification, ni entrée de menu. Second filet après extraction (kit) :
  `LSMinimumSystemVersion` de l'app comparé au système (`.systeme` → `incompatible`).
  Une release sans minimum dans le nom n'est pas lue.
- **Installation** (kit, sur le geste) : DMG `Synfus-X.Y.Z-macos<N>-<arch>.dmg` téléchargé (arch
  du binaire qui tourne : sous Rosetta, x86_64), empreinte comparée à `SHA256SUMS.txt` de la même
  release, `hdiutil attach -nobrowse -readonly`, app copiée par `ditto`, puis contrôlée : même
  `CFBundleIdentifier`, `CFBundleShortVersionString` = numéro du tag, signature intacte (code
  imbriqué compris). Téléchargée par `URLSession`, l'app n'a **pas** de quarantaine.
- **Remplacement** (kit) : l'app prête recontrôlée (entière, signature), `replaceItemAt`, atomique, en place pendant que Synfus tourne (l'ancienne
  reste entière si l'échange échoue), puis `tccutil reset Accessibility|ScreenCapture
  fr.synseria.Synfus`, puis relance (un shell attend la fin du processus avant `open`). Paquet qui
  n'est pas un `.app`, dossier parent ou bundle non inscriptible (app traduite, volume en lecture
  seule) → `echec(.ecriture)` et bouton « Télécharger » vers la page de la release.
- **Pourquoi effacer les autorisations** : les releases sont signées **ad hoc** (pas de Developer
  ID). TCC lie alors l'autorisation à l'empreinte du binaire : l'entrée de l'ancienne version
  resterait cochée sans effet. Effacée, macOS la redemande proprement.
- **Après une mise à jour** (`VersionInstallee.apresMiseAJour`, kit) : `derniereVersionLancee` différente
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

`Tools/publier-release.sh` produit exactement ce que `ReleasesDeSynfus.lire` exige : tag `vX.Y.Z`,
assets `Synfus-X.Y.Z-macos<N>-arm64.dmg`, `Synfus-X.Y.Z-macos<N>-x86_64.dmg`, `SHA256SUMS.txt`
(format `shasum`), l'app à la racine du DMG sous le nom `Synfus.app`. Changer un nom ou le format
casse la mise à jour de **toutes** les versions déjà installées : jamais sans garder l'ancien en
parallèle — sauf pour écarter à dessein des versions qui ne doivent plus rien proposer (ci-dessous).
Une `X.Y.Z-rc.N` part en **pre-release** (`--prerelease`) : seul le canal Bêta la propose ; les
versions d'avant le canal (qui lisent `releases/latest`) ne la voient jamais.

## Passage à macOS 26 (0.14 → 0.15) — le piège des versions sans garde

Jusqu'à la 0.14.0 (cible macOS 14), la mise à jour ne vérifie pas le macOS : elle lit
`releases/latest`, cherche `Synfus-X.Y.Z-<arch>.dmg` et l'installe. Sous macOS 14/15, une release
macOS 26 publiée sous ce nom serait proposée, téléchargée, contrôlée (le contrôle ne lit pas
`LSMinimumSystemVersion`) puis posée : le script de remplacement efface l'ancienne app
(`rm -rf` du dossier de travail, qui la contient), efface les autorisations (`tccutil`), et
`open` échoue — l'utilisateur n'a plus de Synfus qui s'ouvre et doit retélécharger une 0.14 à la main.

**Parade en place** : depuis la 0.15, le DMG porte le minimum dans son nom. Une 0.14.0 (ou plus
ancienne) ne trouve plus son asset, `lire` rend `nil` : état `inconnu`, rien de proposé, sur
**tout** macOS. Coût : une 0.14.0 sous macOS 26 ne se met plus à jour d'elle-même.

**Parade complète (à décider)** : publier, **avant** la 0.15, une **0.14.1 pont** tirée du tag
`v0.14.0` (cible macOS 14 gardée, assets à l'**ancien** nom pour que toutes les versions la voient),
qui embarque la lecture du nouveau nom et ce garde. Sous macOS 26 elle propose la 0.15 ; sous
14/15 elle dit « nécessite macOS 26 ». Une 0.14.0 qui ne se lance pas entre la 0.14.1 et la 0.15
reste sur place, sans danger. Un pont seul, sans le changement de nom, ne suffit pas : une 0.14.0
qui ne l'a pas pris avant la 0.15 installerait directement la 0.15.

## Statistiques d'utilisation

Une release envoie les statistiques (`Usage/UsageStore`, sur `SynseriaKit.Telemetrie` : skill globale `synseriakit`) : `publier-release.sh` lit l'adresse du
collecteur et le jeton de Synfus dans le coffre (`secret run`, `domus:telemetrie/prod/URL` et
`…/SYNFUS`, Touch ID) ou dans l'environnement (`TELEMETRIE_URL`, `TELEMETRIE_JETON` : secrets de la
CI), et refuse de construire sans eux. `sh run.sh --install` les lit aussi dans le coffre (sans
`secret` ou coffre fermé : installée sans envoi) ; le build Debug n'en a pas, il compte sans
envoyer. `build.sh` les inscrit dans l'Info.plist (`SynseriaTelemetrieURL`, `SynseriaTelemetrieJeton`, XML échappé) avec `SynseriaDistribution` (`release` si
`DISTRIBUTION=1`, sinon `local`), rapporté en `deployment.environment` : sans cette clé, rien ne part.
Les plantages et blocages (MetricKit, dans le paquet) partent un par envoi ; chaque
release publie aussi `Synfus-X.Y.Z-dSYM.zip` (asset ignoré par la mise à jour), dont
`Tools/symboliser.sh <diagnostic.json>` tire les noms de fonctions. Contrat d'envoi et
collecteur : `docs/` de Flux-Domus. Un compteur ajouté à `EvenementUsage` est
gardé par le collecteur tant qu'il suit `usage.[a-z0-9_]+` (de même `reglage.*`).

## Données du jeu — `App/DonneesDuJeu.swift`

Carte, cartes intérieures, quêtes et classes : lues au lancement par leurs stores, puis
`DonneesDuJeu` les revoit chaque jour ; chacune ne se retélécharge que passée
`DofusDB.peremption` (30 jours). Indices de chasse et fiches « Où trouver » : à la demande,
30 jours ; almanax : les sept jours d'une semaine, à l'entrée de sa vue. Une nouvelle source DofusDB gardée sur disque s'ajoute à
`DonneesDuJeu.rafraichir`.
