#!/bin/bash
# Fabrique Synfus.streamDeckProfile — le profil livré avec le plugin, vers
# lequel SynfusDeck bascule quand Dofus passe devant. Disposition 5 × 3 :
#
#   ◀ perso │ perso actif │ perso ▶ │ corps à corps │ fin de tour
#   sort 1  │ sort 2      │ sort 3  │ sort 4        │ sort 5
#   sort 6  │ sort 7      │ sort 8  │ sort 9        │ sort 10
#
# Les cases 11 et 12 de chaque barre ne tiennent pas sur 15 touches : « perso
# actif » passe à la barre suivante. Un `.streamDeckProfile` est un zip d'un
# dossier `<uuid>.sdProfile/manifest.json` dont les actions sont indexées par
# « colonne,ligne ».
#
#   ./Plugin/make-profile.sh <dossier .sdPlugin>
set -euo pipefail
PLUGIN="${1:?usage: make-profile.sh <dossier .sdPlugin>}"
UUID="7F0D2C1A-5E4B-4C63-9A21-5D6E8F3A1B02"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DIR="$WORK/$UUID.sdProfile"
mkdir -p "$DIR"

action() { # colonne ligne uuid nom
    printf '"%s,%s":{"Name":"%s","UUID":"fr.synseria.synfus.%s","Settings":{},"State":0,"States":[{"Image":"","Title":"","TitleAlignment":"bottom","FontSize":"9","ShowTitle":true}]}' "$1" "$2" "$4" "$3"
}
{
    printf '{"Name":"Synfus","Version":"1.0","DeviceModel":"20GAA9901","DeviceUUID":"","Actions":{'
    action 0 0 perso-precedent "Perso précédent"; printf ','
    action 1 0 perso-actif "Perso actif"; printf ','
    action 2 0 perso-suivant "Perso suivant"; printf ','
    action 3 0 corps-a-corps "Corps à corps"; printf ','
    action 4 0 fin-de-tour "Fin de tour"
    for row in 1 2; do for col in 0 1 2 3 4; do printf ','; action "$col" "$row" sort "Sort"; done; done
    printf '}}'
} > "$DIR/manifest.json"
rm -f "$PLUGIN/Synfus.streamDeckProfile"
(cd "$WORK" && zip -qr "$OLDPWD/$PLUGIN/Synfus.streamDeckProfile" "$UUID.sdProfile")
