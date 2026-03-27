#!/bin/bash
# build-dmg.sh
# Builds a release archive of Claud-y, creates a signed + notarized .dmg
#
# Prerequisites:
#   - Xcode 16+
#   - Active Apple Developer account (for signing + notarization)
#   - xcrun notarytool configured with an App Store Connect API key
#
# Usage:
#   ./scripts/build-dmg.sh --team-id "YOURTEAMID" --apple-id "you@example.com" --keychain-profile "notarytool-profile"
#   or set TEAM_ID, APPLE_ID, KEYCHAIN_PROFILE as env vars

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
APP_NAME="Claudy"
SCHEME="Claudy"
PROJECT_PATH="../../Claudy/Claudy.xcodeproj"
ARCHIVE_PATH="/tmp/${APP_NAME}.xcarchive"
EXPORT_PATH="/tmp/${APP_NAME}-export"
DMG_NAME="Claud-y.dmg"
DMG_PATH="./${DMG_NAME}"
VOLUME_NAME="Claud-y"

TEAM_ID="${TEAM_ID:-${1:-}}"
APPLE_ID="${APPLE_ID:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notarytool-profile}"   # created via: xcrun notarytool store-credentials

# ── Parse args ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --team-id)         TEAM_ID="$2";         shift 2 ;;
        --apple-id)        APPLE_ID="$2";         shift 2 ;;
        --keychain-profile) KEYCHAIN_PROFILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "${TEAM_ID}" ]]; then
    echo "❌  TEAM_ID is required. Pass --team-id YOURTEAMID or set \$TEAM_ID."
    exit 1
fi

echo "▶  Building ${APP_NAME} (Release)…"

# ── 1. Archive ───────────────────────────────────────────────────────────────
xcodebuild archive \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "platform=macOS" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    ENABLE_HARDENED_RUNTIME=YES \
    | grep -E "error:|warning:|Build succeeded|ARCHIVE SUCCEEDED|ARCHIVE FAILED" || true

echo "✅  Archive created at ${ARCHIVE_PATH}"

# ── 2. Export ────────────────────────────────────────────────────────────────
# Write a temporary ExportOptions.plist
EXPORT_OPTIONS="/tmp/ClaudyExportOptions.plist"
cat > "${EXPORT_OPTIONS}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -exportPath "${EXPORT_PATH}"

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
echo "✅  Export created at ${APP_PATH}"

# ── 3. Create DMG ────────────────────────────────────────────────────────────
echo "▶  Creating DMG…"

# Remove any previous DMG
echo "  [dmg] removing old dmg…"
rm -f "${DMG_PATH}"

# Create a temporary read-write DMG
TEMP_DMG="/tmp/${APP_NAME}-temp.dmg"
echo "  [dmg] removing old temp dmg…"
rm -f "${TEMP_DMG}"

# Detach any leftover mount from a previous run
echo "  [dmg] checking for stale mount…"
if [[ -d "/Volumes/${VOLUME_NAME}" ]]; then
    hdiutil detach "/Volumes/${VOLUME_NAME}" -force -quiet 2>/dev/null || true
fi

echo "  [dmg] creating temp dmg…"
hdiutil create -size 100m -fs HFS+ -volname "${VOLUME_NAME}" "${TEMP_DMG}" -ov -quiet
echo "  [dmg] attaching…"
hdiutil attach "${TEMP_DMG}" -mountpoint "/Volumes/${VOLUME_NAME}" -quiet
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

echo "  [dmg] copying app…"
cp -R "${APP_PATH}" "${MOUNT_POINT}/"

echo "  [dmg] symlinking Applications…"
ln -s /Applications "${MOUNT_POINT}/Applications"

echo "  [dmg] detaching…"
sync
sleep 2
hdiutil detach "${MOUNT_POINT}" -force -quiet

# Convert to read-only compressed DMG
hdiutil convert "${TEMP_DMG}" -format UDZO -o "${DMG_PATH}" -quiet
rm -f "${TEMP_DMG}"

echo "✅  DMG created at ${DMG_PATH}"

# ── 4. Sign the DMG ─────────────────────────────────────────────────────────
echo "▶  Signing DMG…"
SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep "(${TEAM_ID})" | sed 's/.*"\(.*\)".*/\1/' | head -1)
if [[ -z "${SIGN_IDENTITY}" ]]; then
    echo "❌  No 'Developer ID Application' certificate found for team ${TEAM_ID}."
    echo "    Install your Developer ID certificate in Keychain Access and try again."
    exit 1
fi
echo "   Using identity: ${SIGN_IDENTITY}"
codesign --sign "${SIGN_IDENTITY}" \
    --force \
    --timestamp \
    "${DMG_PATH}"
echo "✅  DMG signed"

# ── 5. Notarize ─────────────────────────────────────────────────────────────
echo "▶  Submitting for notarization (this takes a few minutes)…"

xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait \
    --timeout 600

echo "▶  Stapling notarization ticket…"
xcrun stapler staple "${DMG_PATH}"

echo ""
echo "🎉  Done! ${DMG_NAME} is signed, notarized, and ready to ship."
echo "    Drag it into your GitHub Release assets."
