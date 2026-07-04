#!/usr/bin/env bash
set -euo pipefail

DERIVED_DATA="${DERIVED_DATA:-$RUNNER_TEMP/DerivedData}"
IPA_OUTPUT="${IPA_OUTPUT:-$RUNNER_TEMP/Anygram-tdlib.ipa}"
SOURCE_PACKAGES="${DERIVED_DATA}/SourcePackages"
NCPU="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

XCODE_BUILD_FLAGS=(
  -jobs "$NCPU"
  COMPILER_INDEX_STORE_ENABLE=NO
  SWIFT_INDEX_STORE_ENABLE=NO
)

echo "Resolving Swift packages (derivedDataPath=$DERIVED_DATA)..."
xcodebuild -resolvePackageDependencies \
  -project Anygram.xcodeproj \
  -scheme Anygram \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
  "${XCODE_BUILD_FLAGS[@]}"

echo "Building unsigned Release for iOS (BetterTG-style build, not archive)..."
xcodebuild build \
  -project Anygram.xcodeproj \
  -scheme Anygram \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
  "${XCODE_BUILD_FLAGS[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 \
  ONLY_ACTIVE_ARCH=NO

APP_PATH="$(find "$DERIVED_DATA" -path "*/Build/Products/Release-iphoneos/Anygram.app" -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "::error::Anygram.app not found in $DERIVED_DATA"
  find "$DERIVED_DATA" -name "Anygram.app" -type d || true
  exit 1
fi

echo "Found app bundle: $APP_PATH"

WORK_DIR="$RUNNER_TEMP/ipa-pack"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/Payload"
cp -R "$APP_PATH" "$WORK_DIR/Payload/"

(
  cd "$WORK_DIR"
  zip -qr "$IPA_OUTPUT" Payload
)

echo "IPA written to $IPA_OUTPUT"
ls -lh "$IPA_OUTPUT"
