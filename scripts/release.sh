#!/bin/bash
set -e

# Jessep Release Script
# Usage: ./scripts/release.sh v1.0.1
#
# This script:
# 1. Updates version in Info.plist
# 2. Builds a release archive (ad-hoc signed)
# 3. Creates a DMG
# 4. Commits the version bump
# 5. Creates and pushes a git tag
# 6. Creates a GitHub release and uploads the DMG

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
INFO_PLIST="$PROJECT_DIR/Jessep/Info.plist"

# Configuration
SCHEME="Jessep"
CONFIGURATION="Release"
APP_NAME="Jessep"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_step() {
    echo -e "\n${BLUE}==>${NC} $1"
}

# Show usage
usage() {
    echo "Usage: $0 <version>"
    echo ""
    echo "Arguments:"
    echo "  version    Version string (e.g., v1.0.1 or 1.0.1)"
    echo ""
    echo "Examples:"
    echo "  $0 v1.0.1"
    echo "  $0 1.2.0"
    echo ""
    echo "Options:"
    echo "  --dry-run  Show what would be done without making changes"
    echo "  --help     Show this help message"
    exit 1
}

# Parse arguments
DRY_RUN=false
VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            echo_error "Unknown option: $1"
            usage
            ;;
        *)
            VERSION="$1"
            shift
            ;;
    esac
done

# Validate version
if [ -z "$VERSION" ]; then
    echo_error "Version is required"
    usage
fi

# Strip 'v' prefix if present for internal use
VERSION_NUM="${VERSION#v}"

# Validate version format (semver)
if ! [[ "$VERSION_NUM" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo_error "Invalid version format: $VERSION_NUM"
    echo_error "Expected format: X.Y.Z (e.g., 1.0.1)"
    exit 1
fi

# Ensure tag has 'v' prefix
VERSION_TAG="v$VERSION_NUM"

echo "========================================="
echo "  Jessep Release Script"
echo "========================================="
echo ""
echo "  Version:  $VERSION_NUM"
echo "  Tag:      $VERSION_TAG"
echo "  Dry run:  $DRY_RUN"
echo ""

# Check requirements
echo_step "Checking requirements..."

if ! command -v xcodebuild &> /dev/null; then
    echo_error "xcodebuild not found. Please install Xcode."
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo_error "GitHub CLI (gh) not found. Install with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo_error "GitHub CLI not authenticated. Run: gh auth login"
    exit 1
fi

# Check for uncommitted changes (skip in dry-run)
if [ "$DRY_RUN" = false ]; then
    if ! git diff --quiet HEAD 2>/dev/null; then
        echo_error "You have uncommitted changes. Please commit or stash them first."
        exit 1
    fi
fi

# Check if tag already exists
if git rev-parse "$VERSION_TAG" &> /dev/null; then
    echo_error "Tag $VERSION_TAG already exists!"
    exit 1
fi

# Check for create-dmg (optional but preferred)
if command -v create-dmg &> /dev/null; then
    USE_CREATE_DMG=true
    echo_info "create-dmg found - will create fancy DMG"
else
    USE_CREATE_DMG=false
    echo_warn "create-dmg not found - will use basic DMG (install with: brew install create-dmg)"
fi

if [ "$DRY_RUN" = true ]; then
    echo_warn "DRY RUN - no changes will be made"
    echo ""
    echo "Would perform:"
    echo "  1. Update Info.plist to version $VERSION_NUM"
    echo "  2. Build release archive"
    echo "  3. Create DMG: Jessep-$VERSION_NUM.dmg"
    echo "  4. Commit: 'Release $VERSION_TAG'"
    echo "  5. Create tag: $VERSION_TAG"
    echo "  6. Push to origin with tags"
    echo "  7. Create GitHub release with DMG"
    exit 0
fi

# Step 1: Update version in Info.plist
echo_step "Updating version to $VERSION_NUM..."

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_NUM" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION_NUM" "$INFO_PLIST"

echo_info "Updated Info.plist"

# Step 2: Clean and build
echo_step "Building release..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the archive
xcodebuild archive \
    -project "$PROJECT_DIR/Jessep.xcodeproj" \
    -scheme "$SCHEME" \
    -archivePath "$BUILD_DIR/Jessep.xcarchive" \
    -configuration "$CONFIGURATION" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "$BUILD_DIR/build.log" | grep -E "(error:|warning:|BUILD|Signing)" || true

# Check if archive was created
if [ ! -d "$BUILD_DIR/Jessep.xcarchive" ]; then
    echo_error "Archive failed. Check $BUILD_DIR/build.log"
    exit 1
fi

# Copy app from archive
APP_PATH="$BUILD_DIR/$APP_NAME.app"
cp -R "$BUILD_DIR/Jessep.xcarchive/Products/Applications/Jessep.app" "$APP_PATH"

# Ad-hoc sign the app
echo_info "Ad-hoc signing app..."
codesign --force --deep --sign - "$APP_PATH"

echo_info "Build complete"

# Step 3: Create DMG
echo_step "Creating DMG..."

DMG_NAME="Jessep-$VERSION_NUM.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

if [ "$USE_CREATE_DMG" = true ]; then
    # Try create-dmg for a nice DMG with background
    create-dmg \
        --volname "Jessep" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "Jessep.app" 150 190 \
        --app-drop-link 450 185 \
        --hide-extension "Jessep.app" \
        "$DMG_PATH" \
        "$APP_PATH" 2>/dev/null || {
            echo_warn "create-dmg failed, using fallback..."
            USE_CREATE_DMG=false
        }
fi

if [ "$USE_CREATE_DMG" = false ]; then
    # Fallback to hdiutil
    TEMP_DMG_DIR="$BUILD_DIR/dmg-staging"
    mkdir -p "$TEMP_DMG_DIR"
    cp -R "$APP_PATH" "$TEMP_DMG_DIR/"
    ln -s /Applications "$TEMP_DMG_DIR/Applications"

    hdiutil create -volname "Jessep" \
        -srcfolder "$TEMP_DMG_DIR" \
        -ov -format UDZO \
        "$DMG_PATH"

    rm -rf "$TEMP_DMG_DIR"
fi

if [ ! -f "$DMG_PATH" ]; then
    echo_error "DMG creation failed"
    exit 1
fi

# Generate checksum
echo_info "Generating checksum..."
cd "$BUILD_DIR"
shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
SHA256=$(cat "$DMG_NAME.sha256" | awk '{print $1}')
echo_info "SHA256: $SHA256"

echo_info "DMG created: $DMG_PATH"

# Step 4: Commit version bump
echo_step "Committing version bump..."

cd "$PROJECT_DIR"
git add "$INFO_PLIST"
git commit -m "Release $VERSION_TAG"

echo_info "Committed version bump"

# Step 5: Create and push tag
echo_step "Creating tag $VERSION_TAG..."

git tag -a "$VERSION_TAG" -m "Release $VERSION_TAG"

echo_info "Tag created"

echo_step "Pushing to origin..."

git push origin main
git push origin "$VERSION_TAG"

echo_info "Pushed to origin"

# Step 6: Create GitHub release
echo_step "Creating GitHub release..."

RELEASE_NOTES="## Jessep $VERSION_TAG

### Installation

1. Download \`$DMG_NAME\` below
2. Open the DMG file
3. Drag Jessep to your Applications folder
4. Launch Jessep from Applications
5. Click the menu bar icon to view usage

### Checksums

\`\`\`
SHA256: $SHA256
\`\`\`

### Requirements

- macOS 13.0 (Ventura) or later
- Claude Code installed and logged in, OR manual token entry
"

gh release create "$VERSION_TAG" \
    --title "Jessep $VERSION_TAG" \
    --notes "$RELEASE_NOTES" \
    "$DMG_PATH" \
    "$BUILD_DIR/$DMG_NAME.sha256"

echo ""
echo "========================================="
echo -e "${GREEN}  Release Complete!${NC}"
echo "========================================="
echo ""
echo "  Version:  $VERSION_NUM"
echo "  Tag:      $VERSION_TAG"
echo "  DMG:      $DMG_PATH"
echo "  SHA256:   $SHA256"
echo ""
echo "  GitHub Release: https://github.com/stackingturtles/jessep/releases/tag/$VERSION_TAG"
echo ""
