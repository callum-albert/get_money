#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="${SDK:-/tmp/sdkbuild/sdk/iPhoneOS27.2.sdk}"
VERSION="${VERSION:-1.0.0}"
DEPLOY="17.0"
[[ -d "$SDK" ]] || { echo "Missing iOS SDK: $SDK" >&2; exit 1; }
BUILD="$(mktemp -d /tmp/today-earnings.XXXXXX)"
trap 'rm -rf "$BUILD"' EXIT
APP="$BUILD/Payload/TodayEarnings.app"
EXT="$APP/PlugIns/EarningsWidgetExtension.appex"
mkdir -p "$EXT" "$BUILD/modules" "$ROOT/build"
FLAGS=(-target "arm64-apple-ios$DEPLOY" -sdk "$SDK" -swift-version 5 -O -whole-module-optimization)
echo '==> Compile EarningsCore (static)'
swiftc "${FLAGS[@]}" -parse-as-library -module-name EarningsCore \
  -emit-module -emit-module-path "$BUILD/modules/EarningsCore.swiftmodule" \
  -emit-object "$ROOT/Sources/EarningsCore/Earnings.swift" -o "$BUILD/EarningsCore.o"
echo '==> Compile App'
swiftc "${FLAGS[@]}" -parse-as-library -I "$BUILD/modules" \
  "$ROOT"/App/*.swift "$BUILD/EarningsCore.o" -o "$APP/TodayEarnings"
echo '==> Compile Widget'
swiftc "${FLAGS[@]}" -parse-as-library -application-extension -I "$BUILD/modules" \
  "$ROOT/Widget/EarningsWidget.swift" "$ROOT/App/SharedStore.swift" "$BUILD/EarningsCore.o" \
  -Xlinker -e -Xlinker _NSExtensionMain -o "$EXT/EarningsWidgetExtension"
echo '==> Bundle metadata'
python3 "$ROOT/Scripts/package.py" metadata "$APP" "$VERSION" "$DEPLOY"
echo '==> Ad-hoc sign (requires re-signing for installation)'
xattr -cr "$APP"
codesign --force --sign - --timestamp=none --entitlements "$ROOT/Configuration/App.entitlements" "$EXT"
codesign --force --sign - --timestamp=none --entitlements "$ROOT/Configuration/App.entitlements" "$APP"
codesign --verify --strict "$EXT"
codesign --verify --strict "$APP"
echo '==> Package and verify'
python3 "$ROOT/Scripts/package.py" archive "$BUILD/Payload" "$ROOT/build/today-earnings-$VERSION.ipa"
(cd "$ROOT/build" && shasum -a 256 "today-earnings-$VERSION.ipa" > "today-earnings-$VERSION.ipa.sha256")
echo "Done: $ROOT/build/today-earnings-$VERSION.ipa"
