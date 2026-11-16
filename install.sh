#!/bin/bash
# Install the latest XDR Boost release:
#   curl -fsSL https://raw.githubusercontent.com/RoshanManjaly/xdr-boost/main/install.sh | bash
# Downloads XDRBoost.zip from GitHub Releases into a temp folder and runs the install.sh inside it.
# Env: XDRBOOST_VERSION=v1.0.1 picks a release (v1.0.1 or later). XDRBOOST_DEST and
#      XDRBOOST_NO_LAUNCH are passed through to the bundled install.sh.
set -euo pipefail
REPO="RoshanManjaly/xdr-boost"
if [ -n "${XDRBOOST_VERSION:-}" ]; then
  URL="https://github.com/$REPO/releases/download/$XDRBOOST_VERSION/XDRBoost.zip"
else
  URL="https://github.com/$REPO/releases/latest/download/XDRBoost.zip"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading $URL"
curl -fsSL -o "$TMP/XDRBoost.zip" "$URL"
ditto -x -k "$TMP/XDRBoost.zip" "$TMP"
bash "$TMP/XDRBoost/install.sh"
