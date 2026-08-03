# Synfus

Gestionnaire de multi-comptes Dofus pour macOS. L'app vit dans la barre de menus
et fait basculer d'un perso à l'autre sans passer par ⌘-Tab.

## Ce que ça fait

- **Barre flottante** listant les persos connectés, chacun avec la couleur de sa
  classe — lue dans le titre de la fenêtre, pas dans l'icône du Dock (tous les
  clients partagent le même bundle `Dofus.app`, donc la même icône). Les clients
  restés à l'écran de connexion ne sont pas listés : ils décaleraient la
  numérotation des vrais persos.
- **Icône par classe**, à fournir soi-même : section *Classes* des réglages, par
  glisser-déposer ou en remplissant `~/Library/Application Support/Synfus/Classes`
  (`iop.png`, `cra.png`…). Synfus n'embarque aucune image du jeu — celles
  d'Ankama n'ont pas à être redistribuées. Sans image, la pastille colorée reste.
  Pour aller vite, `./Tools/fetch-class-icons.sh` remplit ce dossier avec les
  emblèmes des 19 classes : le dépôt ne transporte que des adresses, c'est ta
  machine qui télécharge, pour ton usage personnel.

  > Certaines illustrations sont la propriété d'Ankama Studio et de Dofus
  > — Tous droits réservés.
- **Raccourcis clavier globaux** : un par emplacement, plus deux pour cycler dans
  l'ordre choisi.
- **Détection d'attention** : quand un perso réclame la main, Synfus peut le
  signaler dans la barre ou basculer dessus automatiquement.
- **Ordre des persos** réglable, mémorisé d'une session à l'autre.

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
./build.sh            # produit ./Synfus.app
./build.sh --install  # installe dans /Applications et relance
swift test            # suite de tests
```

Deux variables d'environnement pilotent le script :

| Variable | Effet |
| --- | --- |
| `VERSION` | Numéro inscrit dans l'`Info.plist` (défaut `0.0.1`) |
| `ARCH` | Architecture cible, `arm64` ou `x86_64` (défaut : celle de la machine) |

Si un certificat *Apple Development* est présent dans le trousseau, `build.sh`
s'en sert : l'identité vue par TCC reste alors stable d'un build à l'autre, et
l'autorisation Accessibilité n'est pas à redonner à chaque fois.

Le DMG se fabrique à part :

```sh
./make-dmg.sh Synfus.app dist/Synfus-0.0.1-arm64.dmg
```

Les tests se lancent avec `swift test`. Ils portent sur la logique pure —
analyse des titres de fenêtres, classes, raccourcis, persistance — et ne
touchent pas aux réglages de la machine.

L'icône est **dessinée par le code** plutôt que stockée comme image : la marque
est décrite une seule fois dans `Sources/Synfus/SynfusMark.swift`, d'où sont
tirés l'icône du bundle, le symbole de la barre de menus et la poignée de la
barre flottante. Après toute retouche :

```sh
./Tools/generate-app-icons.sh   # régénère Resources/Synfus.{icns,png}
```

**La compilation exige le SDK macOS 26** (Xcode 26) : `BarView` appelle
`glassEffect`, absent des SDK antérieurs. Le deployment target reste 14.0, donc
le binaire produit couvre bien macOS 14 et suivants.

## Publier une release

```sh
git tag v0.0.2
git push origin v0.0.2
```

Le workflow [`release.yml`](.github/workflows/release.yml) compile les deux
architectures sur un runner `macos-26`, fabrique les DMG et crée la release
GitHub avec les fichiers en pièces jointes.
