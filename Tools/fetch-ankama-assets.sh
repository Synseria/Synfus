#!/bin/bash
# Télécharge les emblèmes des classes et les icônes de sorts dans
# Resources/Ankama/ (ignoré par Git), pour ton usage personnel — voir l'en-tête
# de Tools/FetchAnkamaAssets.swift pour la règle (CGU Dofus, art. 13.2).
#
#   ./Tools/fetch-ankama-assets.sh [--force] [--liste] [--dest DIR]
#
# Compile le programme avec la source RÉELLE des classes
# (Sources/Synfus/Classes/DofusClass.swift) : les clés — donc les noms de
# fichiers — sont celles de l'app, sans table recopiée. Même pratique que
# generate-app-icons.sh. Le binaire est gardé dans .build/tools/ et n'est
# recompilé que si une source a changé : un pare-feu applicatif (LuLu…)
# identifie le programme par son chemin et ne redemande pas à chaque fois.
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCES=(Sources/Synfus/Classes/DofusClass.swift Tools/FetchAnkamaAssets.swift)
BINARY=.build/tools/FetchAnkamaAssets

needs_build=0
[ -x "$BINARY" ] || needs_build=1
for source in "${SOURCES[@]}"; do
    [ "$source" -nt "$BINARY" ] && needs_build=1
done

if [ "$needs_build" -eq 1 ]; then
    echo "▸ Compilation…"
    mkdir -p "$(dirname "$BINARY")"
    swiftc -O -swift-version 6 -parse-as-library "${SOURCES[@]}" -o "$BINARY"
fi

exec "$BINARY" "$@"
