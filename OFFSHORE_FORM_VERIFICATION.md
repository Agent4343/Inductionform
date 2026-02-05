# Offshore Induction Form - Demo Mode Verification Guide

## Quick Answer

**YES!** You should be able to see the **Offshore Induction Form - Hebron Platform** in demo mode.

---

## Template Information

**Official Name:** Offshore Induction Form - Hebron Platform  
**Program:** Hebron Platform - Green Hat Program  
**Form ID:** CANE-EC-OFPRO-01-005-4008-00 | 04  
**Category:** Safety  
**Total Fields:** 70 fields  
**Estimated Time:** 20-30 minutes  
**Template ID:** `offshore-induction-hebron`

---

## How to View in Demo Mode

### Step-by-Step Instructions

#### 1. Access the Login Page
```
URL: https://inductionform-production.up.railway.app/login
```

#### 2. Click Demo Account Button
Look for the button that says:
```
Continue with Demo Account
No backend required • All features available • Perfect for evaluation
```

Click this button.

#### 3. Wait for Dashboard to Load
You should see:
- Demo mode banner (yellow/amber) at the top
- Banner text: "⚠️ Demo Mode"
- Dashboard with statistics

#### 4. Navigate to Templates
In the sidebar or navigation menu, click:
```
Templates
```

#### 5. Filter by Safety Category (Optional)
If the templates page has category filters, click:
```
Safety
```

#### 6. Locate the Template
Scroll through the templates list to find:

```
┌──────────────────────────────────────────────────────┐
│ 🛡️ Safety                                            │
│                                                       │
│ Offshore Induction Form - Hebron Platform           │
│ 70 fields • 20-30 min                                │
│                                                       │
│ Hebron Platform - Green Hat Program                 │
│ (CANE-EC-OFPRO-01-005-4008-00 | 04)                │
│                                                       │
│ [View Template →]                                    │
└──────────────────────────────────────────────────────┘
```

#### 7. View Template Details
Click the **"View Template →"** button to see all 70 fields.

---

## What You Should See

### In the Templates List

**All 7 Templates Available:**

**Safety Category (4 templates):**
1. Daily Safety Inspection (30 fields, 5-10 min)
2. Incident / Accident Report (30 fields, 10-15 min)
3. Toolbox Talk / Safety Meeting (15 fields, 5 min)
4. **Offshore Induction Form - Hebron Platform (70 fields, 20-30 min)** ⭐

**Other Categories:**
5. Equipment Pre-Use Checklist - Operations (30 fields)
6. Hot Work Permit - Permits (26 fields)
7. Delivery Receipt - Logistics (21 fields)

### Template Details Page

When you click "View Template →", you should see:

**Header:**
- Template name
- Form reference: CANE-EC-OFPRO-01-005-4008-00 | 04
- Category: Safety
- Field count: 70 fields
- Time estimate: 20-30 min

**Sections (70 fields total):**

1. **Form ID Reference** (1 field)
   - Text field for form reference number

2. **Instructions Section** (2 fields)
   - Section header
   - Textarea with instructions

3. **General Orientation** (32 fields)
   - Section header (0/31 checked)
   - 31 checkbox items covering:
     - Muster stations (4 items)
     - Emergency equipment (2 items)
     - Facility locations (7 items)
     - Emergency procedures (8 items)
     - Platform rules (10 items)

4. **Safety Overview** (4 fields)
   - Section header (0/3 checked)
   - 3 checkbox items for basic safety

5. **Detailed Safety Training** (17 fields)
   - Section header (0/16 checked)
   - 16 checkbox items for comprehensive safety

6. **Work Management System** (4 fields)
   - Section header (0/3 checked)
   - 3 checkbox items for WMS/PSMS

7. **Inductee Acknowledgement** (5 fields)
   - Section header
   - Name (required)
   - Company (required)
   - Date (required)
   - Inductee signature (required)

8. **Supervisor Confirmation** (5 fields)
   - Section header
   - Offshore team
   - Responsible supervisor (required)
   - Presenter/Mentor
   - Supervisor signature (required)

**Total:** 70 fields across 8 sections

---

## Verification Checklist

Use this checklist to verify everything is working:

### ✅ Demo Mode Access
- [ ] Navigated to login page
- [ ] Clicked "Continue with Demo Account"
- [ ] Dashboard loaded successfully
- [ ] Demo mode banner visible at top
- [ ] No console errors (press F12 to check)

### ✅ Templates Page
- [ ] Clicked "Templates" in navigation
- [ ] Templates page loaded
- [ ] All 7 templates visible
- [ ] Can filter by category (optional)

### ✅ Offshore Induction Form
- [ ] Found "Offshore Induction Form - Hebron Platform"
- [ ] Located in Safety category
- [ ] Shows "70 fields"
- [ ] Shows "20-30 min"
- [ ] Shows form description with ID
- [ ] "View Template →" button visible

### ✅ Template Details
- [ ] Clicked "View Template →"
- [ ] Template details page loaded
- [ ] Can see all sections
- [ ] Can see field count (70 total)
- [ ] Can see checklist items (53 total)
- [ ] Can see signature fields (2 required)

---

## Troubleshooting

### Problem: Don't See Template in List

**Possible Causes:**
1. Not in demo mode
2. Page not refreshed
3. Browser cache issue
4. JavaScript error

**Solutions:**

#### Solution 1: Verify Demo Mode
Look for the demo mode banner at the top:
```
⚠️ Demo Mode
You're viewing demo data. To see real data, log in with your account credentials.
```

If you don't see this banner:
- You're NOT in demo mode
- Log out and click "Continue with Demo Account"

#### Solution 2: Force Refresh
- **Windows/Linux:** Press `Ctrl + Shift + R`
- **Mac:** Press `Cmd + Shift + R`
- This clears cached JavaScript and CSS

#### Solution 3: Clear Browser Cache
1. Open browser settings
2. Go to Privacy or History
3. Select "Clear browsing data"
4. Check "Cached images and files"
5. Click "Clear data"
6. Reload the page

#### Solution 4: Check Browser Console
1. Press `F12` to open developer tools
2. Click the "Console" tab
3. Look for red error messages
4. If you see errors, note them and check documentation

**Expected Console (No Errors):**
```
(Clean console - no red errors)
```

**If You See Errors:**
- See DEMO_MODE_FIX.md for error resolution
- See LOGIN_ERROR_FIX.md for login issues

#### Solution 5: Check Network Tab
1. Press `F12` to open developer tools
2. Click the "Network" tab
3. Refresh the page
4. Look for requests being made

**In Demo Mode (Expected):**
- No `/api/templates` HTTP request (data is hardcoded)
- No authentication requests
- Only static file requests (HTML, CSS, JS)

**If You See API Requests:**
- You're NOT in demo mode
- Demo mode should NOT make API calls
- Log out and use demo login again

---

## Technical Verification

### For Developers

#### Verify Demo Data Configuration

**File:** `web/dashboard/src/services/api.js`

**Check:**
```javascript
// Around line 100-150 in demoData.templates
{
  id: 'offshore-induction-hebron',
  name: 'Offshore Induction Form - Hebron Platform',
  category: 'safety',
  fieldCount: 70,
  description: 'Hebron Platform - Green Hat Program (CANE-EC-OFPRO-01-005-4008-00 | 04)',
  estimatedTime: '20-30 min'
}
```

**Status:** ✅ Should be present

#### Verify Backend JSON Template

**File:** `shared/templates/industrial-templates.json`

**Check:**
```bash
grep -c "offshore-induction-hebron" shared/templates/industrial-templates.json
```

**Expected Output:** `1` (template found)

**Status:** ✅ Should return 1

#### Verify iOS Template

**File:** `ios/DigitalFormsApp/Templates/BuiltInTemplates.swift`

**Check:**
```bash
grep -c "offshoreInductionForm" ios/DigitalFormsApp/Templates/BuiltInTemplates.swift
```

**Expected Output:** `1` (template found)

**Status:** ✅ Should return 1

---

## Expected vs Actual

### Expected Behavior ✅

**When in Demo Mode:**
1. ✅ Login with "Continue with Demo Account"
2. ✅ See demo mode banner
3. ✅ Navigate to Templates
4. ✅ See 7 total templates
5. ✅ Find Offshore Induction Form in Safety category
6. ✅ Template shows 70 fields, 20-30 min
7. ✅ Click "View Template →"
8. ✅ See all 8 sections with 70 fields
9. ✅ Zero errors in console

**Template Data:**
- ✅ ID: `offshore-induction-hebron`
- ✅ Name: Offshore Induction Form - Hebron Platform
- ✅ Category: safety
- ✅ Fields: 70
- ✅ Time: 20-30 min
- ✅ Description: Hebron Platform - Green Hat Program (CANE-EC-OFPRO-01-005-4008-00 | 04)

### If NOT Working ❌

**Symptoms:**
- Template not in list
- Only 6 templates showing (not 7)
- "Offshore Induction Form" missing
- Errors in console

**Diagnosis:**
1. Check if in demo mode (look for banner)
2. Check browser console for errors
3. Verify demo data configuration
4. Check network requests (should be none in demo mode)
5. Try different browser

**Solutions:**
- See troubleshooting section above
- See DEMO_MODE_FIX.md
- See LOGIN_ERROR_FIX.md
- See DATABASE_REQUIREMENTS.md

---

## Browser Compatibility

### Tested Browsers ✅

**Desktop:**
- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+

**Mobile:**
- ✅ Chrome Mobile (Android)
- ✅ Safari Mobile (iOS)

**Requirements:**
- JavaScript enabled
- Cookies enabled (for localStorage)
- Modern browser (ES6 support)

---

## Summary

### Quick Checklist

**To view Offshore Induction Form in demo mode:**
1. ✅ Go to login page
2. ✅ Click "Continue with Demo Account"
3. ✅ Wait for dashboard (demo banner visible)
4. ✅ Click "Templates" in navigation
5. ✅ Find in Safety category (4th template)
6. ✅ Should show 70 fields, 20-30 min
7. ✅ Click "View Template →"
8. ✅ See all 70 fields in 8 sections

**Expected Result:**
✅ Template is visible and fully functional in demo mode!

**If Not Working:**
- Verify demo mode (banner visible)
- Refresh page (Ctrl+Shift+R)
- Clear browser cache
- Check console for errors
- See troubleshooting guide above

---

## Related Documentation

**For More Information:**

- **OFFSHORE_INDUCTION_FORM.md** - Complete template usage guide
- **TEMPLATE_STRUCTURE.txt** - Field hierarchy visualization
- **DEMO_VS_PRODUCTION.md** - Demo vs production mode comparison
- **DEMO_MODE_FIX.md** - Demo mode error troubleshooting
- **LOGIN_ERROR_FIX.md** - Login error resolution
- **DATABASE_REQUIREMENTS.md** - Database setup (for production)

---

## Support

**If You Still Can't See the Template:**

1. **Check Demo Mode:**
   - Verify demo banner is visible
   - No API calls should be made

2. **Browser Console:**
   - Press F12
   - Look for errors
   - Report any errors found

3. **Network Tab:**
   - Press F12
   - Check Network tab
   - Should see NO API requests in demo mode

4. **Documentation:**
   - Read DEMO_MODE_FIX.md
   - Read LOGIN_ERROR_FIX.md
   - Check TROUBLESHOOTING sections

**Common Issues:**
- Not in demo mode (use demo login!)
- Browser cache (clear it!)
- JavaScript errors (check console!)
- Network issues (shouldn't matter in demo)

---

## Final Answer

**YES, you should absolutely be able to see the Offshore Induction Form - Hebron Platform template in demo mode!**

**It's configured with:**
- ✅ 70 fields
- ✅ 20-30 min estimated time
- ✅ Complete form ID: CANE-EC-OFPRO-01-005-4008-00 | 04
- ✅ All sections implemented
- ✅ Ready to view and use

**Just follow the simple steps:**
1. Login with demo account
2. Go to Templates
3. Find in Safety category
4. Click View Template

**That's it! You should see the complete form with all 70 fields.**

---

**Last Updated:** 2026-02-05  
**Status:** ✅ Template Configured and Available in Demo Mode  
**Documentation:** Complete
