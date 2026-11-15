#!/bin/bash
# Install XDR Boost into ~/Applications and start it.
# Run from Terminal: bash install.sh   (the app is unsigned, so double-clicking may be blocked)
# Env: XDRBOOST_DEST=<dir> installs elsewhere; XDRBOOST_NO_LAUNCH=1 skips starting it.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${XDRBOOST_DEST:-$HOME/Applications}"
APP="$DEST/XDRBoost.app"

if [ "$(uname -m)" != "arm64" ]; then
  echo "XDR Boost needs an Apple silicon MacBook Pro with an XDR display." >&2
  exit 1
fi
major=$(sw_vers -productVersion | cut -d. -f1)
if [ "$major" -lt 14 ]; then
  echo "XDR Boost needs macOS 14 or later (this Mac: $(sw_vers -productVersion))." >&2
  exit 1
fi

if pgrep -x XDRBoost >/dev/null; then
  osascript -e 'quit app "XDRBoost"' >/dev/null 2>&1 || true
  for _ in $(seq 1 50); do pgrep -x XDRBoost >/dev/null || break; sleep 0.1; done
fi

mkdir -p "$DEST"
rm -rf "$APP"
ditto "$HERE/XDRBoost.app" "$APP"
# A downloaded copy carries Gatekeeper's quarantine flag, which blocks unsigned apps.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
codesign --verify "$APP"

if [ -z "${XDRBOOST_NO_LAUNCH:-}" ]; then
  open "$APP"
  echo "Installed and started: $APP"
  echo "Look for the sun icon in the menu bar (a menu bar manager such as Bartender may hide it)."
else
  echo "Installed: $APP"
fi
