# PHASE 1-2: Foundation
> Active during: Environment setup and app skeleton
> Always read 00_project.md alongside this file.

## Goal of This Phase
Build a working app skeleton with NavigationSplitView, dummy data, and
screen transitions — before touching any real files or iCloud.

## Xcode Project Settings
| Item | Value |
|------|-------|
| Project Name | Nodus |
| Bundle ID | com.YOURNAME.Nodus |
| Interface | SwiftUI |
| Language | Swift |
| Minimum Deployment | iOS 17.0 |
| Include Tests | Yes |

## Target Folder Structure
```
Nodus/
├── App/
│   └── NodusApp.swift           ← App entry point (@main)
├── Models/
│   └── Note.swift               ← Note data model
├── Views/
│   ├── ContentView.swift        ← NavigationSplitView root
│   ├── NoteListView.swift       ← Sidebar: search + note list
│   ├── NoteDetailView.swift     ← Detail: editor + preview
│   └── EmptySelectionView.swift ← Shown when no note selected (iPad)
├── ViewModels/
│   └── NoteStore.swift          ← State management, business logic
├── Core/                        ← Pure logic only, no SwiftUI imports
│   ├── SearchEngine.swift       ← AND search logic (tested in PHASE 4)
│   ├── LinkResolver.swift       ← [[ID]] resolution (tested in PHASE 4)
│   └── NoteFilenameParser.swift ← Timestamp/title parsing (tested in PHASE 4)
└── Utilities/
    └── DateFormatter+Note.swift ← YYYYMMDDHHmm timestamp helpers
```
> Create the Core/ folder in PHASE 1 even though it stays empty until PHASE 4.
> This keeps the structure consistent from the start.

## Note Model (Phase 2 - Dummy Data)
```swift
struct Note: Identifiable {
    let id: UUID
    var filename: String   // e.g. "202604271321 Title.md"
    var body: String       // Full markdown content
    var createdAt: Date
    var updatedAt: Date
}
```
> In Phase 3 this will be backed by real files. Keep the model simple for now.

## NavigationSplitView Skeleton
```swift
NavigationSplitView {
    NoteListView()       // Sidebar (iPhone: full screen, iPad: left pane)
} detail: {
    EmptySelectionView() // iPad: shown until user selects a note
}
```

## Phase 2 Checklist
- [ ] Project created in Xcode with correct settings
- [ ] Folder structure created
- [ ] Note model defined
- [ ] NoteStore has hardcoded dummy notes (at least 5)
- [ ] NoteListView shows list of note titles
- [ ] Tapping a note navigates to NoteDetailView
- [ ] NoteDetailView shows filename and body as plain text
- [ ] Builds and runs on iPhone simulator without errors
- [ ] Builds and runs on iPad simulator without errors

## Prompting Tips for This Phase
When asking Cursor for help, always specify:
- Which file you are working on
- What the file should do (single responsibility)
- Which other files it depends on

### Example Prompt
```
I'm building Nodus, a SwiftUI Zettelkasten app (see 00_project.md).
Create NoteListView.swift in Views/.
This view:
- Receives [Note] from NoteStore via @EnvironmentObject
- Shows a plain List of note titles (filename without extension)
- Has a search bar at the top (filter by filename only for now)
- Has a + button in the toolbar that calls NoteStore.createNote()
No navigation logic yet — just the list UI.
```

## What NOT to Do in This Phase
- Do not connect iCloud yet
- Do not implement real file I/O
- Do not implement search against body text
- Do not implement wiki link resolution
- Keep NoteStore's data source as a hardcoded array
