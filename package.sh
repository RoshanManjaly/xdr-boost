#!/bin/bash
# Build XDR Boost and package it as a portable zip: app + install.sh + uninstall.sh + README.
# Output: build/XDRBoost.zip (unzips to a folder named XDRBoost). The name has no version, so
# https://github.com/RoshanManjaly/xdr-boost/releases/latest/download/XDRBoost.zip always works.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/build.sh" --no-install
STAGE="$DIR/build/stage/XDRBoost"
rm -rf "$DIR/build/stage"
mkdir -p "$STAGE"
ditto "$DIR/build/XDRBoost.app" "$STAGE/XDRBoost.app"
cp "$DIR/dist/install.sh" "$DIR/dist/uninstall.sh" "$DIR/dist/README.txt" "$STAGE/"
chmod +x "$STAGE/install.sh" "$STAGE/uninstall.sh"
OUT="$DIR/build/XDRBoost.zip"
rm -f "$OUT"
ditto -c -k --keepParent "$STAGE" "$OUT"
echo "packaged: $OUT ($(du -h "$OUT" | cut -f1))"
