# Synfus

Gestionnaire de multi-comptes Dofus pour macOS. L'app vit dans la barre de menus
et fait basculer d'un perso à l'autre sans passer par ⌘-Tab.

## Ce que ça fait

- **Barre flottante** listant les persos connectés, chacun avec la couleur de sa
  classe — lue dans le titre de la fenêtre, pas dans l'icône du Dock (tous les
  clients partagent le même bundle `Dofus.app`, donc la même icône).
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

Cette étape est nécessaire tant que l'app n'est pas notarisée : les builds de CI
sont signés ad-hoc, et macOS refuse de les ouvrir sans ça.

Au premier lancement, autoriser Synfus dans **Réglages Système → Confidentialité
et sécurité → Accessibilité** : l'API d'accessibilité est ce qui permet de lire
les fenêtres des clients et de leur donner le focus.

Compatible **macOS 14 (Sonoma) à macOS 26**. L'effet Liquid Glass de la barre
n'apparaît que sur macOS 26 ; en deçà, la barre utilise un matériau translucide.

## Compiler depuis les sources

```sh
./build.sh            # produit ./Synfus.app
./build.sh --install  # installe dans /Applications et relance
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
