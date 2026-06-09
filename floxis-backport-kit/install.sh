#!/usr/bin/env bash
# Installs the Floxis Prebid.js adapter backport into an existing Prebid.js checkout (v8.52+).
# Usage: ./install.sh /path/to/Prebid.js
set -euo pipefail

TARGET="${1:?usage: ./install.sh /path/to/Prebid.js}"
if [[ ! -f "$TARGET/package.json" ]] || ! grep -q '"name": "prebid.js"' "$TARGET/package.json"; then
  echo "error: $TARGET does not look like a Prebid.js checkout" >&2
  exit 1
fi

KIT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$TARGET/libraries/floxisUtils" "$TARGET/modules" "$TARGET/test/spec/modules"
cp "$KIT/modules/floxisBidAdapter.js"                 "$TARGET/modules/"
cp "$KIT/modules/floxisBidAdapter.md"                 "$TARGET/modules/"
cp "$KIT/libraries/floxisUtils/politePixel.js"        "$TARGET/libraries/floxisUtils/"
cp "$KIT/test/spec/modules/floxisBidAdapter_spec.js"  "$TARGET/test/spec/modules/"

PB_VERSION="$(grep -m1 '"version"' "$TARGET/package.json" | sed 's/[^0-9.]*//g')"
echo "Floxis adapter backport installed into Prebid.js v${PB_VERSION}"
echo
echo "Build:  cd $TARGET && npm ci && node_modules/.bin/gulp build --modules=floxisBidAdapter"
echo "        (append your existing module list to --modules, comma-separated)"
echo "        (macOS arm64: PUPPETEER_SKIP_DOWNLOAD=true npm ci)"
echo "Test:   node_modules/.bin/gulp test --nolint --file test/spec/modules/floxisBidAdapter_spec.js"
