#!/usr/bin/env bash
# Resume the v1.1 ship pipeline after iOS platform support is installed.
#
# Prereqs:
#   1. Xcode → Settings → Platforms → iOS shows "Installed", OR
#      `xcodebuild -downloadPlatform iOS` has finished successfully, OR
#      macOS Tahoe 26.5 update is installed.
#   2. ASC v1.1 already exists (this commit created it; id
#      364f9674-fd15-458a-b036-7b191ddec62b).
#   3. Both subs have their introductoryOffers deleted (this commit did
#      that — 237 rows DELETEd).
#   4. Description + whatsNew + promo already pushed to en-US localization
#      (this commit did that via asc_stage7.py step d).
#
# Steps:
#   a. Clean + archive RelationOS.xcarchive in Release for iphoneos.
#   b. Export App-Store-ready .ipa.
#   c. Upload via xcrun altool. Block until App Store processes it
#      (~5-15 min).
#   d. Find the new build id via /v1/builds?filter[app] and attach it
#      to v1.1 via PATCH /v1/appStoreVersions/.../relationships/build.
#   e. (Manual) re-shoot screenshots from a Release sim/device, upload
#      via `python3 scripts/asc_stage7.py i`.
#   f. (Manual) check the App Privacy nutrition answers in ASC web UI
#      against the new PrivacyInfo.xcprivacy manifest.
#   g. Submit via POST /v1/reviewSubmissions + reviewSubmissionItems.
#
# Hard rule: do NOT run step g until steps e and f are done.

set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE_PATH="$HOME/Developer/relationos/build/RelationOS-1.1.4.xcarchive"
EXPORT_DIR="$HOME/Developer/relationos/build/export-1.1.4"
IPA_PATH="$EXPORT_DIR/RelationOS.ipa"
EXPORT_OPTS="$HOME/Developer/relationos/build/ExportOptions.plist"

echo "==> Step a: archive"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
xcodebuild \
    -project RelationOS.xcodeproj \
    -scheme RelationOS \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    ONLY_ACTIVE_ARCH=NO \
    archive

echo "==> Step b: export ipa"
mkdir -p "$EXPORT_DIR"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTS" \
    -allowProvisioningUpdates

ls -la "$EXPORT_DIR"

echo "==> Step c: upload to App Store Connect"
KEY_ID="${ASC_KEY_ID:-48ZWN983JL}"
ISSUER_ID="${ASC_ISSUER_ID:-730b7d86-5366-48ee-b04f-41a5dc0783cb}"
xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$KEY_ID" \
    --apiIssuer "$ISSUER_ID" \
    --verbose

echo "==> Step d: wait for build to appear + attach to v1.1"
python3 scripts/attach_build_to_v1_1.py
