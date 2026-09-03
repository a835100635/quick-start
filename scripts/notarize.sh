#!/bin/bash
# Notarizes and staples the packaged disk image.
#   NOTARY_PROFILE=quickstart ./scripts/notarize.sh [version]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-${MARKETING_VERSION:-1.0.0}}"
DMG="$ROOT/build/QuickStart-${VERSION}.dmg"
PROFILE="${NOTARY_PROFILE:-}"

[ -f "$DMG" ] || {
    echo "no disk image at $DMG — run ./scripts/make-dmg.sh first" >&2
    exit 1
}

[ -n "$PROFILE" ] || {
    echo "error: set NOTARY_PROFILE to a notarytool keychain profile" >&2
    echo "       create one with: xcrun notarytool store-credentials <profile>" >&2
    exit 1
}

echo "→ submitting $DMG for notarization"
xcrun notarytool submit "$DMG" \
    --keychain-profile "$PROFILE" \
    --wait

echo "→ stapling notarization ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "✓ notarized $DMG"
