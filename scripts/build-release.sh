#!/bin/bash
set -e

# Jessep Release Build Script
# This script builds, signs, notarizes, and creates a DMG for distribution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Jessep.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/Jessep.app"

# Configuration
SCHEME="Jessep"
CONFIGURATION="Release"
BUNDLE_ID="com.stackingturtles.Jessep"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for required tools
check_requirements() {
    echo_info "Checking requirements..."

    if ! command -v xcodebuild &> /dev/null; then
        echo_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi

    if ! command -v create-dmg &> /dev/null; then
        echo_warn "create-dmg not found. Install with: brew install create-dmg"
        echo_warn "DMG creation will be skipped."
        CREATE_DMG=false
    else
        CREATE_DMG=true
    fi
}

# Clean previous build
clean_build() {
    echo_info "Cleaning previous build..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

# Build archive
build_archive() {
    echo_info "Building archive..."
    xcodebuild archive \
        -project "$PROJECT_DIR/Jessep.xcodeproj" \
        -scheme "$SCHEME" \
        -archivePath "$ARCHIVE_PATH" \
        -configuration "$CONFIGURATION" \
        CODE_SIGN_STYLE=Automatic \
        | xcpretty || xcodebuild archive \
        -project "$PROJECT_DIR/Jessep.xcodeproj" \
        -scheme "$SCHEME" \
        -archivePath "$ARCHIVE_PATH" \
        -configuration "$CONFIGURATION" \
        CODE_SIGN_STYLE=Automatic
}

# Export archive
export_archive() {
    echo_info "Exporting archive..."

    # Create ExportOptions.plist
    cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"
}

# Notarize app (requires Apple Developer account)
notarize_app() {
    echo_info "Notarizing app..."

    # Check if credentials are available
    if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ]; then
        echo_warn "APPLE_ID or TEAM_ID not set. Skipping notarization."
        echo_warn "Set these environment variables to enable notarization:"
        echo_warn "  export APPLE_ID='your@email.com'"
        echo_warn "  export TEAM_ID='XXXXXXXXXX'"
        return 0
    fi

    # Create zip for notarization
    ditto -c -k --keepParent "$APP_PATH" "$BUILD_DIR/Jessep.zip"

    # Submit for notarization
    xcrun notarytool submit "$BUILD_DIR/Jessep.zip" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "@keychain:AC_PASSWORD" \
        --wait

    # Staple the ticket
    xcrun stapler staple "$APP_PATH"

    echo_info "Notarization complete!"
}

# Create DMG
create_dmg() {
    if [ "$CREATE_DMG" = false ]; then
        echo_warn "Skipping DMG creation."
        return 0
    fi

    echo_info "Creating DMG..."

    # Get version from Info.plist
    VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)

    create-dmg \
        --volname "Jessep" \
        --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "Jessep.app" 150 190 \
        --app-drop-link 450 185 \
        --hide-extension "Jessep.app" \
        "$BUILD_DIR/Jessep-$VERSION.dmg" \
        "$EXPORT_PATH/" || {
            # Fallback to simple DMG if create-dmg fails
            echo_warn "create-dmg failed, using fallback method..."
            hdiutil create -volname "Jessep" -srcfolder "$EXPORT_PATH" -ov -format UDZO "$BUILD_DIR/Jessep-$VERSION.dmg"
        }

    echo_info "DMG created: $BUILD_DIR/Jessep-$VERSION.dmg"
}

# Generate checksums
generate_checksums() {
    echo_info "Generating checksums..."

    cd "$BUILD_DIR"
    for file in *.dmg; do
        if [ -f "$file" ]; then
            shasum -a 256 "$file" > "$file.sha256"
            echo_info "SHA256: $(cat "$file.sha256")"
        fi
    done
}

# Main
main() {
    echo "========================================="
    echo "  Jessep Release Build Script"
    echo "========================================="
    echo

    check_requirements
    clean_build
    build_archive
    export_archive
    notarize_app
    create_dmg
    generate_checksums

    echo
    echo "========================================="
    echo -e "${GREEN}  Build Complete!${NC}"
    echo "========================================="
    echo
    echo "Output files:"
    ls -la "$BUILD_DIR"/*.dmg 2>/dev/null || echo "  (No DMG files)"
    ls -la "$EXPORT_PATH"/*.app 2>/dev/null || echo "  (No app bundle)"
}

main "$@"
