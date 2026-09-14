# Stream Deck — ce qu'il faut savoir pour outiller des profils (macbootstrap)

Résumé de ce que l'intégration Synfus a appris du logiciel Elgato (Stream
Deck 7.x, macOS), à réutiliser pour livrer des profils clef en main par
application.

## Les trois objets

| Objet | C'est quoi | Où ça vit |
| --- | --- | --- |
| `<id>.sdPlugin/` | Un plugin : `manifest.json` + un exécutable (n'importe lequel : Node, Swift, Python…) + icônes | `~/Library/Application Support/com.elgato.StreamDeck/Plugins/` |
| `<id>.streamDeckPlugin` | Le **zip** du dossier ci-dessus. Double-clic = installation par le logiciel, qui enregistre aussi les profils livrés dans le plugin | où on veut |
| `<nom>.streamDeckProfile` | Le **zip** d'un dossier `<uuid>.sdProfile/manifest.json` — un profil : les actions par touche | double-clic = import dans le logiciel |

Le logiciel n'installe **pas** un `.sdPlugin` par double-clic ; copier le
dossier dans `Plugins/` et relancer le logiciel marche pour développer, mais
n'enregistre pas les profils livrés.

## Le format d'un profil (ce que génère `Plugin/make-profile.sh`)

```json
{
  "Name": "Synfus", "Version": "1.0", "DeviceModel": "20GAA9901", "DeviceUUID": "",
  "Actions": {
    "0,0": { "Name": "Barre suivante", "UUID": "fr.synseria.synfus.barre-suivante",
             "Settings": {}, "State": 0,
             "States": [ { "Image": "", "Title": "", "TitleAlignment": "bottom", "FontSize": "9", "ShowTitle": true } ] },
    "1,0": { "...": "colonne,ligne — 0,0 en haut à gauche" }
  }
}
```

C'est l'ancien format (v5) ; le logiciel 7.x l'importe et le convertit
(« Convert profile to new version » dans son journal). `DeviceModel` peut
être celui d'un autre modèle : l'import réassocie à l'appareil branché.
Les actions natives d'Elgato ont leurs UUID : `com.elgato.streamdeck.system.hotkey`
(Settings : `{"hotkey": {...}}`), `com.elgato.streamdeck.system.website`
(`{"url": "..."}`), `com.elgato.streamdeck.system.open` (ouvrir une app,
`{"path": "/Applications/X.app"}`), `com.elgato.streamdeck.profile.rotate`,
`com.elgato.streamdeck.multiactions.multiaction`. Pour voir les `Settings`
exacts, faire l'action dans le logiciel puis lire
`~/Library/Application Support/com.elgato.StreamDeck/ProfilesV3/<uuid>.sdProfile/Profiles/<page>.sdProfile/manifest.json`.

## Basculer automatiquement par application

Deux mécanismes, indépendants :

1. **Natif, sans plugin** : dans le logiciel, un profil peut être *lié à une
   application* (réglages du profil → Application). Le logiciel bascule dessus
   quand l'app passe devant et revient au profil précédent après. C'est la
   réponse générique pour macbootstrap : un `.streamDeckProfile` par app,
   importé, puis lié — le lien se fait dans l'interface (il est enregistré dans
   `ProfilesV3/<uuid>.sdProfile/manifest.json` sous `AppIdentifier`, on peut donc
   l'écrire après import).
2. **Par un plugin** : `switchToProfile` ne vise que les profils **livrés avec
   le plugin** (`Profiles` du manifest, fichier à la racine du `.sdPlugin`,
   installé par le paquet). C'est ce que fait SynfusDeck quand Dofus passe
   devant — parce que « Dofus devant » est un état que Synfus connaît mieux
   que le logiciel (le client est un binaire Unity sans bundle stable).

## Ce que le paquet Synfus contient

```
fr.synseria.synfus.sdPlugin/
├── manifest.json            actions, Profiles: [{Name: "Synfus", DeviceType: 0}]
├── SynfusDeck               binaire Swift lancé par le logiciel (-port -pluginUUID -registerEvent -info)
├── Synfus.streamDeckProfile profil 5 × 3 livré (make-profile.sh)
└── icon*.png
```

`./build.sh` produit le dossier et le paquet dans `dist/` ; `./build.sh
--install` ouvre le paquet la première fois, puis met le dossier à jour et
relance le logiciel. Journal du logiciel :
`~/Library/Logs/ElgatoStreamDeck/StreamDeck.log` ; celui du plugin :
`~/Library/Logs/Synfus/synfusdeck.log`.

## Recette macbootstrap

1. Installer le logiciel (`brew install --cask elgato-stream-deck`), le lancer une fois.
2. Copier les paquets de plugins et `open` chacun (confirmation dans le logiciel).
3. Pour chaque app : générer le `.streamDeckProfile` (script sur le modèle de
   `make-profile.sh`), `open` le fichier, puis lier à l'app — à la main, ou en
   posant `AppIdentifier` (bundle id) dans le manifest importé et en relançant
   le logiciel.
4. Le profil « par défaut » est celui marqué `Default` dans les préférences du
   logiciel ; il se règle dans l'interface.
