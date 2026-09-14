#!/bin/bash
# Compile Synfus et assemble le bundle .app.
#   ./build.sh            -> construit dist/Synfus.app (et le plugin Stream Deck)
#   ./build.sh --install  -> construit puis installe dans /Applications et relance
#
# Deux variables d'environnement pilotent la CI sans changer l'usage local :
#   VERSION=0.0.1   numéro inscrit dans l'Info.plist (défaut : dernier tag git)
#   ARCH=x86_64     architecture cible (défaut : celle de la machine)
set -euo pipefail

cd "$(dirname "$0")"

NAME="Synfus"
# Reverse-DNS du domaine réellement détenu : synseria.fr. Cet identifiant est
# l'identité vue par TCC et le nom du fichier de préférences — le changer oblige
# à réautoriser l'Accessibilité, et impose le repli de Preferences.legacyDomains.
BUNDLE_ID="fr.synseria.Synfus"
# La version est désormais affichée dans les réglages, et les binaires étant
# signés ad-hoc — donc à réautoriser à chaque version —, savoir laquelle tourne
# n'est pas un détail. À défaut de VERSION fournie (c'est la CI qui la donne,
# tirée du tag), on prend le dernier tag du dépôt plutôt qu'un 0.0.1 qui
# mentirait à chaque build local.
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}"
VERSION="${VERSION:-0.0.1}"
# Numéro de build : le tag suivi du nombre de commits et de l'empreinte quand
# HEAD s'en est écarté. `CFBundleShortVersionString` reste purement numérique,
# comme Apple l'attend ; c'est ici que va le détail.
BUILD="$(git describe --tags --always --dirty 2>/dev/null || echo "$VERSION")"
# Tout ce qui est produit va dans dist/ — l'app comme le plugin.
APP="dist/$NAME.app"

BUILD_FLAGS=(-c release)
[ -n "${ARCH:-}" ] && BUILD_FLAGS+=(--arch "$ARCH")

echo "==> Compilation (release${ARCH:+, $ARCH})"
swift build "${BUILD_FLAGS[@]}"
BINARY="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/$NAME"

# La signature détermine l'identité vue par TCC (l'autorisation Accessibilité).
# Une identité stable d'un build à l'autre évite de réautoriser à chaque
# rebuild : le certificat local « Synfus Dev » (Tools/make-signing-identity.sh)
# d'abord, un certificat Apple Development sinon, ad-hoc en dernier recours —
# et là, la case Accessibilité est à recocher après chaque build.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o '"\(Synfus Dev\|Apple Development: [^"]*\)"' | head -1 | tr -d '"' || true)"

# Le plugin Stream Deck : un dossier .sdPlugin à installer dans le logiciel
# Elgato (double-clic, ou `streamdeck link dist/fr.synseria.synfus.sdPlugin`
# avec le CLI d'Elgato pour développer). Le binaire est celui du target
# SynfusDeck ; les icônes sont dérivées de la marque, jamais du jeu.
PLUGIN="dist/fr.synseria.synfus.sdPlugin"
echo "==> Assemblage du plugin Stream Deck"
rm -rf "$PLUGIN"
mkdir -p "$PLUGIN"
cp "$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/SynfusDeck" "$PLUGIN/"
cp Plugin/manifest.json "$PLUGIN/"
sips -z 144 144 Resources/Synfus.png --out "$PLUGIN/icon.png" >/dev/null
sips -z 288 288 Resources/Synfus.png --out "$PLUGIN/icon@2x.png" >/dev/null
# L'état « grisé » (Dofus n'est pas devant) : la même marque pour l'instant —
# le plugin pose son propre titre, c'est lui qui dit l'état.
cp "$PLUGIN/icon.png" "$PLUGIN/icon-dim.png"
cp "$PLUGIN/icon@2x.png" "$PLUGIN/icon-dim@2x.png"
sed -i '' "s/\"Version\": \"[^\"]*\"/\"Version\": \"$VERSION\"/" "$PLUGIN/manifest.json"
./Plugin/make-profile.sh "$PLUGIN"
# Le paquet que le logiciel Stream Deck installe par double-clic — et le seul
# chemin qui enregistre le profil livré comme *appartenant au plugin*, ce que
# `switchToProfile` exige.
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" --identifier "fr.synseria.synfus.deck" "$PLUGIN/SynfusDeck"
else
    codesign --force --sign - --identifier "fr.synseria.synfus.deck" "$PLUGIN/SynfusDeck"
fi
PACKAGE="dist/fr.synseria.synfus.streamDeckPlugin"
rm -f "$PACKAGE"
(cd dist && zip -qr "$(basename "$PACKAGE")" "$(basename "$PLUGIN")")
echo "==> $PLUGIN prêt"

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

# Les visuels Ankama, s'ils ont été téléchargés (Tools/fetch-ankama-assets.sh) :
# embarqués dans ce build-ci, pour cette machine — le dossier est ignoré par
# Git et la CI ne l'a pas, les releases restent sans visuel du jeu.
if [ -d "Resources/Ankama" ]; then
    cp -R "Resources/Ankama" "$APP/Contents/Resources/Ankama"
fi

# Le paquet du plugin et le profil livré, embarqués : l'onglet Stream Deck
# les ouvre dans le logiciel Elgato d'un clic, sans passer par dist/.
cp "$PACKAGE" "$APP/Contents/Resources/"
cp "$PLUGIN/Synfus.streamDeckProfile" "$APP/Contents/Resources/"

echo "==> Signature"
if [ -n "$IDENTITY" ]; then
    echo "    identité : $IDENTITY"
    codesign --force --deep --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP"
else
    echo "    identité : ad-hoc — ./Tools/make-signing-identity.sh pour ne plus réautoriser l'Accessibilité à chaque build"
    codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP"
fi

echo "==> $APP prêt"

if [ "${1:-}" = "--install" ]; then
    echo "==> Installation dans /Applications"
    pkill -x "$NAME" 2>/dev/null || true
    rm -rf "/Applications/$NAME.app"
    cp -R "$APP" /Applications/
    open "/Applications/$NAME.app"
    echo "==> Lancé depuis /Applications/$NAME.app"

    # Le plugin va dans le dossier des plugins du logiciel Stream Deck, qui
    # ne le charge qu'au lancement : on le relance s'il tournait. Un
    # `.sdPlugin` ne s'installe pas par double-clic — c'est le format
    # empaqueté `.streamDeckPlugin` que le logiciel reconnaît.
    DECK_PLUGINS="$HOME/Library/Application Support/com.elgato.StreamDeck/Plugins"
    INSTALLED="$DECK_PLUGINS/$(basename "$PLUGIN")"
    if [ -d "$INSTALLED" ] && ! diff -q <(grep -v '"Version"' "$INSTALLED/manifest.json") \
                                      <(grep -v '"Version"' "$PLUGIN/manifest.json") >/dev/null; then
        # Le manifeste a changé (actions, profils) : seul le paquet fait
        # réenregistrer le profil livré — le logiciel demande confirmation.
        echo "==> Le manifeste du plugin a changé : réinstallation par le paquet"
        open "$PACKAGE"
    elif [ -d "$INSTALLED" ]; then
        # Déjà installé : on remplace le contenu et on relance le logiciel,
        # qui ne charge les plugins qu'au lancement.
        echo "==> Mise à jour du plugin Stream Deck"
        rm -rf "$DECK_PLUGINS/$(basename "$PLUGIN")"
        cp -R "$PLUGIN" "$DECK_PLUGINS/"
        if pkill -x "Stream Deck" 2>/dev/null; then
            sleep 1
            open -a "Elgato Stream Deck"
            echo "==> Logiciel Stream Deck relancé"
        fi
    elif [ -d "$DECK_PLUGINS" ]; then
        # Première installation : par le paquet, pour que le logiciel
        # enregistre le profil « Synfus » comme celui du plugin.
        echo "==> Installation du plugin Stream Deck (le logiciel Stream Deck demande confirmation)"
        open "$PACKAGE"
    fi
fi
