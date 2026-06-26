#!/usr/bin/env bash
# Headless-ish E2E for the menu-bar app. Drives the running app via the file command
# channel (enabled by /tmp/actuna-e2e-on) and asserts that selecting a SPECIFIC
# history item puts THAT item on the clipboard (not whatever was copied last).
#
# This verifies the full pipeline: capture → store → select → clipboard. Auto-paste
# (synthetic ⌘V into another app) needs the Accessibility permission and a focused
# target, so it is checked via the debug log line ("synthesized ⌘V" vs "copy-only"),
# not by typing into a real app.
set -euo pipefail
cd "$(dirname "$0")/.."

LOG="$HOME/Library/Logs/ActunaCopyPaste/debug.log"
CMD="/tmp/actuna-cmd.txt"
APP="build/Full/ActunaCopyPaste.app"
ALPHA="alpha clipboard sample"
BETA="beta clipboard sample"

echo "▶︎ build (Debug)"
pkill -f "ActunaCopyPaste" 2>/dev/null || true
sleep 1
xcodebuild -project ActunaCopyPaste.xcodeproj -scheme App-Full -configuration Debug \
  -derivedDataPath build/dd CONFIGURATION_BUILD_DIR="$PWD/build/Full" build >/dev/null 2>&1 \
  || { echo "❌ BUILD FAILED"; exit 1; }

echo "▶︎ launch with E2E channel"
rm -f "$CMD"
touch /tmp/actuna-e2e-on
open "$APP"
sleep 2.5

echo "▶︎ feed two clipboard items"
printf '%s' "$ALPHA" | pbcopy; sleep 0.8
printf '%s' "$BETA"  | pbcopy; sleep 0.8
# Clipboard now holds BETA; selecting ALPHA must override it with ALPHA.

echo "▶︎ command: select ALPHA (an older, non-top item)"
printf 'select:alpha' > "$CMD"
sleep 1.5

RESULT="$(pbpaste)"
echo "   clipboard after select = '$RESULT'"

echo "▶︎ debug log (tail):"
tail -n 20 "$LOG" 2>/dev/null | sed 's/^/   /'

echo
PASS=1
if [ "$RESULT" = "$ALPHA" ]; then
  echo "✅ PASS: selecting ALPHA put ALPHA on the clipboard (pipeline capture→store→select→clipboard works)"
else
  echo "❌ FAIL: expected '$ALPHA', got '$RESULT'"
  PASS=0
fi

if grep -q "synthesized ⌘V" "$LOG" 2>/dev/null; then
  echo "ℹ️  auto-paste path ran (Accessibility granted)"
elif grep -q "copy-only" "$LOG" 2>/dev/null; then
  echo "ℹ️  copy-only path ran (Accessibility NOT granted → user presses ⌘V; auto-paste needs the permission)"
fi

rm -f /tmp/actuna-e2e-on "$CMD"
pkill -f "ActunaCopyPaste" 2>/dev/null || true
[ "$PASS" = 1 ] || exit 1
