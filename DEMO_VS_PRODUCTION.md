# Demo Mode vs Production - Template Visibility

## Question: "Does it make a difference because I am using Demo?"

**Answer: YES!** Demo mode and Production mode load templates differently.

---

## How Demo Mode Works

### Demo Login
When you click **"Continue with Demo Account"** on the login page:

1. ✅ Creates a local demo user (no backend API call)
2. ✅ Stores demo user in localStorage
3. ✅ Uses **hardcoded demo data** from `api.js`
4. ❌ **Does NOT connect to Railway backend**
5. ❌ **Does NOT call `/api/templates` endpoint**

### Demo Data Source
```javascript
// web/dashboard/src/services/api.js
export const demoData = {
  templates: [
    // Hardcoded array of 7 templates
    { id: 'offshore-induction-hebron', ... },
    // ... other templates
  ]
}
```

**Demo Mode Uses:** Hardcoded JavaScript array in browser
**Demo Templates:** ✅ NOW includes all 7 templates (after recent update)

---

## How Production Mode Works

### Real Login
When you log in with actual email/password:

1. ✅ Connects to Railway backend API
2. ✅ Authenticates against PostgreSQL database
3. ✅ Gets access token
4. ✅ Calls `/api/templates` endpoint
5. ✅ Loads templates from JSON file on backend

### Production Data Source
```javascript
// backend/src/routes/templates.js
// Loads from: shared/templates/industrial-templates.json
router.get('/', async (req, res) => {
  // Returns built-in templates from JSON file
  // Plus any custom templates from database
})
```

**Production Uses:** Railway backend API → JSON file
**Production Templates:** ⏳ Pending deployment (needs merge to default branch)

---

## Current Status

### ✅ Demo Mode (Working NOW)
- **Branch:** `copilot/enhance-form-design-signatures`
- **Status:** Updated with all 7 templates
- **File:** `web/dashboard/src/services/api.js`
- **Templates Visible:** 
  1. Daily Safety Inspection
  2. Incident / Accident Report
  3. Equipment Pre-Use Checklist
  4. Hot Work Permit
  5. Delivery Receipt
  6. Toolbox Talk / Safety Meeting
  7. ⭐ **Offshore Induction Form - Hebron Platform** ⭐

**To See:** Just refresh browser in Demo mode

### ⏳ Production Mode (Pending Deployment)
- **Current Branch:** `claude/claude-md-ml7i8lkrhjgin66e-KOQ8V` (default)
- **Status:** Waiting for merge from feature branch
- **Files Need Merging:**
  - `shared/templates/industrial-templates.json` (7 templates)
  - `backend/src/routes/templates.js` (loads from JSON)
- **Templates Visible:** Only after merge + Railway deployment

**To Deploy:** Merge feature branch → default branch → Railway auto-deploys

---

## Comparison Table

| Feature | Demo Mode | Production Mode |
|---------|-----------|-----------------|
| **Login** | "Demo Account" button | Email + Password |
| **Backend Connection** | ❌ No | ✅ Yes |
| **Data Source** | Hardcoded JS array | Railway API → JSON file |
| **Templates** | ✅ 7 templates (NOW) | ⏳ Pending merge |
| **Offshore Form** | ✅ Visible (NOW) | ⏳ After deployment |
| **Database** | ❌ No | ✅ PostgreSQL |
| **Forms** | Demo forms only | Real database forms |
| **API Calls** | ❌ Skipped | ✅ All endpoints |
| **Authentication** | Local only | JWT tokens |

---

## Why Demo Mode Exists

Demo mode allows:
- ✅ Testing UI without backend
- ✅ Development without database
- ✅ Quick demos without login
- ✅ Offline functionality preview
- ❌ But it's NOT connected to real data

---

## How to Switch Between Modes

### Use Demo Mode
```
1. Go to: https://inductionform-production.up.railway.app/login
2. Click: "Continue with Demo Account"
3. See: Hardcoded demo data (7 templates ✅)
```

### Use Production Mode
```
1. Go to: https://inductionform-production.up.railway.app/login
2. Enter: Real email + password
3. See: Backend API data (pending deployment ⏳)
```

### Check Which Mode You're In
```javascript
// Check localStorage
const user = JSON.parse(localStorage.getItem('user'))
console.log(user)

// Demo user:
{ id: 'demo-user', name: 'Demo User', email: 'demo@example.com' }

// Real user:
{ id: '<uuid>', name: 'Real Name', email: 'real@email.com', ... }
```

---

## Timeline of Updates

### ✅ COMPLETED
1. **iOS App** - Offshore Induction Form added to BuiltInTemplates.swift
2. **Shared JSON** - Template added to industrial-templates.json (7 total)
3. **Backend API** - Code updated to load from JSON file
4. **Demo Mode** - Hardcoded data updated with all 7 templates

### ⏳ PENDING
1. **Merge to Default Branch** - Feature branch → `claude/claude-md-ml7i8lkrhjgin66e-KOQ8V`
2. **Railway Deployment** - Automatic after merge (2-3 minutes)
3. **Production Visible** - Templates appear in real login mode

---

## What You See Right Now

### If Using Demo Login ✅
```
Templates Page → Safety Category:
• Daily Safety Inspection (30 fields)
• Incident / Accident Report (30 fields)
• Toolbox Talk / Safety Meeting (15 fields)
• Offshore Induction Form - Hebron Platform (70 fields) ✅ NEW!
```

### If Using Real Login ⏳
```
Templates Page → Depends on deployment status:
• Before merge: Old templates (may show only 6)
• After merge: All 7 templates including Offshore Form
```

---

## Action Required for Production

To see templates in **Production Mode** (real login):

1. **Merge feature branch to default branch**
   ```bash
   git checkout claude/claude-md-ml7i8lkrhjgin66e-KOQ8V
   git merge copilot/enhance-form-design-signatures --allow-unrelated-histories
   git push origin claude/claude-md-ml7i8lkrhjgin66e-KOQ8V
   ```

2. **Wait for Railway deployment** (~2-3 minutes)

3. **Verify templates appear**
   - Log in with real credentials
   - Navigate to Templates page
   - See all 7 templates including Offshore Induction Form

---

## Summary

**Demo Mode:**
- ✅ Already updated - working NOW
- ✅ Shows all 7 templates
- ✅ Offshore Induction Form visible
- ✅ No deployment needed
- ❌ Not connected to real backend

**Production Mode:**
- ⏳ Needs merge to default branch
- ⏳ Needs Railway deployment
- ⏳ Then shows all 7 templates
- ✅ Connected to real backend
- ✅ Real database and API

**Bottom Line:** YES, it makes a difference! Demo mode is working now. Production mode needs deployment.

---

## Files Updated

1. ✅ `web/dashboard/src/services/api.js` - Demo data updated
2. ✅ `shared/templates/industrial-templates.json` - 7 templates ready
3. ✅ `backend/src/routes/templates.js` - Loads from JSON
4. ⏳ Needs merge to default branch for Railway

---

**Last Updated:** 2026-02-05
**Status:** Demo mode complete ✅ | Production pending merge ⏳
