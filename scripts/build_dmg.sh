#!/usr/bin/env bash
set -euo pipefail

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

# Version specification (argument or default to 1.1.0)
VERSION="${1:-1.1.0}"
# Strip leading 'v' if present for filename consistency
VERSION_CLEAN="${VERSION#v}"

APP_NAME="ClaudeUsage"
VOL_NAME="Claude Usage"
BUILD_DIR="${PROJECT_ROOT}/build"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"
STAGING_DIR="${BUILD_DIR}/dmg_staging"
DIST_DIR="${PROJECT_ROOT}/dist"
DMG_NAME="${APP_NAME}-v${VERSION_CLEAN}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

echo "=================================================="
echo " Building ${APP_NAME} v${VERSION_CLEAN} DMG"
echo "=================================================="

# Ensure xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "Error: xcodegen is not installed. Please install it with 'brew install xcodegen'."
    exit 1
fi

# 1. Regenerate Xcode project
echo "==> Regenerating Xcode project with xcodegen..."
xcodegen generate

# 2. Build Release Configuration
echo "==> Building ${APP_NAME} in Release configuration..."
rm -rf "${DERIVED_DATA_DIR}"
xcodebuild build \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES

BUILT_APP="${DERIVED_DATA_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "${BUILT_APP}" ]; then
    echo "Error: Built application not found at ${BUILT_APP}"
    exit 1
fi

echo "==> Verifying signatures and embedded extension..."
codesign --verify --deep --strict "${BUILT_APP}"
echo "    ✓ App signature is valid"

# 3. Stage DMG Contents
echo "==> Preparing DMG staging folder..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
mkdir -p "${DIST_DIR}"

cp -R "${BUILT_APP}" "${STAGING_DIR}/${APP_NAME}.app"

# Create symlink to /Applications for drag-and-drop install
ln -s /Applications "${STAGING_DIR}/Applications"

# 4. Create DMG with hdiutil
echo "==> Creating compressed DMG installer at ${DMG_PATH}..."
rm -f "${DMG_PATH}"

hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

# Clean up staging directory
rm -rf "${STAGING_DIR}"

# 5. Output Results & Checksum
echo "=================================================="
echo " Build & Packaging Successful!"
echo " DMG Location: ${DMG_PATH}"
echo " DMG Size:     $(du -h "${DMG_PATH}" | cut -f1)"
echo " SHA-256:      $(shasum -a 256 "${DMG_PATH}" | cut -d' ' -f1)"
echo "=================================================="
