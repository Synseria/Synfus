# Synfus

**Gestionnaire de multi-comptes Dofus pour macOS.** Gratuit, open source, dans
la barre de menus.

Quatre clients Dofus, c'est quatre fenêtres avec **la même icône** dans le
Dock, et ⌘-Tab pour deviner laquelle est laquelle. En combat, avec le chrono,
on clique une fois sur deux sur le mauvais perso — et quand c'est le tour d'un
autre, rien ne le dit. Sur Windows, des outils règlent ça depuis toujours ; sur
Mac, il n'y avait rien. Synfus est celui que je me suis fait.

![La barre flottante au-dessus du jeu](docs/screenshots/barre.png)

## Ce que ça fait

- **Une barre flottante** qui liste les persos connectés, avec leur classe —
  un clic et on est dessus. Le nom et la classe sont lus dans le **titre de la
  fenêtre**, pas dans l'icône du Dock. Les clients restés à l'écran de
  connexion ne sont pas listés.
- **⌘@ pour passer au suivant** sans lâcher la souris, ⇧⌘@ pour le précédent,
  ⌘1…⌘0 pour aller droit à un perso. Tout est modifiable, et « @ » n'est que
  la touche sous Échap d'un clavier Mac français.
- **Quand un perso réclame la main**, sa pastille clignote — ou Synfus bascule
  dessus tout seul, au choix. Détecté au rebond de l'icône dans le Dock, le
  seul signal qu'une app peut émettre vers l'extérieur.
- **Un mode « enchaîner »** : un clic sur un perso, il passe au suivant, un
  clic, il passe au suivant… pour faire la même action sur toute la team.
  **Il faut toujours un clic par perso** — voir la ligne rouge ci-dessous.
- **Les clients qui gèlent en quittant** sont fermés proprement, fini le
  « Forcer à quitter » à chaque session.
- **Le rangement des fenêtres** : côte à côte, mosaïque, un grand + vignettes,
  tout en plein écran, « lancer la session » le matin.
- **Un aperçu** de la fenêtre au survol d'un perso, et tous les persos d'un
  coup en maintenant ⌥⌘@.
- **Les icônes de classe** sont à fournir soi-même (*Réglages → Classes*, ou
  `~/Library/Application Support/Synfus/Classes/<clé>.png`) : Synfus
  n'embarque aucune image du jeu. `./Tools/fetch-ankama-assets.sh` télécharge
  les emblèmes sur ta machine, pour ton usage personnel.

  > Certaines illustrations sont la propriété d'Ankama Studio et de Dofus
  > — Tous droits réservés.

![Les réglages](docs/screenshots/reglages.png)

## La ligne rouge

Synfus **ne joue rien à ta place**. Il n'envoie aucun clic, aucune touche, ne
rejoue et ne duplique rien — dupliquer une action sur plusieurs clients est
précisément ce que les conditions d'utilisation de Dofus interdisent. Il lit le
titre des fenêtres, regarde le Dock, et change la fenêtre qui est devant, c'est
tout. Un clic reste un clic. L'observation de la souris (mode « enchaîner ») est
passive ; le clavier reste hors de vue.

Pas de lecture mémoire, pas de réseau. Deux autorisations macOS :
**Accessibilité**, et **Enregistrement de l'écran** seulement si tu veux les
aperçus.

## Stream Deck (optionnel)

Avec un Stream Deck Elgato, Synfus peut montrer les sorts du perso devant sous
les doigts et frapper la touche que le jeu attend — trois niveaux d'appui, les
trois barres sous dix touches, la sélection visible dans le jeu pendant qu'on
tient. Désactivé par défaut ; *Réglages → Stream Deck* installe le plugin et
fait apparaître l'onglet *Sorts*. Même règle : c'est le plugin qui frappe, une
pression = une frappe, et la liaison est un socket local réservé à ton compte.

## Installation

Récupérer le DMG correspondant à ta machine dans la page
[Releases](../../releases) :

| Mac | Fichier |
| --- | --- |
| Apple Silicon (M1 → M4) | `Synfus-<version>-arm64.dmg` |
| Intel | `Synfus-<version>-x86_64.dmg` |

Monter l'image, glisser **Synfus** dans **Applications**, puis lever la
quarantaine :

```sh
xattr -dr com.apple.quarantine /Applications/Synfus.app
```

Cette étape n'est pas facultative, et l'oublier ne se voit pas : l'app **se lance
normalement**, mais l'autorisation Accessibilité n'a alors aucun effet — la case
se coche dans les Réglages et Synfus continue de se dire non autorisé. L'attribut
suit l'app quand on la copie depuis le DMG : le retirer du DMG ne suffit pas.

Si l'app a déjà été lancée avant cette commande, l'entrée enregistrée ne
redeviendra pas valide ; il faut la réinitialiser :

```sh
tccutil reset Accessibility fr.synseria.Synfus
```

Tout cela tient à ce que les binaires publiés sont signés **ad-hoc** faute de
certificat *Developer ID* : macOS n'a aucune identité stable à leur associer et
se rabat sur l'empreinte du binaire, ce qui impose aussi de **réautoriser à
chaque nouvelle version**. Compiler depuis les sources l'évite entièrement.

Au premier lancement, autoriser Synfus dans **Réglages Système → Confidentialité
et sécurité → Accessibilité** : l'API d'accessibilité est ce qui permet de lire
les fenêtres des clients et de leur donner le focus.

Les aperçus de fenêtres, eux, réclament en plus **Enregistrement de l'écran** —
c'est la seule façon de capturer une image de fenêtre sur macOS. Ils sont
désactivés par défaut, et rien n'est capturé tant qu'ils le restent.

Compatible **macOS 14 (Sonoma) à macOS 26**. L'effet Liquid Glass de la barre
n'apparaît que sur macOS 26 ; en deçà, la barre utilise un matériau translucide.

## Compiler depuis les sources

```sh
./build.sh            # produit dist/Synfus.app
./build.sh --install  # installe dans /Applications et relance
swift test            # suite de tests
```

Deux variables d'environnement pilotent le script :

| Variable | Effet |
| --- | --- |
| `VERSION` | Numéro inscrit dans l'`Info.plist` (défaut : dernier tag du dépôt) |
| `ARCH` | Architecture cible, `arm64` ou `x86_64` (défaut : celle de la machine) |

`build.sh` signe avec le certificat local « Synfus Dev » s'il existe —
`./Tools/make-signing-identity.sh` le crée une fois — ou, à défaut, un
certificat *Apple Development* : l'identité vue par TCC reste alors stable d'un
build à l'autre, et l'autorisation Accessibilité n'est pas à redonner à chaque
fois. Le plugin Stream Deck est construit et embarqué dans l'app, mais jamais
installé par le script : c'est Synfus qui le propose.

Le DMG se fabrique à part :

```sh
./make-dmg.sh dist/Synfus.app dist/Synfus-0.0.1-arm64.dmg
```

Les tests se lancent avec `swift test`. Ils portent sur la logique pure —
analyse des titres de fenêtres, classes, raccourcis, persistance — et ne
touchent pas aux réglages de la machine.

L'icône est **dessinée par le code** plutôt que stockée comme image : la marque
est décrite une seule fois dans `Sources/Synfus/Marque/SynfusMark.swift`, d'où
sont tirés l'icône du bundle et le symbole de la barre de menus. Après toute retouche :

```sh
./Tools/generate-app-icons.sh   # régénère Resources/Synfus.{icns,png}
```

**La compilation exige le SDK macOS 26** (Xcode 26) : `BarView` appelle
`glassEffect`, absent des SDK antérieurs. Le deployment target reste 14.0, donc
le binaire produit couvre bien macOS 14 et suivants.

## Licence

Code sous licence [MIT](LICENSE). Les visuels du jeu ne font pas partie du
dépôt et n'en feront jamais partie : ils sont la propriété d'Ankama Studio et
de Dofus — Tous droits réservés —, et ne sont téléchargés que par l'utilisateur,
pour son usage personnel (voir *Icône par classe*). Synfus n'est ni affilié à
ni approuvé par Ankama.

## Publier une release

```sh
git tag v0.0.2
git push origin v0.0.2
```

Le workflow [`release.yml`](.github/workflows/release.yml) compile les deux
architectures sur un runner `macos-26`, fabrique les DMG et crée la release
GitHub avec les fichiers en pièces jointes.
