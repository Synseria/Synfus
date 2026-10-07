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
for arch in arm64 x86_64; do
    DISTRIBUTION=1 ARCH="$arch" bash build.sh --release "$VERSION"
    rm -rf dist/Synfus.app
done
( cd dist && shasum -a 256 "Synfus-$VERSION-arm64.dmg" "Synfus-$VERSION-x86_64.dmg" ) | tee dist/SHA256SUMS.txt

# Ce qui change vient de CHANGELOG.md, seule source ; le mode d'emploi qui
# suit est le même à chaque version.
NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
{ bash Tools/notes-de-version.sh "$VERSION"; echo; } > "$NOTES"
cat >> "$NOTES" <<'EOF'
### Téléchargement

| Mac | Fichier |
| --- | --- |
| Apple Silicon (M1 → M4) | `Synfus-VERSION-arm64.dmg` |
| Intel | `Synfus-VERSION-x86_64.dmg` |

Compatible macOS 14 (Sonoma) et suivants. L'effet Liquid Glass de la barre
n'apparaît que sur macOS 26 ; en deçà la barre utilise un matériau translucide.

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
EOF
sed -i '' "s/VERSION/$VERSION/g" "$NOTES"

FICHIERS=(dist/Synfus-"$VERSION"-arm64.dmg dist/Synfus-"$VERSION"-x86_64.dmg dist/SHA256SUMS.txt)
# La release peut déjà exister (ouverte depuis GitHub, publication rejouée) :
# on la met alors à jour, fichiers homonymes écrasés.
if gh release view "$TAG" >/dev/null 2>&1; then
    gh release edit "$TAG" --title "Synfus $VERSION" --notes-file "$NOTES"
    gh release upload "$TAG" "${FICHIERS[@]}" --clobber
else
    gh release create "$TAG" --title "Synfus $VERSION" --notes-file "$NOTES" "${FICHIERS[@]}"
fi
echo "==> https://github.com/Synseria/Synfus/releases/tag/$TAG"
