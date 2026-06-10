#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/build_app.sh

OUTPUT="$ROOT_DIR/dist/AwayLock-preview.zip"
rm -f "$OUTPUT"

cd "$ROOT_DIR/dist"
/usr/bin/zip -r "$OUTPUT" AwayLock.app

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
    echo "NOTARIZE=1 requires APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD." >&2
    exit 1
  fi

  xcrun notarytool submit "$OUTPUT" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

  xcrun stapler staple "$ROOT_DIR/dist/AwayLock.app"
fi

echo "$OUTPUT"
