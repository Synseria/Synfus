#!/bin/bash
# signature.sh — sourcé par build.sh : choisit l'identité de signature et
# expose `signer <chemin> <identifiant> [--deep]`.
#
# Pourquoi : l'autorisation Accessibilité (TCC) est liée à l'identité de code.
# Signée ad hoc, l'app change d'identité à chaque build : la case reste cochée
# dans Réglages Système mais macOS ne la lui applique plus — il faut la
# redonner après chaque build. Avec un certificat stable, on autorise une fois.
#
# Ordre de préférence, le même dans toutes les apps Synseria :
#   1. Developer ID Application   (distribution, notarisable)
#   2. Apple Development de l'équipe personnelle 339WUY8TXY (compte gratuit :
#      pas de notarisation), puis tout autre Apple Development
#   3. « Synfus Dev », le certificat local (Tools/make-signing-identity.sh)
#   4. ad hoc — c'est le cas de la CI, qui n'a aucun certificat.
#
# ⚠️ Changer d'identité — y compris en en créant une mieux classée — fait
# réautoriser l'Accessibilité (et l'enregistrement de l'écran) une fois.
EQUIPE_SIGNATURE="339WUY8TXY"

_identites="$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' || true)"
_equipe() {
    security find-certificate -c "$1" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null \
        | grep -q "OU *= *$EQUIPE_SIGNATURE"
}
IDENTITE_SIGNATURE="$(printf '%s\n' "$_identites" | grep '^Developer ID Application: ' | head -1 || true)"
if [ -z "$IDENTITE_SIGNATURE" ]; then
    while IFS= read -r _nom; do
        [ -n "$_nom" ] && _equipe "$_nom" && { IDENTITE_SIGNATURE="$_nom"; break; }
    done < <(printf '%s\n' "$_identites" | grep '^Apple Development: ' || true)
fi
[ -n "$IDENTITE_SIGNATURE" ] || IDENTITE_SIGNATURE="$(printf '%s\n' "$_identites" | grep '^Apple Development: ' | head -1 || true)"
[ -n "$IDENTITE_SIGNATURE" ] || IDENTITE_SIGNATURE="$(printf '%s\n' "$_identites" | grep -x 'Synfus Dev' | head -1 || true)"
unset _identites _nom
unset -f _equipe

if [ -n "$IDENTITE_SIGNATURE" ]; then
    echo "[signature] 🔏 $IDENTITE_SIGNATURE"
else
    echo "[signature] ⚠️  aucune identité : signature ad hoc — l'Accessibilité sera à réautoriser après chaque build."
    echo "[signature]    ./Tools/make-signing-identity.sh crée un certificat local une fois pour toutes."
fi

# signer <chemin> <identifiant> [--deep]
signer() {
    local chemin="$1" identifiant="$2"; shift 2
    codesign --force "$@" --sign "${IDENTITE_SIGNATURE:--}" --identifier "$identifiant" "$chemin"
}
