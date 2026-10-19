#!/bin/bash
# Builds the BAR launcher for macOS (BAR.app, DMG, zip and latest-mac.yml for
# the self-update) from a spring-launcher checkout with macOS support and
# dist_cfg, like the launcher workflow does for Linux and Windows. The engine
# is not part of the app, the launcher downloads it.
#
# Usage: build/mac/build.sh <spring-launcher checkout> <output dir>
# Env:
#   APP_VERSION    launcher version, default 0.0.0
#   UPDATE_URL     where the launcher looks for latest-mac.yml; no self-update if unset
#   SIGN_IDENTITY  codesign identity, "-" (default) for ad-hoc
#   NOTARIZE=1     notarize, needs APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID
#   PACK_ONLY=1    only build <output dir>/BAR.app
#   CONFIG         launcher config to build with, default: written by make_config.py
#                  for the engines BAR uses
set -euo pipefail

CHOBBY_SRC="$(cd "$(dirname "$0")/../.." && pwd)"
LAUNCHER_SRC="$(cd "$1" && pwd)"
OUT_DIR="$(mkdir -p "$2" && cd "$2" && pwd)"
APP_VERSION="${APP_VERSION:-0.0.0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
MIN_OS="${MIN_OS:-26.0}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
L="$WORK/launcher"

# BAR's artwork (backgrounds, logo) has no license for redistribution, the
# launcher keeps its own; styles and fonts (OFL) are BAR's
mkdir -p "$L/build"
cp -R "$LAUNCHER_SRC/src" "$LAUNCHER_SRC/package.json" "$LAUNCHER_SRC/package-lock.json" "$LAUNCHER_SRC/LICENSE" "$L/"
rsync -a --exclude={/renderer/images,/renderer/spring-icon.png,/renderer/exts/random_background.js,/build,/config.json} \
	"$CHOBBY_SRC/dist_cfg/" "$L/src/"
if [ -n "${CONFIG:-}" ]; then
	cp "$CONFIG" "$L/src/config.json"
else
	python3 "$CHOBBY_SRC/build/mac/make_config.py" "$CHOBBY_SRC/dist_cfg/config.json" "$L/src/config.json"
fi
cp "$CHOBBY_SRC/build/mac/icon.icns" "$L/build/icon.icns"
cp "$CHOBBY_SRC/build/mac/version_info.js" "$L/src/renderer/exts/"
node "$CHOBBY_SRC/build/make_package_json.js" "$L/package.json" "$L/src/config.json" leonseemann/BYAR-Chobby "$APP_VERSION"

node - "$L/package.json" "${UPDATE_URL:-}" "$SIGN_IDENTITY" "$MIN_OS" <<'EOF'
const fs = require('fs');
const [file, updateUrl, identity, minOs] = process.argv.slice(2);
const pkg = JSON.parse(fs.readFileSync(file));
pkg.build.appId = 'io.github.recoil.bar-mac';
pkg.build.productName = 'BAR';
pkg.build.artifactName = 'BAR-${version}.${ext}';
pkg.build.mac = {
	target: ['dmg', 'zip'],
	icon: 'build/icon.icns',
	category: 'public.app-category.games',
	minimumSystemVersion: minOs,
	hardenedRuntime: true,
	identity: identity === '-' ? null : identity.replace(/^Developer ID Application: /, ''),
	extendInfo: { CFBundleDisplayName: 'Beyond All Reason' },
};
if (identity === '-') {
	// electron-builder cannot sign ad-hoc, without an identity it does not sign at all
	pkg.build.afterPack = 'build/adhoc-sign.js';
}
pkg.build.dmg = { title: 'Beyond All Reason' };
pkg.build.publish = updateUrl ? { provider: 'generic', url: updateUrl } : null;
fs.writeFileSync(file, JSON.stringify(pkg, null, 2));
EOF

cat > "$L/build/adhoc-sign.js" <<'EOF'
const { execFileSync } = require('child_process');
exports.default = async (context) => {
	const app = `${context.appOutDir}/${context.packager.appInfo.productFilename}.app`;
	execFileSync('codesign', ['--force', '--deep', '-s', '-', app], { stdio: 'inherit' });
};
EOF

cd "$L"
npm ci --no-audit --no-fund
BUILDER_ARGS=(--mac --arm64 --publish never)
[ "${PACK_ONLY:-0}" = 1 ] && BUILDER_ARGS+=(--dir)
[ "${NOTARIZE:-0}" = 1 ] && BUILDER_ARGS+=(-c.mac.notarize.teamId="$APPLE_TEAM_ID")
npx electron-builder "${BUILDER_ARGS[@]}"
codesign --verify --deep --strict dist/mac-arm64/BAR.app

rm -rf "$OUT_DIR/BAR.app"
cp -R dist/mac-arm64/BAR.app "$OUT_DIR/"
if [ "${PACK_ONLY:-0}" != 1 ]; then
	cp dist/BAR-*.dmg dist/BAR-*.zip "$OUT_DIR/"
	[ ! -f dist/latest-mac.yml ] || cp dist/latest-mac.yml "$OUT_DIR/"
fi
ls "$OUT_DIR"
