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

install_ldid() {
  if command -v ldid >/dev/null 2>&1; then
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    brew install ldid >/dev/null 2>&1 || true
  fi
  if command -v ldid >/dev/null 2>&1; then
    return 0
  fi
  local arch url tmp
  arch="$(uname -m)"
  if [[ "$arch" == "arm64" ]]; then
    url="https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_macosx_arm64"
  else
    url="https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_macosx_x86_64"
  fi
  tmp="$(mktemp -d)"
  curl -L --fail -o "$tmp/ldid" "$url"
  chmod +x "$tmp/ldid"
  export PATH="$tmp:$PATH"
}

install_ldid
if ! command -v ldid >/dev/null 2>&1; then
  echo "ldid is required; Apple ad-hoc codesign crashes under TrollStore on iOS 16" >&2
  exit 1
fi
echo "using ldid: $(command -v ldid)"

STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/ScreenLingo.app"
APP_STAGE="$STAGE/Payload/ScreenLingo.app"
APPEX="$APP_STAGE/PlugIns/Broadcast.appex"

# Drop any ad-hoc signature left by the toolchain. TrollStore wants ldid.
rm -rf "$APP_STAGE/_CodeSignature" || true
rm -rf "$APPEX/_CodeSignature" || true

cp "$ROOT/App/ScreenLingo.entitlements" "$APP_STAGE/ScreenLingo.entitlements"
if [[ -d "$APPEX" ]]; then
  cp "$ROOT/Broadcast/Broadcast.entitlements" "$APPEX/Broadcast.entitlements"
  ldid -S"$ROOT/Broadcast/Broadcast.entitlements" "$APPEX/Broadcast"
fi
ldid -S"$ROOT/App/ScreenLingo.entitlements" "$APP_STAGE/ScreenLingo"

rm -f "$OUT"
(cd "$STAGE" && zip -qry "$OUT" Payload)
rm -rf "$STAGE"
echo "wrote $OUT"
ls -lh "$OUT"
