#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/build_app.sh

OUTPUT="$ROOT_DIR/dist/AwayLock-preview.zip"
rm -f "$OUTPUT"

cd "$ROOT_DIR/dist"
/usr/bin/zip -r "$OUTPUT" AwayLock.app

echo "$OUTPUT"
