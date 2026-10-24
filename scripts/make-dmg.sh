#!/usr/bin/env bash
# Wraps build/Vibecode24.app in dist/Vibecode24-<version>.dmg with an Applications link.
#
# Usage: scripts/make-dmg.sh [--skip-build]
#
#   --skip-build   use the existing build/Vibecode24.app instead of running build-app.sh
#
# Uses create-dmg (brew install create-dmg) for the styled window when it is available,
# and plain hdiutil otherwise. create-dmg lays out the window through Finder AppleScript;
# if that step fails or hangs (no Automation permission, headless session), the script
# retries without the Finder step.
#
# Environment:
#   DMG_LAYOUT_TIMEOUT  seconds to wait for create-dmg before giving up on it (default 300)
#   Everything build-app.sh reads (VERSION, BUILD_NUMBER, PACKAGE_DIR, OUTPUT_DIR).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Vibecode24"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/build}"
DIST_DIR="$REPO_ROOT/dist"
BACKGROUND="$REPO_ROOT/Assets/dmg-background.tiff"
VOLUME_ICON="$REPO_ROOT/Assets/AppIcon.icns"
LAYOUT_TIMEOUT="${DMG_LAYOUT_TIMEOUT:-300}"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

if [[ $SKIP_BUILD -eq 0 ]]; then
  "$SCRIPT_DIR/build-app.sh"
fi

APP="$OUTPUT_DIR/$APP_NAME.app"
[[ -d "$APP" ]] || die "$APP not found; run scripts/build-app.sh first"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST_DIR/$APP_NAME-$VERSION.dmg"
mkdir -p "$DIST_DIR"
rm -f "$DMG"

# Staging folder holding only the app; the Applications link is added by the tool.
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/vibecode24-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT
ditto "$APP" "$STAGING/$APP_NAME.app"
# Folders synced by iCloud Drive (File Provider) add Finder info to bundles, which
# `codesign --verify --strict` rejects; ship the copy without extended attributes.
xattr -cr "$STAGING/$APP_NAME.app" 2> /dev/null || true
codesign --verify --deep --strict "$STAGING/$APP_NAME.app" || die "the app's signature does not verify"

# Detaches and deletes create-dmg's read-write scratch images left behind by a killed run.
cleanup_scratch_images() {
  local rw dev
  for rw in "$DIST_DIR"/rw.*."$APP_NAME-$VERSION.dmg"; do
    [[ -e "$rw" ]] || continue
    dev="$(hdiutil info | awk -v img="$rw" '
      /^image-path/ { sub(/^image-path *: */, ""); current = $0 }
      /^\/dev\/disk[0-9]+[ \t]/ && current == img { print $1; exit }')"
    if [[ -n "$dev" ]]; then
      hdiutil detach "$dev" -force > /dev/null 2>&1 || true
    fi
    rm -f "$rw"
  done
}

# Runs create-dmg with a watchdog; returns create-dmg's status, or 124 on timeout.
run_create_dmg() {
  local args=(
    --volname "$APP_NAME"
    --window-pos 200 120
    --window-size 660 400
    --icon-size 128
    --text-size 13
    --icon "$APP_NAME.app" 165 190
    --hide-extension "$APP_NAME.app"
    --app-drop-link 495 190
  )
  [[ -f "$BACKGROUND" ]] && args+=(--background "$BACKGROUND")
  [[ -f "$VOLUME_ICON" ]] && args+=(--volicon "$VOLUME_ICON")
  if create-dmg --help 2>/dev/null | grep -q -- '--no-internet-enable'; then
    args+=(--no-internet-enable)
  fi
  args+=("$@" "$DMG" "$STAGING")

  create-dmg "${args[@]}" &
  local pid=$! waited=0
  while kill -0 "$pid" 2> /dev/null; do
    if (( waited >= LAYOUT_TIMEOUT )); then
      warn "create-dmg did not finish in ${LAYOUT_TIMEOUT}s; stopping it."
      pkill -TERM -P "$pid" 2> /dev/null || true
      kill -TERM "$pid" 2> /dev/null || true
      wait "$pid" 2> /dev/null || true
      cleanup_scratch_images
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  local status=0
  wait "$pid" || status=$?
  return $status
}

make_with_hdiutil() {
  log "Creating the disk image with hdiutil (no custom window layout)"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" > /dev/null
}

if command -v create-dmg > /dev/null 2>&1; then
  log "Creating the disk image with create-dmg"
  status=0
  run_create_dmg || status=$?
  if [[ $status -ne 0 ]]; then
    warn "create-dmg failed (status $status), most likely at the Finder layout step."
    warn "retrying without the Finder layout (--skip-jenkins): no background or icon positions."
    cleanup_scratch_images
    rm -f "$DMG"
    status=0
    run_create_dmg --skip-jenkins || status=$?
    if [[ $status -ne 0 ]]; then
      warn "create-dmg failed again (status $status); falling back to hdiutil."
      cleanup_scratch_images
      rm -f "$DMG"
      make_with_hdiutil
    fi
  fi
else
  warn "create-dmg not found (brew install create-dmg); the image will have no custom layout."
  make_with_hdiutil
fi

[[ -f "$DMG" ]] || die "disk image was not created"
hdiutil verify -quiet "$DMG"

SHA256="$(shasum -a 256 "$DMG" | awk '{print $1}')"
printf '\n%s\n' "$DMG"
printf 'SHA-256: %s\n' "$SHA256"
