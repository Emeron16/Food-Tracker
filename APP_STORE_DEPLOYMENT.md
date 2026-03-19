# FreshTrack — App Store Deployment Guide

Step-by-step guide for submitting FreshTrack to the Apple App Store.

---

## Prerequisites

Before starting, make sure you have:

- [ ] Apple Developer account ($99/year) at [developer.apple.com](https://developer.apple.com)
- [ ] Xcode 15.0 or later
- [ ] A physical iOS device for final testing
- [ ] App Store Connect access (same Apple ID as Developer account)
- [ ] App icon (1024×1024px PNG, no alpha, no rounded corners — Apple applies them)
- [ ] At least 3–5 screenshots per device size

---

## Step 1 — App Store Connect Setup

### 1.1 Create the App Record

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Click **My Apps → +** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: FreshTrack (must be unique in the App Store)
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: Select the bundle ID you'll register in step 2 (e.g. `com.yourname.freshtrack`)
   - **SKU**: A unique internal identifier (e.g. `freshtrack-001`)
4. Click **Create**

### 1.2 Fill In App Information

Under **App Information**:
- **Subtitle** (optional, 30 chars): `Track groceries. Reduce waste.`
- **Category**: Food & Drink (primary), Health & Fitness (secondary)
- **Content Rights**: Check "This app does not use third-party content"
- **Age Rating**: Complete the questionnaire → should result in **4+**

---

## Step 2 — Xcode Project Configuration

### 2.1 Set Bundle Identifier

1. Open `FreshTrack.xcodeproj` in Xcode
2. Select the **FreshTrack** target → **Signing & Capabilities**
3. Set **Bundle Identifier** to match what you created in App Store Connect (e.g. `com.yourname.freshtrack`)
4. Select your **Team** from the dropdown (your Apple Developer account)
5. Enable **Automatically manage signing**

### 2.2 Set Version and Build Number

In the **General** tab of the FreshTrack target:
- **Version**: `1.0.0` (semantic versioning — this is what users see)
- **Build**: `1` (increment every time you upload a build — can be `1`, `2`, `3`...)

> App Store Connect requires a new build number with every upload, even for the same version.

### 2.3 Set Deployment Target

- **Minimum Deployments**: iOS 17.0
- **Devices**: iPhone (iPad support is optional)

### 2.4 Add Required Capabilities

In **Signing & Capabilities**, confirm these are present:
- **Push Notifications** — not required yet (local notifications don't need this)
- **Background Modes** — not required

If you plan to add CloudKit sync later:
- Add **iCloud** capability → enable **CloudKit**

### 2.5 Add Privacy Usage Descriptions

In `Info.plist`, add the following keys (Xcode may already have them if you tested on device):

| Key | Value |
|---|---|
| `NSCameraUsageDescription` | FreshTrack uses your camera to scan grocery barcodes for quick entry. |
| `NSPhotoLibraryUsageDescription` | FreshTrack can save grocery photos to your photo library. |
| `NSUserNotificationsUsageDescription` | FreshTrack sends meal-time reminders about expiring groceries. |

To add in Xcode:
1. Select `FreshTrack` target → **Info** tab
2. Click **+** to add each key

### 2.6 Add App Icon

1. Open `Assets.xcassets` in Xcode
2. Click **AppIcon**
3. Drag your 1024×1024px PNG into the **App Store** slot
4. Xcode will auto-generate all required sizes

> Tools to generate all sizes from one image: [appicon.co](https://appicon.co) or use Xcode's asset catalog which handles this automatically from a single 1024×1024 image.

---

## Step 3 — API Keys for Production

### 3.1 Spoonacular API Key

The Spoonacular key is currently hardcoded in `RecipeAPIService.swift`. Before release:

1. Create a production key at [spoonacular.com/food-api](https://spoonacular.com/food-api)
2. Consider storing it in a `Secrets.xcconfig` file (not committed to git):

```
// Secrets.xcconfig — add to .gitignore
SPOONACULAR_API_KEY = your_key_here
```

Then read it at runtime:
```swift
let apiKey = Bundle.main.infoDictionary?["SPOONACULAR_API_KEY"] as? String ?? ""
```

### 3.2 Open Food Facts

No API key required — Open Food Facts is a free, open database.

---

## Step 4 — TestFlight Beta Testing

Always test via TestFlight before submitting to the App Store.

### 4.1 Archive the App

1. Connect a physical iPhone (or use **Any iOS Device** as destination)
2. In Xcode: **Product → Archive**
3. Wait for the archive to complete — Xcode Organizer will open automatically

### 4.2 Upload to App Store Connect

1. In Xcode Organizer, select your archive
2. Click **Distribute App**
3. Choose **App Store Connect** → **Upload**
4. Keep all default options checked (strip Swift symbols, upload symbols)
5. Click **Upload**
6. Wait 5–15 minutes for processing in App Store Connect

### 4.3 Add Internal Testers

1. In App Store Connect → **TestFlight** tab
2. Select the build once it finishes processing
3. Under **Internal Testing** → Add testers (up to 100, no review needed)
4. Testers receive an email invitation

### 4.4 Add External Testers (optional)

External testing (up to 10,000 testers) requires a **Beta App Review** — usually 1–2 days:

1. **TestFlight → External Groups → +**
2. Add testers or a public link
3. Submit for Beta App Review — fill in test notes explaining what reviewers should test

---

## Step 5 — App Store Listing

### 5.1 Screenshots

Required sizes (at minimum):

| Device | Size |
|---|---|
| iPhone 6.9" (iPhone 16 Pro Max) | 1320 × 2868px |
| iPhone 6.5" (iPhone 11 Pro Max) | 1242 × 2688px |
| iPad Pro 12.9" (if supporting iPad) | 2048 × 2732px |

Tips:
- Show the most compelling screens: pantry list, recipe recommendations, barcode scanner, onboarding
- Add device frames and short captions using [Previewed](https://previewed.app) or Sketch/Figma
- Minimum 3 screenshots, maximum 10

### 5.2 App Description

**Short description** (first 3 lines shown before "more" — make these count):
```
Track your groceries, cut food waste, and cook smarter.

FreshTrack predicts expiration dates using on-device AI and reminds
you at breakfast, lunch, and dinner about items about to expire.
```

**Full description** (~500 words, use line breaks to separate sections):
```
TRACK WHAT YOU HAVE
Add groceries by scanning a barcode or entering manually. FreshTrack
pulls product details and photos automatically from Open Food Facts.

NEVER LET FOOD EXPIRE AGAIN
Our on-device machine learning model predicts expiration dates based
on the food category and where you store it — no internet required.

MEAL-TIME REMINDERS
Set your breakfast, lunch, and dinner times. FreshTrack reminds you
about expiring items at exactly the right moment, so nothing gets
forgotten at the back of the fridge.

COOK WITH WHAT YOU HAVE
Search recipes by the ingredients in your pantry. Filter by diet,
cooking time, and health score. Tap "My Ingredients" and select
exactly which items to include.

PERSONALIZED RECOMMENDATIONS
The more you use FreshTrack, the smarter it gets. Recommendations
are based on your viewing history and the time of day — entirely
on-device, with no data sent anywhere.

PRIVACY FIRST
All your grocery data, ML predictions, and recommendation history
stay on your device. No account required to use the app.
```

### 5.3 Keywords

Max 100 characters, comma-separated:
```
grocery,food tracker,expiration,recipes,meal planner,food waste,pantry,barcode,fridge
```

### 5.4 Support URL

You need a URL for support. Options:
- A GitHub repository URL (`https://github.com/yourname/freshtrack`)
- A simple landing page
- A personal website

### 5.5 Privacy Policy URL

Apple requires a privacy policy URL. Minimum content:
- What data is collected (local only — no server)
- How it's used
- Contact information

Free generators: [app-privacy-policy-generator.firebaseapp.com](https://app-privacy-policy-generator.firebaseapp.com)

Host it on GitHub Pages, Notion, or any public URL.

---

## Step 6 — Submit for Review

### 6.1 Select the Build

1. App Store Connect → Your App → **iOS App** section
2. Click **+** next to Build
3. Select the TestFlight build you want to submit

### 6.2 Complete App Review Information

Under **App Review Information**:
- **Sign-in required**: No (FreshTrack has no login)
- **Notes for reviewer**:
```
FreshTrack is a grocery tracking app. Core features:
1. Add groceries manually or by scanning a barcode
2. The app predicts expiration dates using an on-device ML model
3. Notifications remind users about expiring items at meal times (set in Settings tab)
4. Recipe search powered by Spoonacular API

No account or login is required. All data is stored locally on device.
Barcode scanning requires a physical device — cannot be tested in simulator.
```

### 6.3 Set Pricing

1. **Pricing and Availability** tab
2. Set price to **Free** (or your chosen tier)
3. Select territories (default: all available)

### 6.4 Submit

1. Confirm all sections show a green checkmark
2. Click **Submit for Review**
3. First submissions typically take **1–3 business days**
4. You'll receive an email when the status changes

---

## Step 7 — After Approval

### 7.1 Release Options

When the app is approved, choose:
- **Automatically release** — goes live immediately
- **Manually release** — you control when it goes live
- **Scheduled release** — set a specific date/time

### 7.2 Monitor After Launch

- **App Store Connect → Analytics** — downloads, sessions, retention
- **Crashes tab** — crash reports from users
- **Reviews** — respond to user reviews within App Store Connect

### 7.3 Subsequent Updates

For every update:
1. Increment the **Build number** in Xcode (required)
2. Increment **Version** if user-facing changes (e.g. 1.0.1 for a bug fix, 1.1.0 for new features)
3. Archive → Upload → Submit
4. Add **"What's New"** release notes in App Store Connect

---

## Common Rejection Reasons to Avoid

| Guideline | What to check |
|---|---|
| 2.1 — App Completeness | All tabs/features work. No placeholder content. |
| 4.0 — Design | No broken layouts on iPhone SE (small screen) or iPhone 16 Pro Max (large) |
| 5.1.1 — Privacy | `Info.plist` has usage descriptions for camera and notifications |
| 5.1.2 — Data Collection | Privacy policy URL is live and accessible |
| 2.3.3 — Accurate Metadata | Screenshots match the actual app UI |
| 3.1.1 — Payments | If adding paid features later, must use In-App Purchase |

---

## Checklist Summary

### Before Archiving
- [ ] Bundle ID set and matches App Store Connect
- [ ] Version set to `1.0.0`, Build set to `1`
- [ ] App icon added to asset catalog
- [ ] `Info.plist` privacy usage descriptions added
- [ ] Spoonacular API key is a production key
- [ ] Tested on physical device (especially barcode scanner)
- [ ] Onboarding flow tested from fresh install (delete app, reinstall)
- [ ] Notifications fire correctly at configured meal times

### App Store Connect
- [ ] App record created with correct bundle ID
- [ ] Age rating questionnaire completed
- [ ] Screenshots uploaded (6.9" required minimum)
- [ ] App description and keywords filled in
- [ ] Support URL live and accessible
- [ ] Privacy policy URL live and accessible
- [ ] Build selected and attached
- [ ] App Review notes filled in
- [ ] Pricing set

### Post-Submission
- [ ] TestFlight internal testing done before submission
- [ ] Monitor for rejection email within 1–3 days
- [ ] Respond to any reviewer questions promptly
