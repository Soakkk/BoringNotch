#!/bin/bash
# No Apple account, certificates, provisioning profiles or upstream secrets required.
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_ROOT="${BUILD_ROOT:-$PWD/build/personal}"
mkdir -p "$BUILD_ROOT"
xcodebuild -version
xcodebuild -resolvePackageDependencies -project boringNotch.xcodeproj \
  -scheme boringNotch -clonedSourcePackagesDirPath "$BUILD_ROOT/packages" \
  -onlyUsePackageVersionsFromResolvedFile
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_ROOT/DerivedData" \
  -clonedSourcePackagesDirPath "$BUILD_ROOT/packages" \
  -onlyUsePackageVersionsFromResolvedFile \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= build 2>&1 | tee "$BUILD_ROOT/xcodebuild.log"
APP="$BUILD_ROOT/DerivedData/Build/Products/Release/BoringNotch Personal.app"
test -d "$APP/Contents/XPCServices/BoringNotchXPCHelper.xpc"
lipo "$APP/Contents/MacOS/BoringNotch Personal" -verify_arch arm64 x86_64
lipo "$APP/Contents/XPCServices/BoringNotchXPCHelper.xpc/Contents/MacOS/BoringNotchXPCHelper" -verify_arch arm64 x86_64
ditto -c -k --keepParent "$APP" "$BUILD_ROOT/BoringNotch-Personal-unsigned.zip"
