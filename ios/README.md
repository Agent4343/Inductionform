# DigitalFormsApp iOS - Complete Setup Guide

Professional iOS/iPadOS application for digital form management with legally binding signatures.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step-by-Step Setup](#step-by-step-setup)
3. [Core Data Model Setup](#core-data-model-setup)
4. [Running the App](#running-the-app)
5. [Apple Developer Account](#apple-developer-account)
6. [Configuration](#configuration)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)
9. [Deployment](#deployment)

---

## Prerequisites

### Required Software

| Software | Version | How to Install |
|----------|---------|----------------|
| macOS | 14.0+ (Sonoma) | System update |
| Xcode | 15.0+ | Mac App Store |
| Homebrew | Latest | See below |
| xcodegen | Latest | `brew install xcodegen` |

### Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install xcodegen

```bash
brew install xcodegen
```

### Verify Installation

```bash
xcode-select --version    # Should show xcode-select version
xcodegen --version        # Should show xcodegen version
```

---

## Step-by-Step Setup

### Step 1: Navigate to iOS Directory

```bash
cd /path/to/Inductionform/ios
```

### Step 2: Create the Core Data Model

**This is the most critical step!** Xcode cannot generate the Core Data model from code alone.

1. Open Xcode
2. Go to **File → New → File** (or press ⌘N)
3. Select **Data Model** under Core Data
4. Name it: `DigitalFormsApp.xcdatamodeld`
5. Save it in: `ios/DigitalFormsApp/Resources/`

Then create the entities as described in [Core Data Model Setup](#core-data-model-setup) below.

### Step 3: Generate Xcode Project

```bash
cd ios
xcodegen generate
```

You should see:
```
Loaded project:
  Name: DigitalFormsApp
  Targets:
    DigitalFormsApp: iOS application
⚙️  Generating project...
⚙️  Writing project...
Created project at /path/to/ios/DigitalFormsApp.xcodeproj
```

### Step 4: Open in Xcode

```bash
open DigitalFormsApp.xcodeproj
```

### Step 5: Select Your Team

1. Click on **DigitalFormsApp** in the project navigator (left sidebar)
2. Select the **DigitalFormsApp** target
3. Go to **Signing & Capabilities** tab
4. Under **Team**, select your Apple Developer account
5. If you don't have one, select **Personal Team** (free, limited features)

### Step 6: Select a Device/Simulator

1. In the toolbar at the top, click the device dropdown
2. Choose either:
   - **iPhone 15 Pro** (Simulator) - for testing without a device
   - **Your iPhone** - for full feature testing (requires developer account)

### Step 7: Build and Run

Press **⌘R** or click the Play button.

---

## Core Data Model Setup

You must manually create the Core Data model in Xcode. This cannot be automated.

### Open the Data Model Editor

1. In Xcode, navigate to `DigitalFormsApp/Resources/`
2. Click on `DigitalFormsApp.xcdatamodeld`
3. You'll see the Core Data model editor

### Create These Entities

#### Entity: FormTemplate

| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| name | String | No |
| category | String | Yes |
| descriptionText | String | Yes |
| fieldsJSON | Binary | Yes |
| isBuiltIn | Boolean | No |
| createdAt | Date | No |
| updatedAt | Date | No |

#### Entity: Form

| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| templateId | UUID | Yes |
| templateName | String | Yes |
| title | String | No |
| status | String | No |
| fieldsJSON | Binary | Yes |
| submittedBy | String | Yes |
| submittedAt | Date | Yes |
| approvedBy | String | Yes |
| approvedAt | Date | Yes |
| rejectedReason | String | Yes |
| latitude | Double | Yes |
| longitude | Double | Yes |
| deviceId | String | Yes |
| syncStatus | String | No |
| serverId | String | Yes |
| createdAt | Date | No |
| updatedAt | Date | No |

#### Entity: Signature

| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| formId | UUID | No |
| fieldId | String | No |
| signatureType | String | No |
| signatureData | Binary | No |
| typedName | String | Yes |
| consentGiven | Boolean | No |
| consentText | String | Yes |
| timestamp | Date | No |
| ipAddress | String | Yes |
| deviceId | String | Yes |
| latitude | Double | Yes |
| longitude | Double | Yes |
| documentHash | String | Yes |
| createdAt | Date | No |

#### Entity: PhotoAttachment

| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| formId | UUID | No |
| fieldId | String | No |
| imageData | Binary | No |
| thumbnailData | Binary | Yes |
| annotationsJSON | Binary | Yes |
| caption | String | Yes |
| latitude | Double | Yes |
| longitude | Double | Yes |
| createdAt | Date | No |

#### Entity: User

| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| email | String | No |
| name | String | Yes |
| role | String | No |
| companyId | String | Yes |
| avatarURL | String | Yes |
| createdAt | Date | No |

### Set Default Values

For Boolean attributes, set default value to `NO` (false).
For status fields, set default value to `draft`.
For syncStatus, set default value to `pending`.

### Save the Model

Press **⌘S** to save.

---

## Running the App

### On Simulator (Limited Features)

```bash
# These features work on simulator:
✅ Form creation and editing
✅ Form templates
✅ Dashboard
✅ Settings
✅ Offline storage
✅ PDF generation (preview only)

# These features require a real device:
❌ Camera / Photo capture
❌ Document scanning
❌ Barcode scanning
❌ Face ID (use Simulated Face ID)
❌ Real GPS location
```

### On Physical Device (Full Features)

1. Connect your iPhone/iPad via USB
2. Trust your Mac on the device if prompted
3. Select your device in Xcode's device dropdown
4. Press **⌘R** to build and run
5. On first run, go to **Settings → General → Device Management** on your device
6. Trust your developer certificate

---

## Apple Developer Account

### Free Account (Personal Team)

- Cost: Free
- Limitations:
  - Apps expire after 7 days
  - Can only install on 3 devices
  - No push notifications
  - No App Store distribution

### Paid Account ($99/year)

- Required for:
  - App Store distribution
  - Push notifications
  - Longer certificate validity
  - TestFlight beta testing

### Enroll at:
https://developer.apple.com/programs/enroll/

---

## Configuration

### Backend URL

Edit `DigitalFormsApp/Services/APIService.swift`:

```swift
struct APIConfig {
    #if DEBUG
    // Local development
    static let baseURL = "http://localhost:3000/api"
    #else
    // Production (your Railway deployment)
    static let baseURL = "https://your-app.railway.app/api"
    #endif
}
```

### Bundle Identifier

Edit `project.yml` before generating:

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.digitalforms
```

Or change it in Xcode after generating the project.

### App Name

Edit `project.yml`:

```yaml
CFBundleDisplayName: YourAppName
```

---

## Testing

### Test Accounts

If your backend is running:

```
Admin: admin@example.com / Admin123!
User:  user@example.com / User1234!
```

### Test Scenarios

| Test | Steps |
|------|-------|
| Create form | Forms tab → + → Select template → Fill fields → Submit |
| Scan document | Scanner tab → Scan → Review OCR → Save |
| Sign form | Open form → Signature field → Draw/Type → Confirm consent |
| Export PDF | Open form → Share → Export PDF |
| Offline mode | Enable Airplane mode → Create form → Disable → Check sync |

### Simulator Tips

**Simulate Face ID:**
1. In Simulator menu: **Features → Face ID → Enrolled**
2. When prompted: **Features → Face ID → Matching Face**

**Simulate Location:**
1. In Simulator menu: **Features → Location → Custom Location**
2. Enter coordinates

**Add Photos to Simulator:**
1. Drag images from Finder onto Simulator
2. They'll appear in Photos app

---

## Troubleshooting

### Build Errors

| Error | Solution |
|-------|----------|
| "No such module 'SwiftUI'" | Clean build: **Product → Clean Build Folder** (⇧⌘K) |
| "Signing certificate" error | Select team in Signing & Capabilities |
| "Core Data model not found" | Create `.xcdatamodeld` file (see Step 2) |
| "Untrusted Developer" | On device: Settings → General → Device Management |

### Runtime Errors

| Error | Solution |
|-------|----------|
| "Failed to load model" | Delete app, reinstall |
| "Network error" | Check backend URL, verify backend is running |
| "Camera not available" | Use physical device, not simulator |
| "Location not available" | Allow location permission, use device for real GPS |

### Common Issues

**App won't install on device:**
1. Check device is trusted
2. Check team is selected
3. Check device is registered with Apple Developer account

**Core Data crashes on launch:**
1. Delete the app from device/simulator
2. Clean build folder (⇧⌘K)
3. Rebuild and run

**Signatures not saving:**
1. Ensure consent checkbox is tapped
2. Check Core Data model has Signature entity

---

## Deployment

### TestFlight (Beta Testing)

1. In Xcode: **Product → Archive**
2. In Organizer: Click **Distribute App**
3. Select **App Store Connect**
4. Upload
5. In App Store Connect: Add testers

### App Store

See `APP_STORE_CHECKLIST.md` in the root directory for full submission checklist.

**Required before submission:**
- Screenshots for all device sizes
- App description and keywords
- Privacy policy URL (use `web/landing/privacy.html`)
- Support URL
- App icon (1024x1024)

---

## Project Structure

```
ios/
├── setup.sh                    # Quick setup script
├── project.yml                 # xcodegen configuration
├── README.md                   # This file
└── DigitalFormsApp/
    ├── App/
    │   └── DigitalFormsApp.swift      # Main app entry point
    ├── Models/
    │   └── CoreDataModel.swift        # Core Data helpers
    ├── Managers/
    │   ├── AuthManager.swift          # Authentication & tokens
    │   ├── DataController.swift       # Core Data stack
    │   └── SyncManager.swift          # Cloud sync logic
    ├── Services/
    │   └── APIService.swift           # Railway API client
    ├── Views/
    │   ├── Forms/
    │   │   ├── FormsListView.swift
    │   │   ├── FormEditorView.swift
    │   │   └── TemplatesListView.swift
    │   ├── Scanner/
    │   │   └── DocumentScannerView.swift
    │   ├── Dashboard/
    │   │   └── DashboardView.swift
    │   ├── Signatures/
    │   │   └── LegalSignatureView.swift
    │   └── Settings/
    │       └── SettingsView.swift
    ├── Templates/
    │   └── BuiltInTemplates.swift     # 10 pre-built templates
    └── Resources/
        ├── Info.plist
        ├── DigitalFormsApp.entitlements
        ├── Assets.xcassets/
        └── DigitalFormsApp.xcdatamodeld  # YOU MUST CREATE THIS
```

---

## Pre-Built Templates

The app includes 10 professional templates:

| Template | Category | Fields | Use Case |
|----------|----------|--------|----------|
| Safety Inspection | Safety | 21 | Daily safety walks |
| Incident Report | Safety | 23 | Accident documentation |
| Work Order | Maintenance | 17 | Repair requests |
| Visitor Sign-In | Administration | 15 | Building access |
| Equipment Checklist | Operations | 23 | Pre-use inspections |
| Time Sheet | HR | 18 | Weekly hours |
| Expense Report | Finance | 15 | Reimbursements |
| Customer Feedback | Customer Service | 14 | Satisfaction surveys |
| Delivery Receipt | Logistics | 19 | Proof of delivery |
| Maintenance Request | Facilities | 15 | Building issues |

---

## Legal Signatures

Signatures are legally binding under Canadian law:

- **Federal**: PIPEDA Part 2, Section 31-47
- **Provincial**: Electronic Transactions Acts (Ontario, BC, Alberta, etc.)

Each signature captures:
- Drawn/typed signature image
- Explicit consent checkbox + text
- SHA-256 hash of form content
- Timestamp (ISO 8601)
- IP address
- Device identifier
- GPS coordinates (if permitted)
- Optional witness signature

---

## Quick Reference

### Keyboard Shortcuts (Xcode)

| Shortcut | Action |
|----------|--------|
| ⌘R | Run |
| ⌘B | Build |
| ⇧⌘K | Clean Build Folder |
| ⌘. | Stop |
| ⌘0 | Toggle Navigator |
| ⌥⌘0 | Toggle Inspector |

### Useful Commands

```bash
# Generate project
xcodegen generate

# Open project
open DigitalFormsApp.xcodeproj

# Clean derived data (fixes weird issues)
rm -rf ~/Library/Developer/Xcode/DerivedData

# List simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot "iPhone 15 Pro"
```

---

## Support

For issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Review Xcode console logs
3. Create issue in repository

---

*Last updated: 2026-02-04*
