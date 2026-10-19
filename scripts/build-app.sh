#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

# YETDA_UNIVERSAL=1 builds one binary for Apple silicon and Intel (releases).
if [ "${YETDA_UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN=".build/apple/Products/Release/Yetda"
else
    swift build -c release
    BIN=".build/release/Yetda"
fi

APP="Yetda.app"
BUNDLE_ID="${YETDA_BUNDLE_ID:-io.github.woonmayer.yetda}"
VERSION="$(cat VERSION)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Yetda"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# The /shots skill, offered to coding agents from the app (see SkillInstaller).
mkdir -p "$APP/Contents/Resources/skills/shots"
cp skills/shots/SKILL.md "$APP/Contents/Resources/skills/shots/SKILL.md"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Yetda</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>Yetda</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Code signing. Signing with a stable code-signing identity makes macOS
# permissions (e.g. Screen Recording) persist across rebuilds — TCC keys on the
# signature, not the binary hash. Prefer an explicit identity via
# YETDA_SIGN_ID; otherwise auto-pick the first available code-signing
# identity (by hash, to stay unambiguous). Fall back to ad-hoc if none exist.
SIGN_ID="${YETDA_SIGN_ID:-}"
if [ -z "$SIGN_ID" ]; then
    SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'[ "]+' '/[0-9]+\)/{print $3; exit}')
fi
# YETDA_HARDENED=1 (set by release.sh) adds the hardened runtime and a secure
# timestamp, which notarization requires, and refuses to fall back to ad-hoc.
SIGN_FLAGS=(--force --sign)
if [ "${YETDA_HARDENED:-0}" = "1" ]; then
    SIGN_FLAGS=(--force --options runtime --timestamp --sign)
fi
if [ -n "$SIGN_ID" ] && security find-identity -v -p codesigning 2>/dev/null | grep -qF "$SIGN_ID"; then
    codesign "${SIGN_FLAGS[@]}" "$SIGN_ID" "$APP"
    echo "Built $APP (signed: $SIGN_ID)"
elif [ "${YETDA_HARDENED:-0}" = "1" ]; then
    echo "error: YETDA_HARDENED=1 needs a code-signing identity (YETDA_SIGN_ID); not found" >&2
    exit 1
else
    codesign --force --deep --sign - "$APP"
    echo "Built $APP (ad-hoc — no code-signing identity found; Screen Recording permission will reset on rebuild)"
fi
