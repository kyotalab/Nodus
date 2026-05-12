# PHASE 6: App Store Submission
> Active during: TestFlight, review preparation, and App Store submission
> Always read 00_project.md alongside this file.

## Goal of This Phase
Prepare and submit Nodus to the App Store.
This phase is mostly non-coding work: assets, metadata, and process.

---

## Step 1: Apple Developer Program

### Enrollment
- URL: https://developer.apple.com/programs/enroll/
- Cost: $99 USD/year
- Required before any TestFlight or App Store submission
- Takes up to 48 hours for approval

### What You Get
- Ability to distribute on the App Store
- TestFlight for beta testing
- Up to 10,000 external TestFlight testers

---

## Step 2: App Store Connect Setup

### Create App Record
1. Go to https://appstoreconnect.apple.com
2. My Apps → + → New App
3. Fill in:

| Field | Value |
|-------|-------|
| Platform | iOS |
| Name | Nodus |
| Subtitle | Plain text, connected thinking |
| Bundle ID | com.YOURNAME.Nodus |
| SKU | nodus-ios-1 (any unique string) |
| Primary Language | English |

---

## Step 3: Required Assets

### App Icon
- Size: 1024×1024px PNG
- No alpha channel (no transparency)
- No rounded corners (App Store crops automatically)
- Xcode generates all required sizes from this single image

### Screenshots (Required)
Minimum: iPhone 6.9" (iPhone 16 Pro Max)
Recommended: also provide iPad 13"

| Device | Size |
|--------|------|
| iPhone 6.9" | 1320×2868px |
| iPhone 6.5" | 1242×2688px |
| iPad 13" Pro | 2064×2752px |

### Screenshot Content (suggested)
1. Note list with search bar (showing density)
2. Editor with keyboard toolbar visible
3. Preview mode with rendered [[wiki links]]
4. iPad split view

---

## Step 4: App Store Metadata

### Description
```
Nodus — Plain text, connected thinking

Your Zettelkasten. On iOS. Finally.

Nodus is a minimal Markdown note-taking app built around
the Zettelkasten method. No plugins. No graph views.
No configuration rabbit holes.
Just plain text files stored in iCloud Drive.

PLAIN TEXT, ALWAYS
Notes are .md files you own completely. Open them in
any Markdown editor on any device. No proprietary
format. No lock-in. Ever.

CONNECTED THINKING
Link notes with [[timestamp]] wiki links. Links survive
title changes because they reference the ID, not the title.

FAST FULL-TEXT SEARCH
Find anything instantly. Space-separated terms work as
AND search across filenames and note bodies.

BUILT FOR WRITING
Toggle between a clean monospaced editor and Markdown
preview. A minimal keyboard toolbar keeps #, **, and [[
one tap away.

WORKS WITH YOUR EXISTING NOTES
Notes are stored as plain .md files in iCloud Drive.
Compatible with any Markdown editor on Mac or iOS.
Your notes. Your files. Always.
```

### Keywords (100 chars max)
```
zettelkasten,markdown,notes,plain text,linked notes,pkm,writing,knowledge
```
> Keywords are not visible to users but affect search ranking.
> Do not repeat words already in the app name or subtitle.

### Pricing
- Model: One-time purchase (no subscription)
- Price range: $2.99–$4.99 (finalize after beta testing)
- Nodus stores notes in user's own iCloud — no backend costs

### Support URL
Required. Use a GitHub repository URL or simple webpage.
Prepare before submission.

### Privacy Policy URL
Required. Nodus stores notes only in the user's own iCloud.
A minimal privacy policy is sufficient.
Prepare before submission.

---

## Step 5: TestFlight Beta

### Internal Testing (before external)
1. Archive build in Xcode: Product → Archive
2. Distribute App → App Store Connect → Upload
3. TestFlight → Internal Testing → Add build
4. Up to 25 internal testers (Apple ID required)

### External Testing
1. Add external tester group
2. Submit build for Beta App Review (1-2 days)
3. Share public link or invite by email

### What to Test in Beta
- [ ] iCloud sync between iPhone and Mac (The Archive)
- [ ] Note creation, editing, deletion
- [ ] Search across a real vault (50+ notes)
- [ ] [[wiki link]] navigation
- [ ] App backgrounded and foregrounded (auto-save)
- [ ] Fresh install (no existing notes)
- [ ] Restore from iCloud (delete app, reinstall)

---

## Step 6: App Review Submission

### Pre-submission Checklist
- [ ] All required screenshots uploaded
- [ ] App description complete
- [ ] Keywords filled (under 100 chars)
- [ ] Privacy policy URL set
- [ ] Support URL set
- [ ] Age rating completed (Nodus: 4+)
- [ ] Version number set (start with 1.0.0)
- [ ] Build uploaded and processed (can take 30 min)
- [ ] iCloud entitlement configured correctly
- [ ] No placeholder content in the app

### Common Rejection Reasons (avoid these)
| Reason | Prevention |
|--------|-----------|
| Crashes on launch | Test on oldest supported device (iPhone with iOS 17) |
| iCloud not working | Verify on real device, not simulator |
| Misleading screenshots | Screenshots must match actual app UI |
| Missing privacy policy | Required if any user data is involved |
| App does too little | Ensure core features are fully working |

### Review Time
- Typically 24-48 hours
- Can request expedited review for critical bugs

---

## Version Numbering
```
1.0.0  ← Initial App Store release
1.0.1  ← Bug fix
1.1.0  ← New feature (e.g. new sort option)
2.0.0  ← Major redesign or breaking change
```

Set in Xcode: Project → Target → General → Version / Build

### Release versioning (Nodus)

- **MARKETING_VERSION** (user-facing): `1.1` (was `1.0` for initial store release)
- **CURRENT_PROJECT_VERSION** (build): `3` — bump for every new binary uploaded to App Store Connect / TestFlight (follows the previous store build).

---

## v1.1 What's New

- Copy Wiki Link: Long press on note list or tap ... in note detail to copy [[ID]] format link
- Back to List: Return to note list instantly from any depth
- Search Notes: Return to list with search bar activated
- Fixed: Opening a note no longer updates its modification date
- Fixed: Share now exports a single .md file with the correct filename

---

## Phase 6 Checklist
- [ ] Apple Developer Program enrolled and approved
- [ ] App record created in App Store Connect
- [ ] App icon designed (1024×1024px)
- [ ] Screenshots captured for all required device sizes
- [ ] App description written
- [ ] Keywords set
- [ ] Privacy policy published
- [ ] Internal TestFlight testing complete
- [ ] External TestFlight beta (optional but recommended)
- [ ] All pre-submission checklist items done
- [ ] Submitted for App Review
- [ ] Approved and released 🎉
