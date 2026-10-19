#!/bin/bash
# Print Casks/yetda.rb for the current VERSION and dmg.
# Usage: scripts/render-cask.sh [release-repo] > Casks/yetda.rb
#   release-repo defaults to woonmayer/yetda (where the dmg is attached).
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
REPO="${1:-woonmayer/yetda}"
SHAFILE="dist/Yetda-$VERSION.dmg.sha256"
[ -f "$SHAFILE" ] || { echo "error: $SHAFILE missing; run scripts/release.sh first" >&2; exit 1; }
SHA="$(cut -d' ' -f1 "$SHAFILE")"

sed -e "s|@VERSION@|$VERSION|g" \
    -e "s|@SHA256@|$SHA|g" \
    -e "s|@RELEASE_REPO@|$REPO|g" \
    packaging/homebrew/yetda.rb.in | grep -v '^# '
