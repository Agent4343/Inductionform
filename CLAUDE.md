# CLAUDE.md - AI Assistant Guide for DigitalFormsApp

## Project Overview

**DigitalFormsApp** (Inductionform) is a professional iOS/iPadOS application for creating, capturing, signing, and submitting digital forms. Built with SwiftUI and Core Data, it supports offline usage with automatic sync.

> **Status**: Full-featured version with all enterprise capabilities

---

## Repository Structure

```
Inductionform/
├── CLAUDE.md                        # This file - AI assistant guide
├── CoreDataModel.md                 # Core Data entity documentation
├── DigitalFormsApp_Improved.swift   # Basic improved version
├── DigitalFormsApp_Ultimate.swift   # Full-featured ultimate version
└── .git/                            # Git version control
```

---

## Feature Summary

### Core Features
| Feature | Description |
|---------|-------------|
| Document Scanner | VisionKit OCR to scan paper forms |
| Form Builder | Drag-and-drop visual form design |
| PDF Export | Professional multi-page PDFs with sharing |
| Email Integration | Native email composer with attachments |
| Offline Support | Full functionality without internet |
| Signature Capture | PencilKit-based signatures |

### Ultimate Version Features
| Feature | Description |
|---------|-------------|
| Conditional Logic | Show/hide fields based on answers |
| Photo Annotation | Draw arrows, circles, text on photos |
| Voice Input | Speech-to-text for hands-free filling |
| Barcode/QR Scanner | Scan equipment IDs and codes |
| Dashboard & Analytics | Stats, charts, compliance tracking |
| Workflow Automation | Rules, triggers, auto-actions |
| Advanced Signatures | Typed, drawn, initials, witness support |
| Map Integration | View/share captured GPS locations |
| Biometric Lock | Face ID / Touch ID security |
| Auto-save | Automatic draft saving every 30 seconds |
| Progress Indicator | Visual step-by-step progress |
| Siri Shortcuts | Voice-activated form creation |

---

## Architecture

### Main Components

| Component | Purpose |
|-----------|---------|
| `DataController` | Core Data stack, CRUD operations |
| `AuthManager` | Authentication, keychain storage |
| `SyncManager` | Network monitoring, sync |
| `AnalyticsManager` | Dashboard statistics |
| `WorkflowEngine` | Automation rules execution |
| `ConditionalLogicEngine` | Field visibility/requirement logic |
| `VoiceInputManager` | Speech recognition |
| `BiometricAuthManager` | Face ID / Touch ID |
| `AutoSaveManager` | Draft auto-saving |
| `PDFGenerator` | PDF document generation |
| `DocumentTextRecognizer` | OCR processing |

### Key Design Patterns

- **MVVM**: Views observe `@Published` properties
- **Singleton**: Shared instances for managers
- **Dependency Injection**: Environment objects
- **Strategy Pattern**: Conditional logic evaluation
- **Observer Pattern**: Workflow triggers

---

## Field Types (18 Total)

| Type | Icon | Description |
|------|------|-------------|
| text | textformat | Single-line text input |
| textarea | text.alignleft | Multi-line text input |
| number | number | Numeric input |
| email | envelope | Email with validation |
| phone | phone | Phone number input |
| date | calendar | Date picker |
| time | clock | Time picker |
| checkbox | checkmark.square | Boolean toggle |
| yesNo | hand.thumbsup | Yes/No/NA selector |
| dropdown | list.bullet | Single selection |
| multiSelect | checklist | Multiple selection |
| signature | signature | Signature capture |
| photo | camera | Photo attachment |
| location | location | GPS coordinates |
| currency | dollarsign.circle | Currency input |
| rating | star | Star rating (1-5) |
| slider | slider.horizontal.3 | Range slider |
| section | rectangle.split.3x1 | Section header |

---

## Conditional Logic

### Operators
- `equals` / `notEquals`
- `contains`
- `greaterThan` / `lessThan`
- `isEmpty` / `isNotEmpty`

### Actions
- `show` / `hide` - Control field visibility
- `require` / `optional` - Control requirement

### Example
```swift
// If "Incident Type" equals "Injury", show "Medical Treatment" field
FieldCondition(
    sourceFieldId: incidentTypeFieldId,
    operator_: .equals,
    value: "Injury",
    action: .show,
    targetFieldIds: [medicalTreatmentFieldId]
)
```

---

## Workflow Automation

### Triggers
- `formSubmitted` - When form is submitted
- `formApproved` - When form is approved
- `formRejected` - When form is rejected
- `fieldValueChanged` - When specific field changes

### Actions
- `sendEmail` - Send email notification
- `assignApprover` - Auto-assign approver
- `setFieldValue` - Auto-fill field
- `createTask` - Create follow-up task
- `sendNotification` - Push notification
- `webhook` - Call external API

---

## Required Frameworks

```swift
import SwiftUI
import CoreData
import PencilKit
import PhotosUI
import CoreLocation
import PDFKit
import Network
import Security
import VisionKit          // Document scanning
import Vision             // OCR
import MessageUI          // Email
import MapKit             // Maps
import AVFoundation       // Camera, Barcode
import Speech             // Voice input
import LocalAuthentication // Biometrics
import WidgetKit          // Widgets
import Intents            // Siri Shortcuts
import UniformTypeIdentifiers
```

---

## Info.plist Keys Required

```xml
<key>NSCameraUsageDescription</key>
<string>Camera for photos, document scanning, and barcode scanning</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library for attaching images to forms</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location capture for audit trail</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone for voice-to-text input</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Speech recognition for hands-free form filling</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID to secure your forms</string>
```

---

## Development Setup

### Prerequisites
- **Xcode**: 15.0+
- **iOS**: 17.0+
- **Swift**: 5.9+
- **Physical Device**: Required for camera, scanner, biometrics

### Setup Steps
1. Create Xcode project (iOS App, SwiftUI, Core Data)
2. Create `DigitalFormsApp.xcdatamodeld` per `CoreDataModel.md`
3. Add `DigitalFormsApp_Ultimate.swift` to project
4. Add all Info.plist privacy keys
5. Enable capabilities: Push Notifications, Siri
6. Build and run on physical device

---

## Testing Checklist

### Core Features
- [ ] Create form from template
- [ ] Fill all 18 field types
- [ ] Capture signature (drawn, typed, initials)
- [ ] Add and annotate photo
- [ ] Submit and approve form
- [ ] Export and email PDF

### Advanced Features
- [ ] Scan paper document with OCR
- [ ] Test conditional logic (show/hide)
- [ ] Use voice input for text fields
- [ ] Scan barcode/QR code
- [ ] View dashboard analytics
- [ ] Test workflow automation
- [ ] Verify biometric lock
- [ ] Check auto-save functionality
- [ ] Test offline mode and sync

---

## API Configuration

```swift
// In SyncManager
private let baseURL = "https://api.yourbackend.com/v1"

// Endpoints
POST /forms          // Submit form
GET  /forms          // List forms
GET  /templates      // Get templates
POST /webhooks       // Workflow webhooks
```

---

## Security Features

| Feature | Implementation |
|---------|---------------|
| Auth tokens | Keychain storage |
| Offline PIN | Hashed storage |
| Biometric lock | LAContext |
| Session timeout | Configurable |
| Audit trail | All actions logged |

---

## Widget Support

Home screen widget showing:
- Pending form count
- Recent form status
- Quick actions

## Siri Shortcuts

- "Start safety inspection"
- "Show pending approvals"
- "Create new form"

---

## Common Tasks

### Add New Field Type
1. Add case to `FieldType` enum
2. Add `displayName` and `icon`
3. Update `FormFieldView` for input
4. Update `FieldPreview` for builder
5. Update `PDFGenerator` for export

### Add Workflow Action
1. Add case to `WorkflowActionType`
2. Implement in `WorkflowEngine.executeActions()`
3. Add UI in `AddWorkflowRuleView`

### Add Dashboard Metric
1. Add property to `AnalyticsManager`
2. Calculate in `refreshAnalytics()`
3. Add card in `DashboardView`

---

## File Comparison

| Feature | Improved | Ultimate |
|---------|----------|----------|
| Document Scanner | Yes | Yes |
| Form Builder | Yes | Yes |
| PDF Export | Yes | Yes |
| Email | Yes | Yes |
| Conditional Logic | No | Yes |
| Photo Annotation | No | Yes |
| Voice Input | No | Yes |
| Barcode Scanner | No | Yes |
| Dashboard | No | Yes |
| Workflow | No | Yes |
| Biometric Lock | No | Yes |
| Auto-save | No | Yes |
| Maps | No | Yes |
| Widgets | No | Yes |

**Recommendation**: Use `DigitalFormsApp_Ultimate.swift` for full functionality.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Scanner not working | Use physical device |
| Voice input failing | Check microphone permission |
| Biometrics unavailable | Device must support Face/Touch ID |
| Barcode not scanning | Ensure good lighting |
| Workflow not triggering | Check rule is active |
| PDF missing content | Check for nil field values |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-04 | Initial CLAUDE.md |
| 2026-02-04 | Added improved version with scanner, builder, PDF, email |
| 2026-02-04 | Added ultimate version with all features |

---

*Last updated: 2026-02-04*
