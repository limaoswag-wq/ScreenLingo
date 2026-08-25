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
APP_STAGE="$STAGE/Payload/ScreenLingo.app"
APPEX="$APP_STAGE/PlugIns/Broadcast.appex"

cp "$ROOT/App/ScreenLingo.entitlements" "$APP_STAGE/ScreenLingo.entitlements"
if [[ -d "$APPEX" ]]; then
  cp "$ROOT/Broadcast/Broadcast.entitlements" "$APPEX/Broadcast.entitlements"
fi

# Embed entitlements into the binaries. Unsigned builds leave App Groups inert.
sign_one() {
  local target="$1"
  local ents="$2"
  if command -v ldid >/dev/null 2>&1; then
    ldid -S"$ents" "$target"
  else
    codesign --force --sign - --timestamp=none --generate-entitlement-der --entitlements "$ents" "$target"
  fi
}

if [[ -d "$APPEX" ]]; then
  sign_one "$APPEX/Broadcast" "$ROOT/Broadcast/Broadcast.entitlements"
  sign_one "$APPEX" "$ROOT/Broadcast/Broadcast.entitlements"
fi
sign_one "$APP_STAGE/ScreenLingo" "$ROOT/App/ScreenLingo.entitlements"
sign_one "$APP_STAGE" "$ROOT/App/ScreenLingo.entitlements"

rm -f "$OUT"
(cd "$STAGE" && zip -qry "$OUT" Payload)
rm -rf "$STAGE"
echo "wrote $OUT"
ls -lh "$OUT"
