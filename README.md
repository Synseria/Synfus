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
  Pour aller vite, `./Tools/fetch-ankama-assets.sh` remplit ce dossier avec les
  emblèmes des 19 classes : le dépôt ne transporte que des adresses, c'est ta
  machine qui télécharge, pour ton usage personnel.

  > Certaines illustrations sont la propriété d'Ankama Studio et de Dofus
  > — Tous droits réservés.
- **Raccourcis clavier globaux**, tous modifiables dans les réglages. Par défaut,
  la navigation tient sur la touche sous Échap — « @ » sur un clavier Mac
  français —, atteignable de la main gauche sans lâcher la souris :

  | Raccourci | Effet |
  | --- | --- |
  | ⌘@ | perso suivant |
  | ⇧⌘@ | perso précédent |
  | ⌥⌘@ | aperçu de tous les persos, tant que c'est maintenu |
  | ⌃⌘@ | activer / désactiver le passage automatique |
  | ⌘1 … ⌘5 | aller droit à un perso (jusqu'à ⌘0 pour le dixième) |

  Afficher / masquer la barre n'a **pas** de raccourci par défaut : une
  combinaison imposée est une combinaison prise au reste du système. À définir
  soi-même dans les réglages si le besoin est là.
- **Détection d'attention** : quand un perso réclame la main, Synfus peut le
  signaler dans la barre ou basculer dessus automatiquement.
- **Mode « enchaîner »**, désactivé par défaut : une fois activé — ⌘< ou la
  flèche verte de la barre —, chaque clic sur un client de jeu part normalement,
  puis Synfus bascule sur le perso suivant. Le mode reste actif jusqu'à ce qu'on
  le coupe, et la flèche est verte tant qu'il l'est.

  Le clic est **nu** : le jeu reçoit exactement ce qu'il attend. Un clic modifié
  lui parvient bien, mais avec le modificateur dessus, et il ne le traite pas
  comme un clic ordinaire — déplacer un perso passe, parler à un PNJ non.

  **Il faut toujours un clic par perso.** Synfus n'émet aucun évènement, n'en
  rejoue aucun et n'en duplique aucun — dupliquer une action sur plusieurs
  clients est précisément ce que les conditions d'utilisation de Dofus
  interdisent, et ce n'est pas ce que fait cette fonction. L'observation est
  passive et porte sur la souris seule ; le clavier reste hors de vue.

- **Ordre des persos** réglable, mémorisé d'une session à l'autre.
- **Fermeture des clients** qui gèlent en quittant : *Fermer* puis, s'il ne
  répond plus, coup de grâce — plus de « Forcer à quitter » à chaque session.
- **Rangement des fenêtres** : côte à côte, mosaïque, un grand + vignettes,
  empilés, tout en plein écran.

## Stream Deck (optionnel)

Avec un Stream Deck Elgato, Synfus peut montrer **les sorts du perso devant**
sous les doigts et frapper la touche que le jeu attend. Tout est désactivé par
défaut ; ça s'active dans *Réglages → Stream Deck*, qui installe le plugin (un
clic) et fait apparaître l'onglet *Sorts*.

- Les sorts de chaque perso sont **reconnus à l'écran** (une capture de la
  barre, comparée aux icônes de sa classe) ou choisis à la main ; un profil JSON
  par perso.
- Trois dispositions — barre par barre, une barre par rangée, personnalisée —,
  générique ou propre à un perso, composées par Synfus : rien à réimporter dans
  le logiciel Elgato quand on change quelque chose.
- Trois niveaux d'appui sur une touche de sort : court, long, très long — les
  trois barres du jeu sous dix touches, avec la **sélection visible dans le jeu
  pendant qu'on tient**. Pas de double-clic : deux appuis sont deux frappes.
- Menu des commandes du jeu (inventaire, carte, quêtes…), perso suivant, fin de
  tour, corps à corps ; détection de combat calibrée par deux captures.

La règle ne change pas : **Synfus n'émet aucun évènement**. C'est le plugin,
comme n'importe quel périphérique d'entrée, qui frappe une touche par appui —
rien n'est rejoué ni multiplié. La liaison entre les deux est un socket Unix
réservé à ton compte, jamais un port réseau.

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
