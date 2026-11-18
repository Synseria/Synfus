#!/bin/bash
# publier-release.sh X.Y.Z — construit les DMG arm64 et x86_64 à distribuer
# (signés ad hoc, sans aucun visuel du jeu), compose les notes et crée — ou
# met à jour — la release GitHub vX.Y.Z. Le tag doit déjà être poussé.
# Lancé par `sh build.sh --publish X.Y.Z` ; release.yml le rejoue à la main.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage : publier-release.sh X.Y.Z}"
TAG="v$VERSION"

# Les deux tranches avec le même SDK ; x86_64 par cross-compilation.
construire() {
    for arch in arm64 x86_64; do
        DISTRIBUTION=1 ARCH="$arch" bash build.sh --release "$VERSION"
        rm -rf dist/Synfus.app
    done
}
# Une release envoie ses statistiques d'utilisation : adresse du collecteur et
# jeton de Synfus viennent de l'environnement (secrets de la CI), sinon du
# coffre (`secret run`, Touch ID). Jamais une release qui compterait pour rien.
if [ -n "${TELEMETRIE_URL:-}" ] && [ -n "${TELEMETRIE_JETON:-}" ]; then
    construire
elif command -v secret >/dev/null; then
    export VERSION
    export -f construire
    secret run TELEMETRIE_URL=domus:telemetrie/prod/URL TELEMETRIE_JETON=domus:telemetrie/prod/SYNFUS \
        -- bash -euo pipefail -c construire
else
    echo "publier-release.sh : ni TELEMETRIE_URL et TELEMETRIE_JETON, ni la commande secret" >&2
    exit 1
fi
# Le nom des DMG porte le macOS minimum (`MACOS_MINIMUM` de build.sh), que la mise à jour lit avant
# de proposer la version : on le reprend tel que build.sh l'a écrit.
dmg() {
    local trouves=(dist/Synfus-"$VERSION"-macos*-"$1".dmg)
    [ ${#trouves[@]} -eq 1 ] && [ -f "${trouves[0]}" ] || { echo "publier-release.sh : DMG $1 introuvable ou en double" >&2; exit 1; }
    basename "${trouves[0]}"
}
DMG_ARM="$(dmg arm64)"; DMG_INTEL="$(dmg x86_64)"
MINIMUM="${DMG_ARM#Synfus-"$VERSION"-macos}"; MINIMUM="${MINIMUM%-arm64.dmg}"
( cd dist && shasum -a 256 "$DMG_ARM" "$DMG_INTEL" ) | tee dist/SHA256SUMS.txt
( cd dist && rm -f "Synfus-$VERSION-dSYM.zip" \
    && zip -qry "Synfus-$VERSION-dSYM.zip" "Synfus-$VERSION-arm64.dSYM" "Synfus-$VERSION-x86_64.dSYM" )

# Ce qui change vient de CHANGELOG.md, seule source ; le mode d'emploi qui
# suit est le même à chaque version.
NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
{ bash Tools/notes-de-version.sh "$VERSION"; echo; } > "$NOTES"
cat >> "$NOTES" <<'EOF'
### Téléchargement

| Mac | Fichier |
| --- | --- |
| Apple Silicon (M1 → M4) | `DMG_ARM` |
| Intel | `DMG_INTEL` |

Compatible macOS MINIMUM et suivants.

### Installation

**1.** Monter le DMG et glisser **Synfus** dans **Applications**.

**2.** Lever la quarantaine — **avant** de lancer l'app :

```sh
xattr -dr com.apple.quarantine /Applications/Synfus.app
```

⚠️ Cette étape n'est pas facultative, et son oubli ne se voit pas :
l'app **se lance normalement**, mais l'autorisation Accessibilité
n'a alors aucun effet — la case se coche dans les Réglages et Synfus
continue de dire qu'il n'est pas autorisé. Copier l'app depuis le DMG
emmène l'attribut avec elle : le retirer du DMG ne suffit pas.

**3.** Lancer Synfus, puis l'autoriser dans **Réglages Système →
Confidentialité et sécurité → Accessibilité**.

Si l'app a déjà été lancée avant l'étape 2, réinitialiser l'autorisation
après avoir levé la quarantaine :

```sh
tccutil reset Accessibility fr.synseria.Synfus
```

### Pourquoi ces manipulations

Les binaires publiés ici sont signés **ad-hoc** et non notarisés : le
projet n'a pas de certificat *Developer ID* (compte Apple Developer
payant). macOS n'a donc aucune identité stable à associer à l'app, et
se rabat sur l'empreinte du binaire. Conséquence : **chaque nouvelle
version doit être réautorisée** — retirer l'ancienne entrée dans la
liste Accessibilité, puis rajouter la nouvelle.

Compiler depuis les sources (`sh run.sh --install --start`) évite tout cela.

Une fois Synfus installé, les versions suivantes se proposent d'elles-mêmes
(menu de Synfus → « Installer Synfus X.Y.Z… ») : téléchargement, contrôle,
remplacement et relance, sans quarantaine ; seules les autorisations sont à
redonner.
EOF
sed -i '' -e "s/DMG_ARM/$DMG_ARM/g" -e "s/DMG_INTEL/$DMG_INTEL/g" -e "s/MINIMUM/$MINIMUM/g" \
    -e "s/VERSION/$VERSION/g" "$NOTES"

FICHIERS=(dist/"$DMG_ARM" dist/"$DMG_INTEL" dist/SHA256SUMS.txt
          dist/Synfus-"$VERSION"-dSYM.zip)
# La release peut déjà exister (ouverte depuis GitHub, publication rejouée) :
# on la met alors à jour, fichiers homonymes écrasés.
if gh release view "$TAG" >/dev/null 2>&1; then
    gh release edit "$TAG" --title "Synfus $VERSION" --notes-file "$NOTES"
    gh release upload "$TAG" "${FICHIERS[@]}" --clobber
else
    gh release create "$TAG" --title "Synfus $VERSION" --notes-file "$NOTES" "${FICHIERS[@]}"
fi
echo "==> https://github.com/Synseria/Synfus/releases/tag/$TAG"
