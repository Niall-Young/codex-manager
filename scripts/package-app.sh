#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$("$ROOT/scripts/build-app.sh" | tail -n 1)"
ZIP_PATH="$ROOT/.build/Codex Manager.zip"

if command -v codesign >/dev/null 2>&1; then
  /usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --norsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "$ZIP_PATH"
