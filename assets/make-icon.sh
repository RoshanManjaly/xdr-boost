#!/bin/bash
# Rebuild assets/AppIcon.icns and assets/icon.png from assets/icon.swift.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
swiftc -O -o "$WORK/icon" "$DIR/icon.swift"
SET="$WORK/AppIcon.iconset"
mkdir "$SET"
for s in 16 32 128 256 512; do
  "$WORK/icon" "$SET/icon_${s}x${s}.png" "$s" >/dev/null
  "$WORK/icon" "$SET/icon_${s}x${s}@2x.png" "$((s * 2))" >/dev/null
done
iconutil -c icns -o "$DIR/AppIcon.icns" "$SET"
"$WORK/icon" "$DIR/icon.png" 512 >/dev/null
echo "wrote $DIR/AppIcon.icns and $DIR/icon.png"
