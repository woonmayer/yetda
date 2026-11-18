#!/bin/bash
# Diagnoses Yetda's OCR failures (E5RT error 13 on macOS 27).
# Run: curl -sL https://raw.githubusercontent.com/woonmayer/yetda/diag/ocr/scripts/diag/diagnose-ocr.sh | bash
# Writes ~/Desktop/yetda-diag.txt. Reads only; deletes nothing.
BASE=https://raw.githubusercontent.com/woonmayer/yetda/diag/ocr/scripts/diag
TMP="$(mktemp -d)"
OUT="$HOME/Desktop/yetda-diag.txt"
curl -sfL "$BASE/ocr.js" -o "$TMP/ocr.js"
curl -sfL "$BASE/ocr-test.png" -o "$TMP/ocr-test.png"
BID=io.github.woonmayer.yetda
{
  echo "== macOS"; sw_vers
  echo "== chip"; sysctl -n machdep.cpu.brand_string
  echo "== Yetda"
  defaults read /Applications/Yetda.app/Contents/Info.plist CFBundleShortVersionString 2>&1
  codesign -dv /Applications/Yetda.app 2>&1 | grep -E "flags|TeamIdentifier"
  codesign -d --entitlements - /Applications/Yetda.app 2>&1 | tail -n +2
  echo "== Yetda caches"
  for d in "$HOME/Library/Caches/$BID" "$(getconf DARWIN_USER_CACHE_DIR)$BID" "$(getconf DARWIN_USER_TEMP_DIR)$BID"; do
    [ -e "$d" ] && { echo "$d"; find "$d" -maxdepth 3 | head -30; ls -ldO@ "$d"; }
  done
  echo "== OCR outside Yetda (osascript), run 1"
  osascript -l JavaScript "$TMP/ocr.js" "$TMP/ocr-test.png" 2>&1
  echo "== run 2"
  osascript -l JavaScript "$TMP/ocr.js" "$TMP/ocr-test.png" 2>&1
} > "$OUT" 2>&1
rm -rf "$TMP"
cat "$OUT"
echo; echo "Saved: $OUT"
