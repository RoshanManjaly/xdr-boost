#!/bin/bash
# Remove XDR Boost: login item, app, and settings. Run: bash uninstall.sh
set -euo pipefail
APP="${XDRBOOST_DEST:-$HOME/Applications}/XDRBoost.app"

if pgrep -x XDRBoost >/dev/null; then
  osascript -e 'quit app "XDRBoost"' >/dev/null 2>&1 || true   # quitting restores the normal display
  for _ in $(seq 1 50); do pgrep -x XDRBoost >/dev/null || break; sleep 0.1; done
fi
if [ -x "$APP/Contents/MacOS/XDRBoost" ]; then
  perl -e 'alarm 15; exec @ARGV' "$APP/Contents/MacOS/XDRBoost" --unregister || true
fi
rm -rf "$APP"
defaults delete io.github.roshanmanjaly.xdrboost >/dev/null 2>&1 || true
echo "Removed: $APP"
