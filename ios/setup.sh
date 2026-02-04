#!/bin/bash

#
# DigitalFormsApp - Xcode Project Setup Script
#
# This script creates a complete Xcode project from the source files.
# Run this script after cloning the repository.
#
# Usage: ./setup.sh
#

set -e

echo "======================================"
echo "DigitalFormsApp Xcode Setup"
echo "======================================"
echo ""

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed or not in PATH"
    echo "Please install Xcode from the App Store"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n1)
echo "Found: $XCODE_VERSION"
echo ""

# Project settings
PROJECT_NAME="DigitalFormsApp"
BUNDLE_ID="com.yourcompany.digitalforms"
TEAM_ID=""  # Add your team ID for signing
DEPLOYMENT_TARGET="17.0"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/$PROJECT_NAME"
XCODE_PROJECT="$PROJECT_DIR.xcodeproj"

echo "Creating Xcode project..."
echo ""

# Create project directory if needed
mkdir -p "$PROJECT_DIR"

# Copy source files
echo "Copying source files..."
cp -r "$SCRIPT_DIR/DigitalFormsApp/"* "$PROJECT_DIR/" 2>/dev/null || true

# Create Info.plist
echo "Creating Info.plist..."
cat > "$PROJECT_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSCameraUsageDescription</key>
    <string>Camera is used for photos, document scanning, and barcode scanning</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Photo library access is needed to attach images to forms</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Location is captured for audit trail and form verification</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Microphone is used for voice-to-text input</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Speech recognition enables hands-free form filling</string>
    <key>NSFaceIDUsageDescription</key>
    <string>Face ID secures access to your forms</string>
</dict>
</plist>
PLIST

# Create entitlements file
echo "Creating entitlements..."
cat > "$PROJECT_DIR/$PROJECT_NAME.entitlements" << 'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.siri</key>
    <true/>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
ENTITLEMENTS

# Create Core Data model
echo "Creating Core Data model..."
MODEL_DIR="$PROJECT_DIR/$PROJECT_NAME.xcdatamodeld"
MODEL_VERSION="$MODEL_DIR/${PROJECT_NAME}.xcdatamodel"
mkdir -p "$MODEL_VERSION"

cat > "$MODEL_VERSION/contents" << 'COREDATA'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="22522" systemVersion="23F79" minimumToolsVersion="Automatic" sourceLanguage="Swift" usedWithSwiftData="YES" userDefinedModelVersionIdentifier="">
    <entity name="LocalForm" representedClassName="LocalForm" syncable="YES">
        <attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="fieldsData" optional="YES" attributeType="Binary"/>
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="latitude" optional="YES" attributeType="Double" defaultValueString="0.0" usesScalarValueType="YES"/>
        <attribute name="longitude" optional="YES" attributeType="Double" defaultValueString="0.0" usesScalarValueType="YES"/>
        <attribute name="needsSync" optional="YES" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
        <attribute name="remoteId" optional="YES" attributeType="String"/>
        <attribute name="status" optional="YES" attributeType="String" defaultValueString="draft"/>
        <attribute name="submittedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="syncedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="templateId" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="title" optional="YES" attributeType="String"/>
        <attribute name="updatedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    </entity>
    <entity name="LocalTemplate" representedClassName="LocalTemplate" syncable="YES">
        <attribute name="category" optional="YES" attributeType="String"/>
        <attribute name="fieldsData" optional="YES" attributeType="Binary"/>
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="isPublic" optional="YES" attributeType="Boolean" usesScalarValueType="YES"/>
        <attribute name="name" optional="YES" attributeType="String"/>
        <attribute name="remoteId" optional="YES" attributeType="String"/>
        <attribute name="syncedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="templateDescription" optional="YES" attributeType="String"/>
        <attribute name="version" optional="YES" attributeType="Integer 32" defaultValueString="1" usesScalarValueType="YES"/>
    </entity>
    <entity name="LocalSignature" representedClassName="LocalSignature" syncable="YES">
        <attribute name="consentGiven" optional="YES" attributeType="Boolean" usesScalarValueType="YES"/>
        <attribute name="consentText" optional="YES" attributeType="String"/>
        <attribute name="documentHash" optional="YES" attributeType="String"/>
        <attribute name="formId" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="latitude" optional="YES" attributeType="Double" defaultValueString="0.0" usesScalarValueType="YES"/>
        <attribute name="longitude" optional="YES" attributeType="Double" defaultValueString="0.0" usesScalarValueType="YES"/>
        <attribute name="signatureData" optional="YES" attributeType="String"/>
        <attribute name="signatureType" optional="YES" attributeType="String"/>
        <attribute name="signedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="signerEmail" optional="YES" attributeType="String"/>
        <attribute name="signerName" optional="YES" attributeType="String"/>
        <attribute name="signerRole" optional="YES" attributeType="String"/>
        <attribute name="witnessEmail" optional="YES" attributeType="String"/>
        <attribute name="witnessName" optional="YES" attributeType="String"/>
    </entity>
    <entity name="LocalAttachment" representedClassName="LocalAttachment" syncable="YES">
        <attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="fieldId" optional="YES" attributeType="String"/>
        <attribute name="fileData" optional="YES" attributeType="Binary"/>
        <attribute name="fileName" optional="YES" attributeType="String"/>
        <attribute name="fileType" optional="YES" attributeType="String"/>
        <attribute name="fileUrl" optional="YES" attributeType="String"/>
        <attribute name="formId" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="latitude" optional="YES" attributeType="Double" defaultValueString="0.0" usesScalarValueType="YES"/>
        <attribute name="longitude" optional="YES" attributeType="Double" defaultValueString="0.0" usesScalarValueType="YES"/>
        <attribute name="thumbnailData" optional="YES" attributeType="Binary"/>
    </entity>
</model>
COREDATA

# Create version info
cat > "$MODEL_DIR/.xccurrentversion" << 'VERSION'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>_XCCurrentVersionName</key>
    <string>DigitalFormsApp.xcdatamodel</string>
</dict>
</plist>
VERSION

# Create Assets catalog
echo "Creating Assets catalog..."
ASSETS_DIR="$PROJECT_DIR/Assets.xcassets"
mkdir -p "$ASSETS_DIR/AppIcon.appiconset"
mkdir -p "$ASSETS_DIR/AccentColor.colorset"

cat > "$ASSETS_DIR/Contents.json" << 'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cat > "$ASSETS_DIR/AppIcon.appiconset/Contents.json" << 'JSON'
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cat > "$ASSETS_DIR/AccentColor.colorset/Contents.json" << 'JSON'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.898",
          "green" : "0.439",
          "red" : "0.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

# Create project.pbxproj
echo "Creating Xcode project file..."
mkdir -p "$XCODE_PROJECT"

# This is a simplified project file. For a complete setup, use xcodegen or tuist.
cat > "$XCODE_PROJECT/project.pbxproj" << 'PBXPROJ'
// !$*UTF8*$!
{
    archiveVersion = 1;
    classes = {};
    objectVersion = 56;
    objects = {
        /* Note: This is a placeholder project file */
        /* For full functionality, use xcodegen or tuist */
        /* Or create project manually in Xcode */
    };
    rootObject = "";
}
PBXPROJ

echo ""
echo "======================================"
echo "Setup Notes"
echo "======================================"
echo ""
echo "The source files have been organized in: $PROJECT_DIR"
echo ""
echo "To complete setup, please:"
echo ""
echo "1. Open Xcode and create a new iOS App project:"
echo "   - Product Name: $PROJECT_NAME"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Storage: Core Data"
echo ""
echo "2. Delete the auto-generated files and copy in:"
echo "   - All files from $PROJECT_DIR"
echo ""
echo "3. Or use xcodegen (recommended):"
echo "   brew install xcodegen"
echo "   cd $SCRIPT_DIR"
echo "   xcodegen generate"
echo ""
echo "4. Configure signing:"
echo "   - Select your Team ID in project settings"
echo "   - Enable required capabilities"
echo ""
echo "5. Build and run on a physical device"
echo "   (Camera, scanner, and biometrics require real device)"
echo ""
echo "======================================"
echo ""

# Create xcodegen spec
echo "Creating xcodegen project.yml..."
cat > "$SCRIPT_DIR/project.yml" << 'XCODEGEN'
name: DigitalFormsApp
options:
  bundleIdPrefix: com.yourcompany
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"

settings:
  base:
    SWIFT_VERSION: "5.9"
    TARGETED_DEVICE_FAMILY: "1,2"
    INFOPLIST_FILE: DigitalFormsApp/Info.plist

targets:
  DigitalFormsApp:
    type: application
    platform: iOS
    sources:
      - path: DigitalFormsApp
        excludes:
          - "**/.DS_Store"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.digitalforms
        INFOPLIST_FILE: DigitalFormsApp/Info.plist
        CODE_SIGN_ENTITLEMENTS: DigitalFormsApp/DigitalFormsApp.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    entitlements:
      path: DigitalFormsApp/DigitalFormsApp.entitlements
    info:
      path: DigitalFormsApp/Info.plist
XCODEGEN

echo "Created project.yml for xcodegen"
echo ""
echo "Run 'xcodegen generate' to create the Xcode project"
echo ""
echo "Done!"
