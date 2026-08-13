#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is required. Run this script on macOS with Xcode installed." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: XcodeGen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

ACTION="${1:-simulator}"
BUNDLE_ID="${BUNDLE_ID:-studio.abstractpollution.EmojiOverdrive}"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
xcodegen generate --spec project.yml

case "$ACTION" in
  simulator)
    xcodebuild \
      -project EmojiOverdrive.xcodeproj \
      -scheme EmojiOverdrive \
      -configuration Debug \
      -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$DERIVED_DATA" \
      CODE_SIGNING_ALLOWED=NO \
      build
    ;;

  test)
    xcodebuild \
      -project EmojiOverdrive.xcodeproj \
      -scheme EmojiOverdrive \
      -configuration Debug \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
      -derivedDataPath "$DERIVED_DATA" \
      CODE_SIGNING_ALLOWED=NO \
      test
    ;;

  device-check)
    xcodebuild \
      -project EmojiOverdrive.xcodeproj \
      -scheme EmojiOverdrive \
      -configuration Debug \
      -destination 'generic/platform=iOS' \
      -derivedDataPath "$DERIVED_DATA" \
      CODE_SIGNING_ALLOWED=NO \
      build
    ;;

  ipa)
    if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
      echo "error: set DEVELOPMENT_TEAM to your Apple Developer Team ID." >&2
      exit 1
    fi

    export_plist="$(mktemp "${TMPDIR:-/tmp}/emoji-overdrive-export.XXXXXX.plist")"
    cleanup_export_plist() { rm -f "$export_plist"; }
    trap cleanup_export_plist EXIT
    /usr/libexec/PlistBuddy -c "Add :method string debugging" "$export_plist"
    /usr/libexec/PlistBuddy -c "Add :signingStyle string automatic" "$export_plist"
    /usr/libexec/PlistBuddy -c "Add :teamID string $DEVELOPMENT_TEAM" "$export_plist"
    /usr/libexec/PlistBuddy -c "Add :stripSwiftSymbols bool true" "$export_plist"
    /usr/libexec/PlistBuddy -c "Add :compileBitcode bool false" "$export_plist"

    rm -rf "$ROOT_DIR/build/EmojiOverdrive.xcarchive" "$ROOT_DIR/build/export"
    xcodebuild \
      -project EmojiOverdrive.xcodeproj \
      -scheme EmojiOverdrive \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      -archivePath build/EmojiOverdrive.xcarchive \
      -derivedDataPath "$DERIVED_DATA" \
      DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
      PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
      -allowProvisioningUpdates \
      archive

    xcodebuild \
      -exportArchive \
      -archivePath build/EmojiOverdrive.xcarchive \
      -exportPath build/export \
      -exportOptionsPlist "$export_plist" \
      -allowProvisioningUpdates

    IPA_PATH="$(find "$ROOT_DIR/build/export" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
    if [[ -z "$IPA_PATH" ]]; then
      echo "error: export completed without an IPA under build/export." >&2
      exit 1
    fi
    unzip -t "$IPA_PATH" >/dev/null
    echo "IPA verified: $IPA_PATH"
    ;;

  *)
    echo "usage: $0 [simulator|test|device-check|ipa]" >&2
    exit 2
    ;;
esac
