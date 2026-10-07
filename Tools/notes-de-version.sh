#!/bin/bash
# notes-de-version.sh X.Y.Z — la section « ## X.Y.Z » de CHANGELOG.md, sans son
# titre ; échoue si elle manque ou est vide, pour ne jamais publier sans notes.
set -euo pipefail
VERSION="${1:?usage : notes-de-version.sh X.Y.Z}"
cd "$(dirname "$0")/.."
NOTES="$(awk -v v="$VERSION" '
    /^## / { dedans = ($2 == v); next }
    dedans { print }
' CHANGELOG.md | sed -e '/./,$!d')"
[ -n "$(printf '%s' "$NOTES" | tr -d '[:space:]')" ] \
    || { echo "notes-de-version.sh : aucune section « ## $VERSION » dans CHANGELOG.md" >&2; exit 1; }
printf '%s\n' "$NOTES"
