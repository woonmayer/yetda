#!/bin/bash
# Regenerates assets/AppIcon.icns and assets/icon.png from make-icon.swift.
set -euo pipefail

cd "$(dirname "$0")/.."

swift scripts/make-icon.swift assets
iconutil -c icns assets/AppIcon.iconset -o assets/AppIcon.icns
rm -rf assets/AppIcon.iconset
echo "Wrote assets/AppIcon.icns and assets/icon.png"
