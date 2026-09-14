#!/bin/bash
# Fabrique Synfus.streamDeckProfile — le profil livré avec le plugin, vers
# lequel SynfusDeck bascule quand Dofus passe devant. Les quinze touches
# portent la même action, « Touche Synfus » : c'est Synfus qui décide de ce
# que chacune montre et fait (onglet Stream Deck), sans rien réimporter.
# Un `.streamDeckProfile` est un zip d'un dossier `<uuid>.sdProfile/manifest.json`
# dont les actions sont indexées par « colonne,ligne ».
#
# Appelé par build.sh ; à la main, sans argument, il vise dist/ :
#   ./Plugin/make-profile.sh [dossier .sdPlugin]
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGIN="${1:-dist/fr.synseria.synfus.sdPlugin}"
[ -d "$PLUGIN" ] || { echo "Dossier introuvable : $PLUGIN — lance ./build.sh d'abord." >&2; exit 1; }
PLUGIN="$(cd "$PLUGIN" && pwd)"
UUID="7F0D2C1A-5E4B-4C63-9A21-5D6E8F3A1B02"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DIR="$WORK/$UUID.sdProfile"
mkdir -p "$DIR"

action() { # colonne ligne uuid nom
    printf '"%s,%s":{"Name":"%s","UUID":"fr.synseria.synfus.%s","Settings":{},"State":0,"States":[{"Image":"","Title":"","TitleAlignment":"bottom","FontSize":8,"ShowTitle":true}]}' "$1" "$2" "$4" "$3"
}
{
    printf '{"Name":"Synfus","Version":"1.0","DeviceModel":"20GAA9901","DeviceUUID":"","Actions":{'
    first=1
    for row in 0 1 2; do for col in 0 1 2 3 4; do
        [ $first = 1 ] && first=0 || printf ','
        action "$col" "$row" touche "Touche Synfus"
    done; done
    printf '}}'
} > "$DIR/manifest.json"
rm -f "$PLUGIN/Synfus.streamDeckProfile"
(cd "$WORK" && zip -qr "$PLUGIN/Synfus.streamDeckProfile" "$UUID.sdProfile")
echo "✓ $PLUGIN/Synfus.streamDeckProfile — double-clic pour l'importer dans le logiciel Stream Deck." 
