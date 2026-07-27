#!/bin/bash
# Compile Synfus et assemble le bundle .app.
#   ./build.sh            -> construit ./Synfus.app
#   ./build.sh --install  -> construit puis installe dans /Applications et relance
#
# Deux variables d'environnement pilotent la CI sans changer l'usage local :
#   VERSION=0.0.1   numéro inscrit dans l'Info.plist (défaut : 0.0.1)
#   ARCH=x86_64     architecture cible (défaut : celle de la machine)
set -euo pipefail

cd "$(dirname "$0")"

NAME="Synfus"
BUNDLE_ID="fr.synfus.Synfus"
VERSION="${VERSION:-0.0.1}"
APP="$NAME.app"

BUILD_FLAGS=(-c release)
[ -n "${ARCH:-}" ] && BUILD_FLAGS+=(--arch "$ARCH")

echo "==> Compilation (release${ARCH:+, $ARCH})"
swift build "${BUILD_FLAGS[@]}"
BINARY="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/$NAME"

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
    <key>CFBundleVersion</key>           <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>    <string>14.0</string>
    <!-- Accessory : pas d'icône dans le Dock, l'app vit dans la barre de menus. -->
    <key>LSUIElement</key>               <true/>
    <key>NSHumanReadableCopyright</key>  <string>Synfus</string>
</dict>
</plist>
PLIST

if [ -f "Resources/$NAME.icns" ]; then
    cp "Resources/$NAME.icns" "$APP/Contents/Resources/"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $NAME" "$APP/Contents/Info.plist"
fi

# La signature détermine l'identité vue par TCC (l'autorisation Accessibilité).
# Une identité de développement donne une identité stable d'un build à l'autre ;
# à défaut, la signature ad-hoc oblige parfois à réautoriser après un rebuild.
echo "==> Signature"
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"' || true)"

if [ -n "$IDENTITY" ]; then
    echo "    identité : $IDENTITY"
    codesign --force --deep --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP"
else
    echo "    identité : ad-hoc (aucun certificat de développement trouvé)"
    codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP"
fi

echo "==> $APP prêt"

if [ "${1:-}" = "--install" ]; then
    echo "==> Installation dans /Applications"
    pkill -x "$NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP"
    cp -R "$APP" /Applications/
    open "/Applications/$APP"
    echo "==> Lancé depuis /Applications/$APP"
fi
