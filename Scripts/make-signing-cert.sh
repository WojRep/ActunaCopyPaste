#!/usr/bin/env bash
# Creates a local self-signed CODE-SIGNING identity ("Actuna CopyPaste Dev") in the
# login keychain. Signing with a stable identity (instead of ad-hoc) gives the app a
# stable code "designated requirement", so macOS persists TCC grants (Accessibility
# for auto-paste) across launches AND across rebuilds signed with the same cert.
#
# One-time. Idempotent. Not for distribution (Gatekeeper won't trust it) — local dev only.
set -euo pipefail

CN="Actuna CopyPaste Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning -v 2>/dev/null | grep -q "$CN"; then
  echo "✅ Identity '$CN' already exists — nothing to do."
  security find-identity -p codesigning -v | grep "$CN"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions     = ext
prompt              = no
[ dn ]
CN = Actuna CopyPaste Dev
[ ext ]
basicConstraints     = critical,CA:false
keyUsage             = critical,digitalSignature
extendedKeyUsage     = critical,codeSigning
EOF

echo "▶︎ generating self-signed code-signing certificate"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -config "$TMP/openssl.cnf" -extensions ext

openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$CN" -out "$TMP/id.p12" -passout pass:actuna

echo "▶︎ importing into the login keychain (allowing codesign to use the key)"
security import "$TMP/id.p12" -k "$KEYCHAIN" -P actuna -T /usr/bin/codesign -A

echo
echo "✅ Created code-signing identity '$CN'."
security find-identity -p codesigning -v | grep "$CN" || {
  echo "⚠️  Identity not listed — the login keychain may be locked; unlock it and re-run."
  exit 1
}
