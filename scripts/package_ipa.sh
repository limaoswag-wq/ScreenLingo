#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DERIVED="${DERIVED_DATA_PATH:-$ROOT/build}"
CONFIG="${CONFIGURATION:-Release}"
APP="$DERIVED/Build/Products/${CONFIG}-iphoneos/ScreenLingo.app"
OUT="${IPA_OUTPUT:-$ROOT/ScreenLingo.ipa}"

if [[ ! -d "$APP" ]]; then
  echo "missing app bundle: $APP" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/ScreenLingo.app"
# TrollStore / ldid: keep entitlements files inside the bundle for later signing.
cp "$ROOT/App/ScreenLingo.entitlements" "$STAGE/Payload/ScreenLingo.app/ScreenLingo.entitlements"
if [[ -d "$STAGE/Payload/ScreenLingo.app/PlugIns/Broadcast.appex" ]]; then
  cp "$ROOT/Broadcast/Broadcast.entitlements" "$STAGE/Payload/ScreenLingo.app/PlugIns/Broadcast.appex/Broadcast.entitlements"
fi

rm -f "$OUT"
(cd "$STAGE" && zip -qry "$OUT" Payload)
rm -rf "$STAGE"
echo "wrote $OUT"
ls -lh "$OUT"
