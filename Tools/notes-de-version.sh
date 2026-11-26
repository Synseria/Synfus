#!/bin/bash
# notes-de-version.sh X.Y.Z[-rc.N] — la section « ## X.Y.Z » de CHANGELOG.md
# (ou « ## X.Y.Z-rc.N » si elle existe), sans son titre : les rc d'une version
# partagent ses notes. Échoue si elle manque ou est vide, pour ne jamais publier
# sans notes.
set -euo pipefail
VERSION="${1:?usage : notes-de-version.sh X.Y.Z[-rc.N]}"
cd "$(dirname "$0")/.."
section() { awk -v v="$1" '
    /^## / { dedans = ($2 == v); next }
    dedans { print }
' CHANGELOG.md | sed -e '/./,$!d'; }
NOTES="$(section "$VERSION")"
[ -n "$(printf '%s' "$NOTES" | tr -d '[:space:]')" ] || NOTES="$(section "${VERSION%%-rc.*}")"
[ -n "$(printf '%s' "$NOTES" | tr -d '[:space:]')" ] \
    || { echo "notes-de-version.sh : aucune section « ## $VERSION » dans CHANGELOG.md" >&2; exit 1; }
printf '%s\n' "$NOTES"
