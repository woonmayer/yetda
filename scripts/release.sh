#!/bin/bash
# Build, sign (Developer ID + hardened runtime), notarize and staple Yetda,
# then package it as a notarized dmg in dist/.
#
# Needs a Mac with Xcode and:
#   YETDA_SIGN_ID   "Developer ID Application: Your Name (TEAMID)"
# and notary credentials, either
#   YETDA_NOTARY_PROFILE   a keychain profile saved with
#                          `xcrun notarytool store-credentials`
# or an App Store Connect API key (what CI uses):
#   NOTARY_KEY_ID, NOTARY_ISSUER_ID, NOTARY_KEY_PATH (path to AuthKey_XXXX.p8)
#
# Output: dist/Yetda.dmg (stable name, for /releases/latest/download/Yetda.dmg),
#         dist/Yetda-<version>.dmg and dist/Yetda-<version>.dmg.sha256
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
: "${YETDA_SIGN_ID:?set YETDA_SIGN_ID to your Developer ID Application identity}"

case "$YETDA_SIGN_ID" in
    *"Developer ID Application"*|[0-9A-F][0-9A-F][0-9A-F][0-9A-F]*) ;;
    *) echo "error: YETDA_SIGN_ID must be a Developer ID Application identity (got: $YETDA_SIGN_ID)" >&2; exit 1 ;;
esac

if [ -n "${YETDA_NOTARY_PROFILE:-}" ]; then
    NOTARY_AUTH=(--keychain-profile "$YETDA_NOTARY_PROFILE")
elif [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_ISSUER_ID:-}" ] && [ -n "${NOTARY_KEY_PATH:-}" ]; then
    NOTARY_AUTH=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
else
    echo "error: set YETDA_NOTARY_PROFILE, or NOTARY_KEY_ID + NOTARY_ISSUER_ID + NOTARY_KEY_PATH" >&2
    exit 1
fi

notarize() {
    echo "Notarizing $1 …"
    xcrun notarytool submit "$1" "${NOTARY_AUTH[@]}" --wait --timeout 30m
    xcrun stapler staple "$2"
}

# 1. App: universal binary, Developer ID, hardened runtime.
YETDA_UNIVERSAL=1 YETDA_HARDENED=1 ./scripts/build-app.sh
codesign --verify --strict --verbose=2 Yetda.app
codesign -d --verbose=2 Yetda.app 2>&1 | grep -q 'flags=.*runtime' \
    || { echo "error: hardened runtime missing" >&2; exit 1; }

# 2. Notarize the app itself, so the stapled ticket travels inside the dmg.
rm -rf dist && mkdir -p dist
ditto -c -k --keepParent Yetda.app dist/Yetda-notarize.zip
notarize dist/Yetda-notarize.zip Yetda.app
rm dist/Yetda-notarize.zip

# 3. Disk image with the app and an Applications shortcut.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R Yetda.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="dist/Yetda-$VERSION.dmg"
hdiutil create -volname "Yetda $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$YETDA_SIGN_ID" "$DMG"
notarize "$DMG" "$DMG"

# 4. Check what Gatekeeper will say on someone else's Mac.
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
spctl --assess --type execute --verbose=2 Yetda.app

cp "$DMG" dist/Yetda.dmg
(cd dist && shasum -a 256 "Yetda-$VERSION.dmg" > "Yetda-$VERSION.dmg.sha256")
echo "Done: $DMG ($(cut -d' ' -f1 "dist/Yetda-$VERSION.dmg.sha256"))"
