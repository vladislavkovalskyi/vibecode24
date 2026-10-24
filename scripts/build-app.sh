#!/usr/bin/env bash
# Builds build/Vibecode24.app: a universal (arm64 + x86_64) release binary in an app bundle,
# signed ad hoc.
#
# Usage: scripts/build-app.sh
#
# Environment:
#   VERSION       marketing version (default: contents of ./VERSION, else 0.1.0)
#   BUILD_NUMBER  bundle version (default: git rev-list --count HEAD, else 1)
#   PACKAGE_DIR   Swift package to build (default: repository root)
#   OUTPUT_DIR    where the .app goes (default: <repo>/build)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Vibecode24"
PRODUCT="Vibecode24"
BUNDLE_ID="com.vladyslavkovalskyi.vibecode24"
PACKAGE_DIR="${PACKAGE_DIR:-$REPO_ROOT}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/build}"
ICON_FILE="$REPO_ROOT/Assets/AppIcon.icns"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- Version -----------------------------------------------------------------

if [[ -z "${VERSION:-}" ]]; then
  if [[ -f "$REPO_ROOT/VERSION" ]]; then
    VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"
  fi
fi
VERSION="${VERSION:-0.1.0}"
VERSION="${VERSION#v}"
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}([-+][0-9A-Za-z.-]+)?$ ]] || die "invalid VERSION '$VERSION'"

if [[ -z "${BUILD_NUMBER:-}" ]]; then
  BUILD_NUMBER="$(git -C "$REPO_ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
fi

log "Building $APP_NAME $VERSION ($BUILD_NUMBER)"

# --- Compile -----------------------------------------------------------------

[[ -f "$PACKAGE_DIR/Package.swift" ]] || die "no Package.swift in $PACKAGE_DIR"

BINARY=""
if swift build --package-path "$PACKAGE_DIR" -c release --arch arm64 --arch x86_64 --product "$PRODUCT"; then
  BIN_DIR="$(swift build --package-path "$PACKAGE_DIR" -c release --arch arm64 --arch x86_64 --show-bin-path)"
  BINARY="$BIN_DIR/$PRODUCT"
else
  warn "universal build failed; falling back to a single-architecture build for $(uname -m)."
  warn "the resulting app will only run on $(uname -m) Macs."
  swift build --package-path "$PACKAGE_DIR" -c release --product "$PRODUCT"
  BIN_DIR="$(swift build --package-path "$PACKAGE_DIR" -c release --show-bin-path)"
  BINARY="$BIN_DIR/$PRODUCT"
fi
[[ -x "$BINARY" ]] || die "built binary not found at $BINARY"
log "Binary: $BINARY ($(lipo -archs "$BINARY" 2>/dev/null || echo unknown arch))"

if compgen -G "$BIN_DIR/*.bundle" > /dev/null; then
  warn "SwiftPM resource bundles found in $BIN_DIR; they are not copied into the app."
fi

# --- Bundle ------------------------------------------------------------------

APP="$OUTPUT_DIR/$APP_NAME.app"
log "Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
chmod 755 "$APP/Contents/MacOS/$APP_NAME"

if [[ -f "$ICON_FILE" ]]; then
  cp "$ICON_FILE" "$APP/Contents/Resources/AppIcon.icns"
else
  warn "$ICON_FILE is missing; run 'swift scripts/make-icon.swift'. The app will have a generic icon."
fi

printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleLocalizations</key>
	<array>
		<string>en</string>
		<string>ru</string>
		<string>uk</string>
	</array>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>$BUNDLE_ID</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>vibecode24</string>
			</array>
		</dict>
	</array>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.developer-tools</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>Vibecode24 asks macOS for administrator rights once, to install the rule that lets it toggle sleep.</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>© 2026 Vladyslav Kovalskyi. MIT License.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" > /dev/null

# --- Sign --------------------------------------------------------------------

log "Signing ad hoc"
# Finder info and other extended attributes make codesign refuse the bundle.
xattr -cr "$APP" 2> /dev/null || true
codesign --force --deep --sign - --options runtime --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"

log "Done: $APP"
