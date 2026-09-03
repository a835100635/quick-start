#!/bin/bash
# Builds QuickStart.app with the Swift command-line toolchain (no Xcode required).
#   ./build.sh          release build
#   ./build.sh debug    fast build, no optimisation
#   ./build.sh run      build then launch the app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/QuickStart.app"
SDK="$(xcrun --show-sdk-path --sdk macosx)"
MODE="${1:-release}"

MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

OPT="-O"
[ "$MODE" = "debug" ] && OPT="-Onone"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ compiling ($MODE) $MARKETING_VERSION ($BUILD_NUMBER)"
swiftc "$OPT" -parse-as-library -swift-version 5 \
    -target arm64-apple-macosx15.0 \
    -sdk "$SDK" \
    "$ROOT"/Sources/*.swift \
    -o "$APP/Contents/MacOS/QuickStart"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
[ -f "$ROOT/Resources/AppIcon.icns" ] && cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

IDENTITY="${CODESIGN_IDENTITY:--}"
SIGN_OPTS=(--force --sign "$IDENTITY")
[ "$IDENTITY" != "-" ] && SIGN_OPTS+=(--options runtime --timestamp)
codesign "${SIGN_OPTS[@]}" "$APP"
codesign --verify --deep --strict "$APP" && echo "✓ signature valid"

echo "✓ built $APP"

if [ "$MODE" = "run" ] || [ "${2:-}" = "run" ]; then
    pkill -x QuickStart 2>/dev/null || true
    sleep 0.4
    open "$APP"
    echo "✓ launched"
fi
