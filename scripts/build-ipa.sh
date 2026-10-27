#!/usr/bin/env bash
# Build file .ipa không ký để cài qua SideStore (SideStore tự ký lại bằng Apple ID của máy cài).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xcodegen generate --quiet
xcodebuild \
  -project NersDaily.xcodeproj \
  -scheme NersDaily \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet build

APP="build/DerivedData/Build/Products/Release-iphoneos/NersDaily.app"
STAGE="build/ipa"
rm -rf "$STAGE" && mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Info.plist")"
(cd "$STAGE" && zip -qry "../NersDaily-$VERSION.ipa" Payload)
echo "build/NersDaily-$VERSION.ipa"
