#!/bin/bash
# Build "ego tiny.app": a copy of the installed ego lite with every outbound
# vendor/analytics channel removed, plus the ego-browser runtime built from
# this fork.
#
#   tiny/build-tiny.sh            build into build/ego tiny.app
#   tiny/build-tiny.sh --install  also copy to /Applications and link ego-tiny
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${EGO_LITE_APP:-/Applications/ego lite.app}"
OUT="$REPO/build"
APP="$OUT/ego tiny.app"
PLISTBUDDY=/usr/libexec/PlistBuddy

[ -d "$SRC" ] || { echo "ego lite not found at $SRC" >&2; exit 1; }

echo "==> runtime (fork)"
(cd "$REPO/package/ego-browser" && { [ -d node_modules ] || npm ci --ignore-scripts; } && npm run build)

echo "==> copy app"
rm -rf "$APP"
mkdir -p "$OUT"
cp -Rc "$SRC" "$APP"
FW="$APP/Contents/Frameworks/ego Framework.framework"
CUR="$(readlink "$FW/Versions/Current")"
for v in "$FW/Versions"/*; do
	[ -L "$v" ] && continue
	[ "$(basename "$v")" = "$CUR" ] || rm -rf "$v"
done
V="$FW/Versions/$CUR"

case "$CUR" in
	0.6.2.9|0.6.2.10)
		python3 -I "$REPO/tiny/patch-chromium-xslt.py" "$V/ego Framework"
		;;
esac

echo "==> remove updater"
rm -rf "$V/Helpers/EgoUpdater.app" "$APP/Contents/Library" \
	"$APP/Contents/embedded.provisionprofile" "$V/Resources/install.sh" \
	"$V/Resources/ego-skills/ego-browser/scripts/install.sh"

# The real browser binary becomes "ego tiny"; the bundle executable is a
# launcher that execs it with the blocking flags.
mv "$APP/Contents/MacOS/ego lite" "$APP/Contents/MacOS/ego tiny"
mv "$APP/Contents/Resources/com.citrolabs.ego.lite.manifest" "$APP/Contents/Resources/com.citrolabs.ego.tiny.manifest"

echo "==> neutralise endpoints + rename"
python3 -I "$REPO/tiny/patch_app.py" "$APP"

echo "==> rebrand"
# com.citrolabs.ego.lite -> com.citrolabs.ego.tiny is the same length, so it is
# safe inside the Mach-O files as well. Helpers keep the shared base id.
LC_ALL=C perl -pi -e 's/com\.citrolabs\.ego\.lite/com.citrolabs.ego.tiny/g' \
	"$APP/Contents/MacOS/ego tiny" "$V/ego Framework" "$APP/Contents/Info.plist" \
	"$V/Resources/app_mode-Info.plist"
for helper in "$V/Helpers"/*.app; do
	LC_ALL=C perl -pi -e 's/com\.citrolabs\.ego\.lite/com.citrolabs.ego.tiny/g' "$helper/Contents/Info.plist"
done
INFO="$APP/Contents/Info.plist"
plutil -convert xml1 "$INFO"
$PLISTBUDDY -c "Set :CFBundleName 'ego tiny'" "$INFO"
$PLISTBUDDY -c "Set :CFBundleDisplayName 'ego tiny'" "$INFO"
$PLISTBUDDY -c "Set :CFBundleExecutable 'ego-tiny-launcher'" "$INFO"
$PLISTBUDDY -c "Set :CrProductDirName 'Citro Labs/ego tiny'" "$INFO"
for key in KSUpdateURL KSProductID KSChannelID KSVersion SMPrivilegedExecutables CFBundleIconName; do
	$PLISTBUDDY -c "Delete :$key" "$INFO" 2>/dev/null || true
done
$PLISTBUDDY -c "Set :CrProductDirName 'Citro Labs/ego tiny'" "$V/Resources/Info.plist"

echo "==> launcher"
cp "$REPO/tiny/launcher.sh" "$APP/Contents/MacOS/ego-tiny-launcher"
chmod 755 "$APP/Contents/MacOS/ego-tiny-launcher"

echo "==> icon"
ICONSET="$OUT/jelly.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
	sips -z $s $s "$REPO/tiny/icon/jelly-1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
	sips -z $((s * 2)) $((s * 2)) "$REPO/tiny/icon/jelly-1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/app.icns"
sips -z 32 32 "$REPO/tiny/icon/jelly-1024.png" --out "$V/Resources/product_logo_32.png" >/dev/null
rm -rf "$ICONSET" "$APP/Contents/Resources/Assets.car"

echo "==> fork runtime"
mkdir -p "$APP/Contents/Resources/ego-tiny-sdk"
cp -R "$REPO/package/ego-browser/dist/out/." "$APP/Contents/Resources/ego-tiny-sdk/"
rm -f "$APP/Contents/Resources/ego-tiny-sdk/agent-skills/ego-browser/scripts/install.sh"
# The guide `ego-tiny skill` prints: same text, commands written as ego-tiny.
LC_ALL=C perl -pi -e 's/(?<![\[.\/\w-])ego-browser(?![:\w\/-])/ego-tiny/g' \
	"$APP/Contents/Resources/ego-tiny-sdk/ego-browser"/SKILL*.md
# Page ledgers and downloads go to ~/.ego-tiny, not ego lite's ~/.ego-browser.
LC_ALL=C perl -pi -e 's/"\.ego-browser"/".ego-tiny"/g' "$APP/Contents/Resources/ego-tiny-sdk/index.js"
mkdir -p "$APP/Contents/Resources/ego-tiny-skill"
cp -R "$REPO/tiny/skill/." "$APP/Contents/Resources/ego-tiny-skill/"
cp "$REPO/tiny/ego-tiny-cli.sh" "$APP/Contents/Resources/ego-tiny"
chmod 755 "$APP/Contents/Resources/ego-tiny"

echo "==> sign (ad hoc)"
xattr -cr "$APP"
sign() { codesign --force --sign - "$@" 2>&1 | grep -v 'replacing existing signature' || true; }
find "$V/Libraries" -name '*.dylib' -print0 | while IFS= read -r -d '' f; do sign "$f"; done
for f in "$V/Helpers"/*; do
	[ -d "$f" ] || sign "$f"
done
for helper in "$V/Helpers"/*.app; do sign "$helper"; done
sign "$FW"
sign "$APP/Contents/MacOS/ego tiny"
sign "$APP"
codesign --verify --deep --strict "$APP"
echo "built: $APP"

if [ "${1:-}" = "--install" ]; then
	DEST="/Applications/ego tiny.app"
	if pgrep -f "$DEST/Contents/MacOS/ego tiny" >/dev/null; then
		echo "ego tiny is running; quit it first" >&2
		exit 1
	fi
	rm -rf "$DEST"
	cp -Rc "$APP" "$DEST"
	mkdir -p "$HOME/.local/bin"
	ln -sf "$DEST/Contents/Resources/ego-tiny" "$HOME/.local/bin/ego-tiny"
	# The ego-tiny skill sits next to ego lite's ego-browser skill.
	for skills in "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills"; do
		[ -d "$skills" ] || continue
		[ -L "$skills/ego-tiny" ] || [ ! -e "$skills/ego-tiny" ] || continue
		ln -sfn "$DEST/Contents/Resources/ego-tiny-skill" "$skills/ego-tiny"
	done
	echo "installed: $DEST, ~/.local/bin/ego-tiny and the ego-tiny skill"
fi
