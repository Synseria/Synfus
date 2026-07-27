#!/bin/bash
# Emballe un bundle .app dans une image disque prête à distribuer.
#   ./make-dmg.sh Synfus.app dist/Synfus-0.0.1-arm64.dmg
#
# Le DMG contient l'app et un alias vers /Applications : l'utilisateur monte
# l'image et glisse l'une sur l'autre.
set -euo pipefail

APP="${1:?usage: make-dmg.sh <bundle.app> <sortie.dmg>}"
DMG="${2:?usage: make-dmg.sh <bundle.app> <sortie.dmg>}"
NAME="$(basename "$APP" .app)"

[ -d "$APP" ] || { echo "erreur : $APP introuvable" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# ditto plutôt que cp -R : préserve les métadonnées étendues, donc la signature.
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"

hdiutil create \
    -volname "$NAME" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

echo "==> $DMG"
