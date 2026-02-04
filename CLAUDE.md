# CLAUDE.md - AI Assistant Guide for DigitalFormsApp

## Project Overview

**DigitalFormsApp** (Inductionform) is an iOS/iPadOS application for creating, capturing, signing, and submitting digital forms. Built with SwiftUI and Core Data, it supports offline usage with automatic sync when online.

> **Status**: Active development - Improved version with document scanning and enhanced form builder

---

## Repository Structure

```
Inductionform/
├── CLAUDE.md                        # This file - AI assistant guide
├── CoreDataModel.md                 # Core Data entity documentation
├── DigitalFormsApp_Improved.swift   # Main app source code (single file)
└── .git/                            # Git version control
```

---

## Key Features

### 1. Document Scanner
- **VisionKit Integration**: Scan paper forms using the device camera
- **OCR Text Recognition**: Automatically detect field labels from scanned documents
- **Smart Field Type Detection**: Suggests appropriate field types based on label text
- **Edit & Refine**: Modify detected fields before creating template

### 2. Improved Form Builder
- **Visual Drag-and-Drop**: Reorder fields by dragging
- **Field Palette**: Quick access to all field types
- **Live Preview**: See how fields will appear
- **Quick Actions**: Fast buttons to add common field types
- **18 Field Types**: text, number, date, time, email, phone, signature, photo, etc.

### 3. PDF Export (Fixed)
- **Professional Layout**: Multi-page support with proper pagination
- **Complete Content**: Includes all fields, signatures, and attachments
- **Share Sheet**: Native iOS sharing to any app
- **Save to Files**: Export to device or cloud storage
- **Print Support**: Direct printing capability

### 4. Email Function (Fixed)
- **MFMailComposeViewController**: Native email composer
- **PDF Attachment**: Automatically attaches generated PDF
- **Pre-filled Content**: Subject and body with form details

### 5. Additional Features
- **Offline Support**: Full functionality without internet
- **Auto-Sync**: Syncs when connection restored
- **Signature Capture**: PencilKit-based signature pad
- **Photo Attachments**: Camera and photo library support
- **GPS Location**: Automatic location capture
- **Approval Workflow**: Submit, approve, reject forms

---

## Architecture

### Main Components

| Component | Purpose |
|-----------|---------|
| `DataController` | Core Data stack management, CRUD operations |
| `AuthManager` | User authentication, keychain storage |
| `SyncManager` | Network monitoring, data synchronization |
| `PDFGenerator` | PDF document generation |
| `DocumentTextRecognizer` | OCR processing for scanned documents |

### Data Flow

```
User Input → SwiftUI Views → DataController → Core Data
                                    ↓
                              SyncManager → Backend API
```

### Key Design Patterns

- **MVVM**: Views observe `@Published` properties
- **Singleton**: Shared instances for controllers
- **Dependency Injection**: Environment objects for managers

---

## Core Data Entities

| Entity | Purpose |
|--------|---------|
| `User` | User accounts and profiles |
| `FormTemplate` | Reusable form templates |
| `TemplateField` | Field definitions in templates |
| `FormEntity` | Filled-out form instances |
| `FormField` | Field values in forms |
| `Signature` | Captured signatures |
| `Attachment` | Photo attachments |
| `Approval` | Approval decisions |

See `CoreDataModel.md` for complete schema documentation.

---

## Development Setup

### Prerequisites

- **Xcode**: 15.0 or later
- **iOS Deployment Target**: iOS 17.0+
- **Swift**: 5.9+

### Required Frameworks

```swift
import SwiftUI
import CoreData
import PencilKit
import PhotosUI
import CoreLocation
import PDFKit
import Network
import Security
import VisionKit      // Document scanning
import Vision         // OCR
import MessageUI      // Email
import UniformTypeIdentifiers
```

### Setup Steps

1. Create new Xcode project (iOS App, SwiftUI)
2. Create Core Data model `DigitalFormsApp.xcdatamodeld`
3. Add entities as documented in `CoreDataModel.md`
4. Replace generated Swift files with `DigitalFormsApp_Improved.swift`
5. Add required capabilities in Xcode:
   - Camera Usage
   - Photo Library Usage
   - Location When In Use

### Info.plist Keys Required

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to capture photos and scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is needed to attach photos to forms</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is captured for audit purposes when creating forms</string>
```

---

## Code Conventions

### Swift Style

- **Naming**: camelCase for properties/methods, PascalCase for types
- **MARK Comments**: Organize code sections with `// MARK: -`
- **Access Control**: Use `private` for internal implementation
- **Optionals**: Prefer optional binding over force unwrapping

### SwiftUI Patterns

```swift
// View structure
struct MyView: View {
    // State
    @State private var value = ""
    @EnvironmentObject var manager: Manager

    // Body
    var body: some View {
        // Content
    }

    // MARK: - Subviews
    private var subview: some View { ... }

    // MARK: - Actions
    private func action() { ... }
}
```

### Core Data Operations

- Always use `DataController.shared` for operations
- Call `save()` after modifications
- Use `@FetchRequest` in views for automatic updates

---

## Common Tasks

### Add a New Field Type

1. Add case to `FieldType` enum
2. Add `displayName` and `icon` computed properties
3. Update `FormFieldView` for input rendering
4. Update `FieldPreview` for builder preview
5. Update `PDFGenerator` if special rendering needed

### Add a New Template Category

1. Add to `categories` array in `ImprovedFormBuilderView`
2. Add to `categories` array in `ScanToFormView`
3. Update `templateIcon` in `TemplateRowView` if custom icon needed

### Modify PDF Layout

1. Edit `PDFGenerator.generatePDF(for:)` method
2. Update page dimensions, margins, fonts as needed
3. Test with forms containing many fields/signatures

---

## Testing

### Manual Testing Checklist

- [ ] Create form from template
- [ ] Fill all field types
- [ ] Capture signature
- [ ] Add photo attachment
- [ ] Submit form
- [ ] Export as PDF
- [ ] Email form
- [ ] Scan document and create template
- [ ] Drag-and-drop reorder fields
- [ ] Offline mode operations
- [ ] Sync when back online

### Simulator Limitations

- Camera not available (use photo library)
- Document scanner not available
- Email composer may not work

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Core Data crash on launch | Ensure model name matches container name |
| PDF generation fails | Check for nil values in form fields |
| Email not working | Simulator doesn't support email |
| Scanner not appearing | VisionKit requires physical device |
| Sync fails | Check network and auth token |

### Debug Tips

- Use `print()` statements in Core Data operations
- Check Console.app for detailed logs
- Use Xcode's Core Data debugger

---

## API Configuration

Update `SyncManager.baseURL` for your backend:

```swift
private let baseURL = "https://api.yourbackend.com/v1"
```

### Expected Endpoints

- `POST /forms` - Submit form data
- `GET /templates` - Fetch templates
- Headers: `Authorization: Bearer <token>`

---

## Security Considerations

- Auth tokens stored in Keychain
- Offline PIN hashed before storage
- No sensitive data in UserDefaults
- Image data stored in Core Data (consider external storage)

---

## AI Assistant Guidelines

### When Working on This Repository

1. **Read First**: Always read the Swift file before making changes
2. **Single File**: All code is in one file - maintain this structure
3. **Core Data**: Don't modify entity names without updating model
4. **iOS Patterns**: Follow Apple's SwiftUI conventions
5. **Test on Device**: Many features require physical device

### Things to Avoid

- Breaking Core Data model compatibility
- Removing required Info.plist keys
- Force unwrapping optionals without checks
- Blocking the main thread with heavy operations
- Storing sensitive data insecurely

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-04 | Initial CLAUDE.md created |
| 2026-02-04 | Added improved DigitalFormsApp with document scanner, form builder, PDF export, and email |

---

*Last updated: 2026-02-04*
