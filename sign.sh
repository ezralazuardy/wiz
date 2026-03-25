#!/usr/bin/env bash
set -e

# Code Signing Script for Wiz App
# Usage: ./sign.sh [certificate_name]

APP_BUNDLE="dist/Wiz.app"
CERT_NAME="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔐 Wiz App Code Signing Tool"
echo "============================"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}❌ Error: $APP_BUNDLE not found!${NC}"
    echo "Please build the app first: ./build.sh"
    exit 1
fi

# List available certificates
echo ""
echo "📋 Checking for signing certificates..."
IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null | grep "1\|2\|3\|4\|5" || true)

if [ -z "$CERT_NAME" ]; then
    if [ -z "$IDENTITIES" ]; then
        echo -e "${YELLOW}⚠️  No code signing certificates found!${NC}"
        echo ""
        echo "To create a certificate, you have these options:"
        echo ""
        echo "Option 1: Free Developer Account (for local testing)"
        echo "  - Open Xcode → Preferences → Accounts"
        echo "  - Add your Apple ID"
        echo "  - Xcode will automatically manage signing"
        echo ""
        echo "Option 2: Apple Developer Program ($99/year)"
        echo "  - Required for distribution"
        echo "  - Go to: https://developer.apple.com/programs/"
        echo "  - Create certificate di Apple Developer Portal"
        echo ""
        echo "Option 3: Self-signed certificate (for testing only)"
        echo "  - Open Keychain Access"
        echo "  - Certificate Assistant → Create Certificate"
        echo "  - Name: 'Wiz Developer'"
        echo ""
        exit 1
    else
        echo -e "${GREEN}✓ Found the following certificates:${NC}"
        echo "$IDENTITIES"
        echo ""
        echo "Usage: ./sign.sh 'Certificate Name'"
        echo "Example: ./sign.sh 'Developer ID Application: Your Name'"
        exit 0
    fi
fi

# Sign the app
echo ""
echo "🔏 Signing app with certificate: $CERT_NAME"
echo ""

# Sign the main executable
codesign --force --options runtime --sign "$CERT_NAME" \
    --entitlements "$APP_BUNDLE/Contents/Resources/Wiz.entitlements" \
    "$APP_BUNDLE/Contents/MacOS/Wiz"

# Sign the app bundle
codesign --force --deep --options runtime --sign "$CERT_NAME" \
    --entitlements "$APP_BUNDLE/Contents/Resources/Wiz.entitlements" \
    "$APP_BUNDLE"

# Verify signature
echo ""
echo "🔍 Verifying signature..."
codesign -dvv "$APP_BUNDLE"

echo ""
echo -e "${GREEN}✅ Code signing complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Test the app: open $APP_BUNDLE"
echo "2. For distribution, submit to Apple for notarization:"
echo "   xcrun altool --notarize-app --primary-bundle-id \"org.ezralazuardy.wiz\" \\"
echo "     --username \"your-apple-id@example.com\" --password \"@keychain:AC_PASSWORD\" \\"
echo "     --file dist/Wiz.zip"
echo ""
