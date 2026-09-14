#!/bin/bash
# Crée, une fois pour toutes, un certificat de signature de code local
# « Synfus Dev » dans le trousseau de session.
#
#   ./Tools/make-signing-identity.sh
#
# Pourquoi : l'autorisation Accessibilité (TCC) est liée à l'identité de
# code. Signée ad-hoc, l'app change d'identité à chaque build — d'où la case
# à recocher à chaque `./build.sh --install`. Signée avec ce certificat,
# l'identité est stable : on autorise une dernière fois, et c'est fini.
# Le certificat est auto-signé et ne sert qu'à cette machine ; il n'a rien à
# voir avec un compte développeur Apple, et n'est jamais reversé au dépôt.
set -euo pipefail

NAME="Synfus Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$NAME\""; then
    echo "✓ Le certificat « $NAME » existe et est reconnu pour la signature."
    exit 0
fi

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    # Importé mais pas encore approuvé (la demande de mot de passe a été
    # refusée) : il ne manque que la confiance.
    echo "▸ Le certificat existe, il manque la confiance pour la signature de code (mot de passe demandé)…"
    security find-certificate -c "$NAME" -p "$KEYCHAIN" > "$TMPDIR/synfus-cert.pem"
    security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMPDIR/synfus-cert.pem"
    rm -f "$TMPDIR/synfus-cert.pem"
    echo "✓ Certificat « $NAME » prêt."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ Génération du certificat…"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -subj "/CN=$NAME" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" >/dev/null 2>&1
openssl pkcs12 -export -legacy -out "$WORK/identity.p12" \
    -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -passout pass:synfus >/dev/null 2>&1 \
    || openssl pkcs12 -export -out "$WORK/identity.p12" \
    -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -passout pass:synfus >/dev/null 2>&1

echo "▸ Import dans le trousseau (codesign y aura accès sans redemander)…"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P synfus -T /usr/bin/codesign -T /usr/bin/security >/dev/null

echo "▸ Confiance pour la signature de code (macOS demande ton mot de passe)…"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

echo "✓ Certificat « $NAME » prêt. Prochain ./build.sh --install : réautoriser l'Accessibilité une dernière fois."
