#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/mac-battery-ledger.app"
DIST_DIR="$ROOT_DIR/dist"
APP_VERSION="${APP_VERSION:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"
ARCHIVE_NAME="Mac-Battery-Ledger-$APP_VERSION.zip"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"

APP_VERSION="$APP_VERSION" "$ROOT_DIR/Scripts/build-app.sh"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

/usr/bin/codesign --force --sign - --timestamp=none "$APP_DIR"
/usr/bin/codesign --verify --deep --strict "$APP_DIR"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"

(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

echo "$ARCHIVE_PATH"
