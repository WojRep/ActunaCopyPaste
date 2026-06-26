#!/usr/bin/env bash
# Build the Actuna CopyPaste app bundle (App-Full) via xcodebuild.
#
# Usage:
#   Scripts/build-app.sh [Debug|Release]    # default: Release
#
# Signing: if the local self-signed identity "Actuna CopyPaste Dev" exists
# (Scripts/make-signing-cert.sh), the app is signed with it. That stable identity
# gives a stable code "designated requirement", so macOS PERSISTS TCC grants
# (Accessibility for auto-paste) across launches and across rebuilds — unlike ad-hoc
# signing, which forces re-granting every launch. Falls back to ad-hoc if absent.
# Swap to a Developer ID identity for distribution.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-Release}"
SCHEME="App-Full"
IDENTITY_NAME="Actuna CopyPaste Dev"
OUT="build/full"

if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
  SIGN_IDENTITY="$IDENTITY_NAME"
  echo "▶︎ signing with stable identity '$IDENTITY_NAME' (TCC grants persist)"
else
  SIGN_IDENTITY="-"
  echo "▶︎ no dev cert → ad-hoc (run Scripts/make-signing-cert.sh for persistent permissions)"
fi

echo "▶︎ Building $SCHEME ($CONFIG) → $OUT"
xcodebuild \
  -project ActunaCopyPaste.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath build/dd \
  CONFIGURATION_BUILD_DIR="$PWD/$OUT" \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  build

APP=$(find "$OUT" -maxdepth 1 -name '*.app' -print -quit)
echo
echo "✅ Built: $APP"
codesign -dvv "$APP" 2>&1 | grep -iE "Authority|Signature|TeamIdentifier" || true
echo "Launch with:  open \"$APP\""
