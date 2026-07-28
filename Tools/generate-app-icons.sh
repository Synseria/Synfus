#!/bin/bash
# Régénère Resources/Synfus.icns et Resources/Synfus.png — l'icône gravée dans le
# bundle, celle que montrent le Finder et le Dock.
#
#   ./Tools/generate-app-icons.sh
#
# Le générateur compile la source RÉELLE du dessin (Sources/Synfus/SynfusMark.swift),
# celle-là même dont l'app tire son symbole de barre de menus : un seul dessin,
# aucune duplication. À relancer après toute modification de la marque.
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="$(mktemp -d)"
ICONSET="$BUILD_DIR/Synfus.iconset"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "▸ Compilation du générateur…"
swiftc -O -swift-version 6 \
    Sources/Synfus/SynfusMark.swift \
    Tools/AppIconExport.swift \
    -o "$BUILD_DIR/AppIconExport"

echo "▸ Rendu des définitions…"
"$BUILD_DIR/AppIconExport" "$ICONSET" Resources/Synfus.png

echo "▸ Assemblage du .icns…"
iconutil -c icns "$ICONSET" -o Resources/Synfus.icns

echo "✓ Resources/Synfus.icns et Resources/Synfus.png à jour."
