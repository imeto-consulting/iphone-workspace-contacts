#!/usr/bin/env bash
#
# build-testflight.sh — archive WorkspaceContacts and upload it to TestFlight.
#
# Repeatable pipeline for the 90-day TestFlight re-upload cadence. It signs for
# App Store distribution WITHOUT any registered device (archive unsigned, then
# sign at export via -allowProvisioningUpdates) — the correct shape for CI, and
# the reason a physical iPhone is never needed to produce a build.
#
# Signing + upload both go through the Apple Developer account SIGNED INTO XCODE
# (Xcode ▸ Settings ▸ Accounts). That account cloud-signs the distribution cert
# and uploads. We do NOT use an App Store Connect API key: an "App Manager" key
# lacks cloud-signing permission ("Cloud signing permission error"). If you ever
# need a fully headless machine with no signed-in Xcode account, generate an
# *Admin*-role API key and add: -authenticationKeyID/-IssuerID/-Path to the
# export step (Admin is required for cloud signing, App Manager is not enough).
#
# The Team ID is read from the ENVIRONMENT and written only into the gitignored
# app/build/ dir + the gitignored .xcodeproj — never the repo.
#
# Required env:
#   DEVELOPMENT_TEAM   10-char Apple Team ID (e.g. XXXXXXXXXX — never commit the real one).
#
# Optional env:
#   BUILD_NUMBER       CFBundleVersion for this upload. TestFlight requires it to
#                      INCREASE every upload. First shipped build was 1, so the
#                      next must be 2, then 3, … Default: project.yml's value.
#   MARKETING_VERSION  Override the version string (default: project.yml, 0.1.0).
#   DEVELOPER_DIR      Xcode to use. Default: /Applications/Xcode.app/Contents/Developer
#
# Flags:
#   --no-upload        Archive + export a local .ipa only; never upload.
#
# Usage:
#   export DEVELOPMENT_TEAM=XXXXXXXXXX
#   BUILD_NUMBER=2 ./scripts/build-testflight.sh
#
set -euo pipefail

NO_UPLOAD=0
[[ "${1:-}" == "--no-upload" ]] && NO_UPLOAD=1

# --- locate paths (script lives in <repo>/scripts) -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_DIR/app"
BUILD_DIR="$APP_DIR/build"                       # gitignored
ARCHIVE_PATH="$BUILD_DIR/WorkspaceContacts.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTS="$BUILD_DIR/ExportOptions.plist"     # generated fresh each run, gitignored

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# --- preflight -------------------------------------------------------------------
: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to the 10-char Apple Team ID}"
[[ -d "$DEVELOPER_DIR" ]] || { echo "ERROR: DEVELOPER_DIR not found: $DEVELOPER_DIR" >&2; exit 1; }

mkdir -p "$BUILD_DIR"

# Per-build version overrides, passed to xcodebuild as build settings (the Info.plist
# references $(MARKETING_VERSION)/$(CURRENT_PROJECT_VERSION), so these win).
VERSION_SETTINGS=()
[[ -n "${MARKETING_VERSION:-}" ]] && VERSION_SETTINGS+=("MARKETING_VERSION=$MARKETING_VERSION")
[[ -n "${BUILD_NUMBER:-}" ]]      && VERSION_SETTINGS+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")

echo "==> Regenerating Xcode project with team $DEVELOPMENT_TEAM (gitignored .xcodeproj)"
( cd "$APP_DIR" && xcodegen generate --spec project.yml --project . )

# Archive UNSIGNED — no device or profile needed; export signs for distribution.
echo "==> Archiving unsigned (generic/platform=iOS)"
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
  -project "$APP_DIR/WorkspaceContacts.xcodeproj" \
  -scheme WorkspaceContacts \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  ${VERSION_SETTINGS[@]+"${VERSION_SETTINGS[@]}"}
echo "==> Archive OK: $ARCHIVE_PATH"

# --- generate ExportOptions.plist (team ID from env, never committed) ------------
DEST="upload"; [[ $NO_UPLOAD -eq 1 ]] && DEST="export"
cat > "$EXPORT_OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>          <string>app-store-connect</string>
  <key>destination</key>     <string>${DEST}</string>
  <key>teamID</key>          <string>${DEVELOPMENT_TEAM}</string>
  <key>signingStyle</key>    <string>automatic</string>
  <key>uploadSymbols</key>   <true/>
  <key>manageAppVersionAndBuildNumber</key> <false/>
</dict>
</plist>
PLIST

# Export signs the unsigned archive for distribution via the signed-in account.
# -allowProvisioningUpdates creates the Apple Distribution cert + App Store profile
# (and registers the App ID) on first run. destination=upload also uploads it.
echo "==> Exporting (destination=$DEST)"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

if [[ $NO_UPLOAD -eq 1 ]]; then
  echo "==> Local .ipa exported to: $EXPORT_DIR (not uploaded; --no-upload)."
else
  echo "==> Uploaded to App Store Connect. It appears under TestFlight after processing (a few min)."
fi
