#!/bin/bash
# build.sh — build Release signé de Synfus.
#   sh build.sh                    → dist/Synfus.app
#   sh build.sh --release [X.Y.Z]  → + dist/Synfus-X.Y.Z-<arch>.dmg
#   sh build.sh --publish X.Y.Z    → depuis main propre : main et tag vX.Y.Z
#                                    poussés, DMG construits ici et publiés
#   sh build.sh --help
# Installer et lancer, c'est `sh run.sh --install [--start]`.
#
# Trois variables d'environnement, pour la publication :
#   VERSION=0.0.1   numéro inscrit dans l'Info.plist (défaut : dernier tag git)
#   ARCH=x86_64     architecture cible (défaut : celle de la machine)
#   DISTRIBUTION=1  build à publier : signé ad hoc
[ -n "${BASH_VERSION:-}" ] || exec /bin/bash "$0" "$@"
case ":${SHELLOPTS:-}:" in *:posix:*) exec /bin/bash "$0" "$@" ;; esac
set -euo pipefail

cd "$(dirname "$0")"

# Où la release se construit : 1 → le tag poussé déclenche release.yml ;
# 0 → construite et publiée depuis ce Mac. 0 : le runner GitHub n'a pas
# encore Xcode 27, qu'exige la swift-tools-version du paquet.
PUBLICATION_PAR_CI=0

aide() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

MODE="app"; CONFIG="release"; DIST="dist"; VERSION_DEMANDEE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --release) MODE="release"; if [ -n "${2:-}" ] && [ "${2#-}" = "$2" ]; then VERSION_DEMANDEE="$2"; shift; fi ;;
        --publish) MODE="publish"; VERSION_DEMANDEE="${2:?--publish attend une version X.Y.Z}"; shift ;;
        # Interne : le build de développement de `run.sh`, hors de dist/.
        --debug) CONFIG="debug"; DIST=".build/dev" ;;
        -h|--help) aide; exit 0 ;;
        --install) echo "build.sh : --install a déménagé — sh run.sh --install [--start]" >&2; exit 2 ;;
        *) echo "build.sh : option inconnue « $1 »" >&2; aide >&2; exit 2 ;;
    esac
    shift
done
if [ -n "$VERSION_DEMANDEE" ] && [[ ! "$VERSION_DEMANDEE" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    echo "build.sh : version « $VERSION_DEMANDEE » mal formée — attendu X.Y.Z" >&2; exit 2
fi

if [ "$MODE" = "publish" ]; then
    TAG="v$VERSION_DEMANDEE"
    [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "build.sh : --publish se lance depuis main" >&2; exit 1; }
    [ -z "$(git status --porcelain)" ] || { echo "build.sh : l'arbre n'est pas propre" >&2; exit 1; }
    git fetch -q origin main --tags
    git merge-base --is-ancestor origin/main HEAD \
        || { echo "build.sh : main a divergé d'origin/main" >&2; exit 1; }
    ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || { echo "build.sh : le tag $TAG existe déjà" >&2; exit 1; }
    bash Tools/notes-de-version.sh "$VERSION_DEMANDEE" >/dev/null || exit 1
    if [ "$PUBLICATION_PAR_CI" = "0" ]; then
        bash test.sh || { echo "build.sh : tests en échec, rien n'est publié" >&2; exit 1; }
    fi
    git push origin main
    git tag -a "$TAG" -m "Synfus $VERSION_DEMANDEE"
    git push origin "$TAG"
    if [ "$PUBLICATION_PAR_CI" = "1" ]; then
        echo "==> $TAG poussé : la release se construit sur la CI"
        exit 0
    fi
    bash Tools/publier-release.sh "$VERSION_DEMANDEE"
    exit 0
fi

NAME="Synfus"
# Reverse-DNS du domaine réellement détenu : synseria.fr. Cet identifiant est
# l'identité vue par TCC et le nom du fichier de préférences — le changer oblige
# à réautoriser l'Accessibilité et repart d'un plist de préférences vierge :
# il n'y a pas de migration (cf. CLAUDE.md, section Préférences).
BUNDLE_ID="fr.synseria.Synfus"
# La version est désormais affichée dans les réglages, et les binaires étant
# signés ad-hoc — donc à réautoriser à chaque version —, savoir laquelle tourne
# n'est pas un détail. À défaut de VERSION fournie (c'est la CI qui la donne,
# tirée du tag), on prend le dernier tag du dépôt plutôt qu'un 0.0.1 qui
# mentirait à chaque build local.
VERSION="${VERSION_DEMANDEE:-${VERSION:-$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null | sed 's/^v//')}}"
VERSION="${VERSION:-0.0.1}"
# Numéro de build : le nombre de commits. `CFBundleShortVersionString` reste
# le tag, purement numérique, comme Apple l'attend.
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
# Tout ce qui est produit va dans dist/ ; le build de développement de run.sh
# dans .build/dev/.
APP="$DIST/$NAME.app"
mkdir -p "$DIST"

BUILD_FLAGS=(-c "$CONFIG")
[ -n "${ARCH:-}" ] && BUILD_FLAGS+=(--arch "$ARCH")

echo "==> Compilation ($CONFIG${ARCH:+, $ARCH})"
swift build "${BUILD_FLAGS[@]}"
BIN_PATH="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"
BINARY="$BIN_PATH/$NAME"

# La signature détermine l'identité vue par TCC (l'autorisation
# Accessibilité) : signature.sh la choisit, la même pour tous les builds.
source ./signature.sh

echo "==> Assemblage du bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>$NAME</string>
    <key>CFBundleDisplayName</key>       <string>$NAME</string>
    <key>CFBundleIdentifier</key>        <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>        <string>$NAME</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>           <string>$BUILD</string>
    <key>LSMinimumSystemVersion</key>    <string>14.0</string>
    <!-- Les langues de l'interface (Resources/Localisation/<code>.json) : les
         déclarer fait apparaître Synfus dans Réglages Système › Langue et
         région › Applications, et Locale.preferredLanguages suit ce choix. -->
    <key>CFBundleDevelopmentRegion</key> <string>fr</string>
    <key>CFBundleLocalizations</key>
    <array><string>fr</string><string>en</string><string>es</string></array>
    <!-- Accessory : pas d'icône dans le Dock, l'app vit dans la barre de menus. -->
    <key>LSUIElement</key>               <true/>
    <!-- Motif affiché par macOS lors de la demande d'autorisation, pour les
         aperçus de fenêtres. Rien n'est capturé tant qu'ils sont désactivés. -->
    <key>NSScreenCaptureUsageDescription</key>
    <string>Synfus capture les fenêtres de Dofus pour en afficher un aperçu dans la barre.</string>
    <key>NSHumanReadableCopyright</key>  <string>Synfus</string>
</dict>
</plist>
PLIST

if [ -f "Resources/$NAME.icns" ]; then
    cp "Resources/$NAME.icns" "$APP/Contents/Resources/"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $NAME" "$APP/Contents/Info.plist"
fi

# Les libellés de l'interface (une table JSON par langue), la carte intégrée.
cp -R "Resources/Localisation" "$APP/Contents/Resources/Localisation"
cp "Resources/Carte.json" "$APP/Contents/Resources/Carte.json"

echo "==> Signature"
signer "$APP" "$BUNDLE_ID"

echo "==> $APP prêt"

if [ "$MODE" = "release" ]; then
    DMG="$DIST/$NAME-$VERSION-${ARCH:-$(uname -m)}.dmg"
    ./Tools/make-dmg.sh "$APP" "$DMG"
fi
