# App Store Review Checklist

## Overview

This document outlines everything needed to pass Apple's App Store Review for DigitalFormsApp.

---

## Critical Issues to Fix Before Submission

### 1. Complete All Features (Guideline 2.1 - App Completeness)

Apple rejects apps with placeholder content, "coming soon" features, or non-functional UI.

| View | Status | Action Required |
|------|--------|-----------------|
| `FormsListView` | ❌ Incomplete | Add full CRUD, fetch from Core Data |
| `TemplatesView` | ❌ Incomplete | Show real templates, allow management |
| `NewFormView` | ❌ Partial | Complete all navigation destinations |
| `FormDetailView` | ❌ Missing | Create full form editing view |
| `PendingApprovalsView` | ❌ Incomplete | Add real approval workflow |
| Widget | ❌ Stub only | Implement full WidgetKit widget |
| Siri Shortcuts | ❌ Stub only | Add intent handling |

### 2. Authentication (Guideline 4.2 - Minimum Functionality)

Current mock auth will be rejected. Options:

**Option A: Remove Login Requirement**
- Allow app usage without account
- Add optional sign-in for sync features

**Option B: Implement Real Auth**
- Add Firebase Auth, Auth0, or custom backend
- If adding Google/Facebook login, MUST add Apple Sign-In (Guideline 4.8)

**Option C: Offline-Only App**
- Remove all sync features
- Store everything locally in Core Data
- No account needed

### 3. Privacy Requirements (Guideline 5.1)

#### Required Privacy Policy
Must include:
- What data is collected
- How data is used
- How data is stored
- How to request data deletion
- Contact information

```swift
// Add to SettingsView
NavigationLink {
    WebView(url: URL(string: "https://yoursite.com/privacy")!)
} label: {
    Text("Privacy Policy")
}
```

#### App Privacy "Nutrition Labels"
In App Store Connect, declare:
- Data collected (location, photos, usage data)
- Data linked to user identity
- Data used for tracking

#### Data Deletion (GDPR/CCPA)
```swift
// Must add to SettingsView
Button("Delete My Account & Data", role: .destructive) {
    // Delete all user data from Core Data
    // Delete from backend if applicable
    // Sign out user
}
```

### 4. Permissions Must Be Justified (Guideline 5.1.1)

Each permission request must:
1. Be requested at time of use (not on launch)
2. Have clear explanation in Info.plist
3. App must work if denied (graceful degradation)

| Permission | Current Plist Text | Needs Improvement |
|------------|-------------------|-------------------|
| Camera | "Camera for photos..." | ✅ OK |
| Location | "Location capture for audit..." | ⚠️ Add "optional" |
| Microphone | "Microphone for voice..." | ✅ OK |
| Speech | "Speech recognition..." | ✅ OK |
| Face ID | "Face ID to secure..." | ✅ OK |

### 5. No Crashes (Guideline 2.1)

Test these scenarios:
- [ ] Deny all permissions - app should still work
- [ ] No network connection
- [ ] Kill app mid-form - data should persist
- [ ] Low memory conditions
- [ ] Rotate device during signature capture

### 6. Human Interface Guidelines

| Requirement | Status | Notes |
|-------------|--------|-------|
| Support Dynamic Type | ⚠️ Partial | Use `.font(.body)` not fixed sizes |
| Support Dark Mode | ✅ OK | Using system colors |
| Accessible | ⚠️ Check | Add accessibility labels |
| iPad Support | ⚠️ Check | Test on iPad, may need layout changes |
| Safe Area | ✅ OK | Using SwiftUI defaults |

---

## App Store Connect Requirements

### 1. App Information
- [ ] App name (30 chars max)
- [ ] Subtitle (30 chars max)
- [ ] Category: Business or Productivity
- [ ] Content Rating: 4+ (no objectionable content)

### 2. Screenshots Required
| Device | Sizes Needed |
|--------|--------------|
| iPhone 6.7" | 1290 x 2796 (iPhone 15 Pro Max) |
| iPhone 6.5" | 1284 x 2778 (iPhone 14 Plus) |
| iPhone 5.5" | 1242 x 2208 (iPhone 8 Plus) |
| iPad 12.9" | 2048 x 2732 (iPad Pro) |

Minimum 3 screenshots, maximum 10 per device.

### 3. App Description
- [ ] Primary description (4000 chars max)
- [ ] Keywords (100 chars max, comma-separated)
- [ ] What's New text for updates

### 4. Support Information
- [ ] Support URL (required)
- [ ] Marketing URL (optional)
- [ ] Privacy Policy URL (required)

### 5. Review Information
- [ ] Demo account credentials (if login required)
- [ ] Notes for reviewer explaining features
- [ ] Contact info for review team

---

## Code Changes Required

### 1. Remove/Fix Placeholder Code

```swift
// BEFORE (will be rejected)
NavigationLink {
    Text("Coming Soon")
} label: {
    Text("Feature")
}

// AFTER (acceptable)
NavigationLink {
    FeatureView() // Fully implemented
} label: {
    Text("Feature")
}
```

### 2. Add Graceful Permission Handling

```swift
// Check before using camera
if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
    // Show alert explaining how to enable in Settings
    showPermissionDeniedAlert()
} else {
    // Request or use camera
}
```

### 3. Add Offline Support Message

```swift
if !syncManager.isOnline {
    Banner("You're offline. Changes will sync when connected.")
}
```

### 4. Implement Real Data Persistence

```swift
// Ensure Core Data saves properly
func saveContext() {
    let context = container.viewContext
    if context.hasChanges {
        do {
            try context.save()
        } catch {
            // Log error but don't crash
            print("Save error: \(error)")
        }
    }
}
```

---

## Testing Before Submission

### Functional Testing
- [ ] Create form from every template
- [ ] Fill every field type
- [ ] Submit form
- [ ] Approve/reject form
- [ ] Export PDF
- [ ] Email form
- [ ] All features work offline

### Permission Testing
- [ ] Deny camera - photo features show appropriate message
- [ ] Deny location - forms still work, location field disabled
- [ ] Deny microphone - voice input shows alternative
- [ ] Deny Face ID - falls back to PIN or no lock

### Device Testing
- [ ] iPhone SE (smallest screen)
- [ ] iPhone 15 Pro Max (largest)
- [ ] iPad
- [ ] iOS 17.0 (minimum supported)
- [ ] Latest iOS version

### Network Testing
- [ ] Airplane mode
- [ ] Slow network (use Network Link Conditioner)
- [ ] Network drops mid-sync

---

## Recommended App Store Description

```
Digital Forms - Create, Sign & Submit

Transform paper forms into digital workflows. Perfect for safety inspections,
audits, work permits, and compliance documentation.

FEATURES:
• Scan paper forms with your camera and auto-convert to digital
• 18 field types including signatures, photos, and GPS location
• Work completely offline - sync when connected
• Professional PDF export and email sharing
• Dashboard with analytics and compliance tracking
• Face ID / Touch ID security

PERFECT FOR:
• Safety inspections
• Equipment audits
• Work permits
• Incident reports
• Quality checklists
• Compliance documentation

No subscription required. Your data stays on your device.
```

---

## Common Rejection Reasons to Avoid

| Rejection Reason | How to Avoid |
|------------------|--------------|
| 2.1 - Crashes | Test thoroughly, handle all errors |
| 2.1 - Placeholder content | Complete all features |
| 2.3 - Inaccurate metadata | Screenshots must match app |
| 4.2 - Minimum functionality | App must do what it claims |
| 4.8 - Sign in with Apple | Add if using social login |
| 5.1.1 - Data collection | Add privacy policy |
| 5.1.2 - Data use | Explain in permission prompts |

---

## Estimated Time to Review-Ready

| Task | Effort |
|------|--------|
| Complete placeholder views | 2-3 days |
| Add error handling | 1 day |
| Privacy/legal compliance | 1 day |
| Testing & bug fixes | 2 days |
| Screenshots & metadata | 1 day |
| **Total** | **7-10 days** |

---

## After Approval

- Set up App Analytics in App Store Connect
- Monitor crash reports
- Respond to user reviews
- Plan update roadmap

---

*Last updated: 2026-02-04*
