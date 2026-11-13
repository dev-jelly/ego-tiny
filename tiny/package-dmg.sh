#!/bin/bash
# Package build/ego tiny.app as the installer DMG that EGO_TINY_DOWNLOAD
# (tiny/links.env) points to. Run tiny/build-tiny.sh first.
#
# The DMG holds a copy of the proprietary ego lite app, patched. Keep it for
# your own machines; do not publish it without Citro Labs' permission.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="$REPO/build/ego tiny.app"
[ -d "$APP" ] || { echo "build/ego tiny.app not found; run tiny/build-tiny.sh" >&2; exit 1; }
. "$REPO/tiny/links.env"
DMG="$REPO/build/$(basename "$EGO_TINY_DOWNLOAD")"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -Rc "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "ego tiny" -srcfolder "$STAGE" -fs HFS+ -format UDZO "$DMG"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "built: $DMG"
echo "upload it so that $EGO_TINY_DOWNLOAD serves this file"
