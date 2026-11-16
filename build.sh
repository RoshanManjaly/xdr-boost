#!/bin/bash
# Build XDRBoost.app (ad-hoc signed) and install it to ~/Applications (override with XDRBOOST_DEST).
# --no-install builds build/XDRBoost.app only. The app registers itself as a login item on first launch.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/build/XDRBoost.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target arm64-apple-macos14.0 -o "$APP/Contents/MacOS/XDRBoost" "$DIR"/Sources/*.swift
cp "$DIR/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -create xml1 "$APP/Contents/Info.plist"
for kv in "CFBundleIdentifier=io.github.roshanmanjaly.xdrboost" "CFBundleName=XDR Boost" "CFBundleExecutable=XDRBoost" \
          "CFBundlePackageType=APPL" "CFBundleShortVersionString=1.0" "CFBundleVersion=1" "LSMinimumSystemVersion=14.0" \
          "CFBundleIconFile=AppIcon"; do
  /usr/bin/plutil -insert "${kv%%=*}" -string "${kv#*=}" "$APP/Contents/Info.plist"
done
/usr/bin/plutil -insert LSUIElement -bool true "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
[ "${1:-}" = "--no-install" ] && { echo "built: $APP"; exit 0; }
DEST="${XDRBOOST_DEST:-$HOME/Applications}"
mkdir -p "$DEST"
rm -rf "$DEST/XDRBoost.app"
cp -R "$APP" "$DEST/"
echo "built: $DEST/XDRBoost.app"
