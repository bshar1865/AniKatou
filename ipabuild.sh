#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

WORKING_LOCATION="$(pwd)"
APPLICATION_NAME=AniKatou
BUILD_DIR="$WORKING_LOCATION/build"
DERIVED_DATA_PATH="$BUILD_DIR/DerivedDataApp"
TARGET_APP="$BUILD_DIR/$APPLICATION_NAME.app"
IPA_PATH="$BUILD_DIR/$APPLICATION_NAME.ipa"

mkdir -p "$BUILD_DIR"
rm -rf "$DERIVED_DATA_PATH" "$TARGET_APP" "$BUILD_DIR/Payload" "$IPA_PATH"

run_build() {
    xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
        -scheme "$APPLICATION_NAME" \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -destination 'generic/platform=iOS' \
        clean build \
        CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"
}

echo "Resolving Swift Package Manager dependencies..."
xcodebuild -resolvePackageDependencies -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj"

echo "Building IPA..."
if ! run_build; then
    echo "First build attempt failed. Cleaning derived data and retrying once..."
    rm -rf "$DERIVED_DATA_PATH"
    run_build
fi

DD_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release-iphoneos/$APPLICATION_NAME.app"
cp -R "$DD_APP_PATH" "$TARGET_APP"

codesign --remove "$TARGET_APP" || true
if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi
if [ -e "$TARGET_APP/embedded.mobileprovision" ]; then
    rm -rf "$TARGET_APP/embedded.mobileprovision"
fi

mkdir -p "$BUILD_DIR/Payload"
cp -R "$TARGET_APP" "$BUILD_DIR/Payload/$APPLICATION_NAME.app"
strip "$BUILD_DIR/Payload/$APPLICATION_NAME.app/$APPLICATION_NAME" || true

cd "$BUILD_DIR"
zip -qry "$APPLICATION_NAME.ipa" Payload
rm -rf "$APPLICATION_NAME.app" Payload
