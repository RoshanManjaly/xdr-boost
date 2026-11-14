#!/bin/bash
# Build XDRBoost.app (ad-hoc signed) and install it to ~/Applications (override with XDRBOOST_DEST).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/build/XDRBoost.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -o "$APP/Contents/MacOS/XDRBoost" "$DIR"/Sources/*.swift
/usr/bin/plutil -create xml1 "$APP/Contents/Info.plist"
for kv in "CFBundleIdentifier=io.github.roshanmanjaly.xdrboost" "CFBundleName=XDR Boost" "CFBundleExecutable=XDRBoost" \
          "CFBundlePackageType=APPL" "CFBundleShortVersionString=0.1" "LSMinimumSystemVersion=14.0"; do
  /usr/bin/plutil -insert "${kv%%=*}" -string "${kv#*=}" "$APP/Contents/Info.plist"
done
/usr/bin/plutil -insert LSUIElement -bool true "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
DEST="${XDRBOOST_DEST:-$HOME/Applications}"
mkdir -p "$DEST"
rm -rf "$DEST/XDRBoost.app"
cp -R "$APP" "$DEST/"
echo "built: $DEST/XDRBoost.app"
