#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/Closend.app"
ZIP="$ROOT/dist/Closend-0.25.0.zip"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/Closend-release.XXXXXX")"
STAGED_APP="$STAGE/Closend.app"
STAGED_ZIP="$STAGE/Closend-0.25.0.zip"
trap 'rm -rf "$STAGE"' EXIT

cd "$ROOT"
swift build -c release

ICON_SOURCE="$ROOT/Assets/ClosendLogo.png"
test -f "$ICON_SOURCE"

ICONSET="$ROOT/.build/Closend.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
    read -r size name <<< "$spec"
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/$name" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/.build/Closend.icns"
sips -z 36 36 "$ICON_SOURCE" --out "$ROOT/.build/MenuIcon.png" >/dev/null

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$ROOT/.build/release/Closend" "$STAGED_APP/Contents/MacOS/Closend"
cp "$ROOT/Info.plist" "$STAGED_APP/Contents/Info.plist"
cp "$ROOT/.build/Closend.icns" "$STAGED_APP/Contents/Resources/Closend.icns"
cp "$ROOT/.build/MenuIcon.png" "$STAGED_APP/Contents/Resources/MenuIcon.png"
xattr -cr "$STAGED_APP"
codesign --force --deep --sign - "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"
ditto --norsrc --noextattr -c -k --keepParent "$STAGED_APP" "$STAGED_ZIP"

rm -rf "$APP" "$ZIP"
ditto "$STAGED_APP" "$APP"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
xattr -c "$APP"
codesign --verify --deep --strict "$APP"
cp "$STAGED_ZIP" "$ZIP"

echo "$APP"
echo "$ZIP"
