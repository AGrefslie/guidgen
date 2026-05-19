#!/usr/bin/env bash
#
# One-command release pipeline for GuidGen.
#
#   scripts/release.sh <version> [release-notes-file]
#
# Steps:
#   1. Verify clean git tree on main.
#   2. Bump MARKETING_VERSION + CURRENT_PROJECT_VERSION.
#   3. Archive → export (Developer ID signed).
#   4. Notarize + staple the .app.
#   5. Build, sign, notarize, staple the .dmg.
#   6. Commit version bump, tag v<version>, push.
#   7. Create GitHub Release with the DMG attached.
#
# Requirements:
#   - Developer ID Application cert installed in keychain.
#   - notarytool keychain profile stored as ${NOTARY_PROFILE}.
#   - `gh` authenticated to the repo.

set -euo pipefail

# ---------- config ----------
TEAM_ID="22ADC8SJAT"
SIGNING_IDENTITY="Developer ID Application: Axel Grefslie (${TEAM_ID})"
NOTARY_PROFILE="guidgen-notary"
SCHEME="GuidGen"
PROJECT="GuidGen.xcodeproj"
BUILD_DIR="build"

# ---------- args ----------
if [[ $# -lt 1 ]]; then
  echo "usage: $0 <version> [release-notes-file]" >&2
  echo "       e.g. $0 1.1" >&2
  exit 1
fi
VERSION="$1"
NOTES_FILE="${2:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "error: version must look like 1.0 or 1.0.1, got '$VERSION'" >&2
  exit 1
fi

# ---------- preflight ----------
cd "$(dirname "$0")/.."

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree dirty. Commit or stash first." >&2
  git status --short
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "error: not on main (on '$CURRENT_BRANCH'). Switch to main first." >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -q "${SIGNING_IDENTITY}"; then
  echo "error: signing identity not found in keychain: ${SIGNING_IDENTITY}" >&2
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
  echo "error: notarytool keychain profile '${NOTARY_PROFILE}' missing or invalid." >&2
  echo "       Create with: xcrun notarytool store-credentials ${NOTARY_PROFILE} --apple-id <id> --team-id ${TEAM_ID}" >&2
  exit 1
fi

if ! command -v gh >/dev/null; then
  echo "error: gh CLI not installed" >&2
  exit 1
fi

git tag --list | grep -qx "v${VERSION}" && {
  echo "error: tag v${VERSION} already exists" >&2
  exit 1
}

# ---------- bump version ----------
echo ">>> Bumping version to ${VERSION}"
NEW_BUILD="$(date +%Y%m%d%H%M)"
xcrun agvtool new-marketing-version "${VERSION}" >/dev/null
xcrun agvtool new-version -all "${NEW_BUILD}" >/dev/null

# ---------- clean build dir ----------
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ---------- export options ----------
cat > "${BUILD_DIR}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
EOF

# ---------- archive ----------
echo ">>> Archiving"
xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -configuration Release \
  -archivePath "${BUILD_DIR}/GuidGen.xcarchive" \
  -destination 'generic/platform=macOS' \
  archive | tail -3

# ---------- export ----------
echo ">>> Exporting"
xcodebuild -exportArchive \
  -archivePath "${BUILD_DIR}/GuidGen.xcarchive" \
  -exportPath "${BUILD_DIR}/export" \
  -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" | tail -3

APP="${BUILD_DIR}/export/GuidGen.app"
if [[ ! -d "${APP}" ]]; then
  echo "error: exported app not found at ${APP}" >&2
  exit 1
fi

# ---------- notarize .app ----------
echo ">>> Notarizing app"
ZIP="${BUILD_DIR}/GuidGen.zip"
ditto -c -k --keepParent "${APP}" "${ZIP}"
xcrun notarytool submit "${ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo ">>> Stapling app"
xcrun stapler staple "${APP}"
spctl -a -t exec -vv "${APP}"

# ---------- build DMG ----------
DMG="${BUILD_DIR}/GuidGen-${VERSION}.dmg"
echo ">>> Building DMG: ${DMG}"
hdiutil create -volname "GuidGen" -srcfolder "${APP}" -ov -format UDZO "${DMG}"

echo ">>> Signing DMG"
codesign --sign "${SIGNING_IDENTITY}" "${DMG}"

echo ">>> Notarizing DMG"
xcrun notarytool submit "${DMG}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo ">>> Stapling DMG"
xcrun stapler staple "${DMG}"
spctl -a -t open --context context:primary-signature -vv "${DMG}"

# ---------- commit + tag + push ----------
echo ">>> Committing version bump"
git add "${PROJECT}/project.pbxproj" GuidGen/Info.plist 2>/dev/null || true
git commit -m "Release v${VERSION}" || echo "(no version-bump changes to commit)"

echo ">>> Tagging v${VERSION}"
git tag "v${VERSION}"

echo ">>> Pushing main + tag"
git push origin main
git push origin "v${VERSION}"

# ---------- GitHub Release ----------
echo ">>> Creating GitHub Release"
if [[ -n "${NOTES_FILE}" && -f "${NOTES_FILE}" ]]; then
  gh release create "v${VERSION}" "${DMG}" --title "GuidGen ${VERSION}" --notes-file "${NOTES_FILE}"
else
  gh release create "v${VERSION}" "${DMG}" --title "GuidGen ${VERSION}" --generate-notes
fi

echo ""
echo "Done. v${VERSION} shipped."
echo "  DMG:     ${DMG}"
echo "  Release: $(gh release view "v${VERSION}" --json url -q .url)"
