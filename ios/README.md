# DigitalFormsApp iOS

Professional iOS/iPadOS application for digital form management with legal signatures.

## Features

- **Document Scanner** - Scan paper forms with VisionKit OCR
- **Form Builder** - Drag-and-drop visual form design
- **18 Field Types** - Text, date, signature, photo, location, and more
- **Legal Signatures** - Canadian-compliant (PIPEDA) e-signatures
- **Offline Support** - Full functionality without internet
- **Cloud Sync** - Automatic sync with Railway backend
- **PDF Export** - Professional multi-page PDF generation
- **Dashboard** - Analytics and statistics

## Quick Start

### Option 1: Using xcodegen (Recommended)

```bash
# Install xcodegen
brew install xcodegen

# Generate Xcode project
cd ios
xcodegen generate

# Open project
open DigitalFormsApp.xcodeproj
```

### Option 2: Manual Setup

1. Open Xcode → Create new iOS App project
2. Name: `DigitalFormsApp`
3. Interface: SwiftUI
4. Storage: Core Data
5. Copy all files from `DigitalFormsApp/` into the project
6. Build and run

## Project Structure

```
ios/
├── setup.sh                    # Setup script
├── project.yml                 # xcodegen configuration
├── README.md
└── DigitalFormsApp/
    ├── App/
    │   └── DigitalFormsApp.swift      # Main app entry
    ├── Models/
    │   └── CoreDataModel.swift        # Core Data entities
    ├── Managers/
    │   ├── AuthManager.swift          # Authentication
    │   ├── DataController.swift       # Core Data
    │   └── SyncManager.swift          # Cloud sync
    ├── Services/
    │   └── APIService.swift           # Railway API client
    ├── Views/
    │   ├── Forms/
    │   │   ├── FormsListView.swift    # Form list
    │   │   ├── FormEditorView.swift   # Form editor
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
        ├── Assets.xcassets
        └── DigitalFormsApp.xcdatamodeld
```

## Pre-Built Templates

| Template | Category | Fields |
|----------|----------|--------|
| Safety Inspection | Safety | 21 |
| Incident Report | Safety | 23 |
| Work Order | Maintenance | 17 |
| Visitor Sign-In | Administration | 15 |
| Equipment Checklist | Operations | 23 |
| Time Sheet | HR | 18 |
| Expense Report | Finance | 15 |
| Customer Feedback | Customer Service | 14 |
| Delivery Receipt | Logistics | 19 |
| Maintenance Request | Facilities | 15 |

## Configuration

### Backend URL

Edit `APIService.swift`:

```swift
struct APIConfig {
    #if DEBUG
    static let baseURL = "http://localhost:3000/api"
    #else
    static let baseURL = "https://your-app.railway.app/api"
    #endif
}
```

### Bundle ID

Update in `project.yml` or Xcode:

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.digitalforms
```

## Requirements

- **Xcode**: 15.0+
- **iOS**: 17.0+
- **Swift**: 5.9+
- **Physical Device**: Required for camera, scanner, Face ID

## Capabilities Required

Enable in Xcode → Signing & Capabilities:

- Push Notifications
- Siri (for Siri Shortcuts)

## Privacy Keys (Info.plist)

| Key | Description |
|-----|-------------|
| NSCameraUsageDescription | Photos, scanning, barcodes |
| NSPhotoLibraryUsageDescription | Image attachments |
| NSLocationWhenInUseUsageDescription | GPS for audit trail |
| NSMicrophoneUsageDescription | Voice input |
| NSSpeechRecognitionUsageDescription | Speech-to-text |
| NSFaceIDUsageDescription | Biometric security |

## Legal Signatures

Signatures comply with Canadian law:

- **PIPEDA Part 2** (Federal)
- **Provincial ETAs** (Ontario, BC, Alberta, etc.)

Each signature includes:
- Consent acknowledgment checkbox
- SHA-256 document hash
- Timestamp, IP, device ID, GPS
- Optional witness signature

## Offline Mode

The app works fully offline:

1. Forms saved to Core Data
2. Automatic sync when online
3. Conflict resolution (server wins)
4. Pending sync indicator

## Testing

### Simulator Limitations

| Feature | Simulator | Device |
|---------|-----------|--------|
| Forms | Yes | Yes |
| Camera | No | Yes |
| Document Scanner | No | Yes |
| Face ID | Limited | Yes |
| GPS | Simulated | Yes |

### Test Accounts

```
Admin: admin@example.com / Admin123!
User:  user@example.com / User1234!
```

## Deployment

### TestFlight

1. Archive in Xcode
2. Upload to App Store Connect
3. Invite testers

### App Store

See `APP_STORE_CHECKLIST.md` in root directory.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Scanner not working | Use physical device |
| Core Data errors | Delete app, reinstall |
| Sync failing | Check network, re-login |
| Signatures not saving | Check consent checkbox |

## License

MIT
