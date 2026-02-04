# Complete Setup Guide - DigitalForms

This guide covers setting up both the iOS app and web dashboard to work together.

---

## Quick Start

### 1. Deploy Web Dashboard to Railway

1. Go to [Railway](https://railway.app)
2. Click **New Project** → **Deploy from GitHub**
3. Select the `Inductionform` repository
4. **IMPORTANT**: Go to **Settings** → Set **Root Directory** to `web/dashboard`
5. Railway will auto-deploy

### 2. Set Up iOS App

```bash
# Navigate to iOS folder
cd ios

# Generate Xcode project
xcodegen generate

# Open in Xcode
open DigitalFormsApp.xcodeproj
```

Then in Xcode:
1. Create Core Data model (see ios/README.md)
2. Select your team in Signing & Capabilities
3. Build and run

---

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │────▶│  Railway API    │◀────│  Web Dashboard  │
│  (Field Use)    │     │  (PostgreSQL)   │     │  (Admin View)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                                               │
        │              Offline Support                  │
        └──────────────────────────────────────────────┘
                        Real-time Sync
```

### iOS App (Field Workers)
- Create and fill forms in the field
- Works offline - syncs when online
- Capture signatures, photos, GPS
- Scan documents with OCR
- Export to PDF

### Web Dashboard (Managers/Admin)
- View all submitted forms
- Approve/reject forms
- Browse templates
- User management
- Analytics & reporting

### Backend API (Railway)
- PostgreSQL database
- JWT authentication
- Form & template storage
- File uploads (S3)
- Email notifications

---

## Directory Structure

```
Inductionform/
├── ios/                    # iOS App (SwiftUI)
│   ├── DigitalFormsApp/
│   └── README.md           # iOS setup instructions
│
├── web/
│   ├── landing/            # Marketing website
│   │   ├── index.html      # Landing page
│   │   ├── privacy.html    # Privacy policy
│   │   └── terms.html      # Terms of service
│   │
│   └── dashboard/          # React admin dashboard
│       ├── src/
│       └── package.json
│
├── backend/                # Node.js API (if exists)
│
├── shared/
│   ├── config.json         # Shared configuration
│   └── templates/          # Form templates (JSON)
│
└── railway.toml            # Railway deployment config
```

---

## Form Templates

Pre-built industrial templates in `shared/templates/`:

| Template | Use Case | Est. Time |
|----------|----------|-----------|
| Daily Safety Inspection | Daily safety walks | 5-10 min |
| Incident Report | Accident documentation | 10-15 min |
| Equipment Pre-Use Check | Heavy equipment inspection | 5-10 min |
| Hot Work Permit | Welding/cutting authorization | 10 min |
| Delivery Receipt | Proof of delivery | 2-5 min |
| Toolbox Talk | Safety meeting attendance | 5 min |

---

## Configuration

### iOS App - Set Backend URL

Edit `ios/DigitalFormsApp/Services/APIService.swift`:

```swift
struct APIConfig {
    static let baseURL = "https://your-app.railway.app/api"
}
```

### Web Dashboard - Set Backend URL

Create `web/dashboard/.env`:

```env
VITE_API_URL=https://your-app.railway.app/api
```

---

## Workflow

### Field Worker (iOS)

1. Open app → Select template
2. Fill out form (works offline)
3. Capture photos/location
4. Sign form
5. Submit → Syncs to server

### Manager (Web Dashboard)

1. Log in to dashboard
2. View submitted forms
3. Review details and signatures
4. Approve or reject
5. Export PDF if needed

---

## Legal Signatures

All signatures are PIPEDA-compliant and capture:

- Signer name and email
- Drawn or typed signature
- Consent acknowledgment
- Timestamp (ISO 8601)
- Device identifier
- IP address
- GPS coordinates
- SHA-256 document hash

---

## Offline Mode

The iOS app works fully offline:

1. **Templates** - Cached locally
2. **Draft Forms** - Saved to Core Data
3. **Photos** - Stored locally
4. **Signatures** - Captured and stored
5. **Auto-Sync** - Uploads when online

---

## Testing

### Test Without Backend

Both apps have demo mode:

**iOS**: Works offline with local storage

**Web**: Login page has "Try Demo" button

### Test With Backend

Deploy backend to Railway:
1. Set **Root Directory** to `backend`
2. Add PostgreSQL database
3. Set environment variables

---

## Deployment Checklist

### Web Dashboard (Railway)
- [ ] Set Root Directory to `web/dashboard`
- [ ] Verify build completes
- [ ] Generate public URL

### iOS App (App Store)
- [ ] Create Core Data model
- [ ] Set backend URL
- [ ] Add app icons
- [ ] Test on physical device
- [ ] Archive and upload to App Store Connect

---

## Support

- iOS README: `ios/README.md`
- Web Dashboard: `web/dashboard/`
- Templates: `shared/templates/`

---

*Last updated: 2026-02-04*
