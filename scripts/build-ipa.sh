#!/usr/bin/env bash
# Builds an unsigned .ipa for SideStore (SideStore re-signs it with the installing Apple ID).
# Optional VERSION and BUILD override the numbers in project.yml; CI passes them from the tag.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xcodegen generate --quiet
xcodebuild \
  -project Medly.xcodeproj \
  -scheme Medly \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  ${VERSION:+MARKETING_VERSION="$VERSION"} ${BUILD:+CURRENT_PROJECT_VERSION="$BUILD"} \
  -quiet build

APP="build/DerivedData/Build/Products/Release-iphoneos/Medly.app"
STAGE="build/ipa"
rm -rf "$STAGE" && mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
# Ad-hoc signatures that carry the entitlements: SideStore reads them to register the App Group shared with the
# widget, then re-signs with the installing Apple ID. The extension is signed before the app that contains it.
codesign --force --sign - --entitlements App/Widget/MedlyWidget.entitlements "$STAGE/Payload/Medly.app/PlugIns/MedlyWidget.appex"
codesign --force --sign - --entitlements App/Medly.entitlements "$STAGE/Payload/Medly.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Info.plist")"
(cd "$STAGE" && zip -qry "../Medly-$VERSION.ipa" Payload)
echo "build/Medly-$VERSION.ipa"
