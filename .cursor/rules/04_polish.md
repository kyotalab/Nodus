# PHASE 5: Polish
> Active during: UX refinement, edge cases, performance
> Always read 00_project.md alongside this file.

## Goal of This Phase
Make Nodus feel like a professional, well-crafted app.
Focus on reliability, edge cases, and the details that make daily use pleasant.

---

## Area 1: Auto-save Reliability

### Trigger Points
1. User leaves NoteDetailView (`.onDisappear`)
2. App goes to background (`scenePhase == .background`)
3. 2-second debounce after last keystroke

### Debounce Implementation
```swift
// In NoteDetailView or its ViewModel
@State private var saveTask: Task<Void, Never>?

func onBodyChange(_ newValue: String) {
    saveTask?.cancel()
    saveTask = Task {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        await saveCurrentNote()
    }
}
```

### Unsaved Changes Indicator
Show a subtle dot in the title bar when there are unsaved changes:
```
← Back    My Note •    Edit
                  ↑ unsaved indicator
```

---

## Area 2: Note Title Editing

### UX
- Title is editable inline at the top of NoteDetailView
- Tapping the title in edit mode makes it editable
- On commit (Return key or focus lost): rename the file

### Behavior
```
Display:  "Structured contexts should..."
Edit:     [Structured contexts should...    ]
Commit:   renames file to "202604271321 Structured contexts should....md"
```

### Edge Cases
- Empty title → filename becomes `202604271321.md` (ID only)
- Title containing `/` → strip or replace with `-`
- Extremely long title → truncate filename to 200 chars total

---

## Area 3: Swipe Actions on Note List

```swift
.swipeActions(edge: .trailing) {
    Button(role: .destructive) {
        noteToDelete = note
        showDeleteConfirmation = true
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

### Delete Confirmation
Show `.alert` before permanent deletion:
```
Title:   "Delete 'Note Title'?"          ← use note.title, or timestampID if no title
Message: "This cannot be undone."
Buttons: [Cancel] [Delete]               ← Delete is destructive (red)
```

---

## Area 4: Empty States

### No Notes at All (first launch)
```
┌─────────────────────────┐
│                         │
│   Your knowledge        │
│   network starts here   │
│                         │
│   Tap + to create       │
│   your first note       │
│                         │
└─────────────────────────┘
```

### Search Returns Nothing (handled in Phase 4)
```
┌─────────────────────────────┐
│  Nothing found for "swift"  │
│                             │
│  + Create new note          │  ← tappable row
└─────────────────────────────┘
```
> Note: query is shown in the message but NOT used as the note title.

### No Note Selected (iPad)
```
┌─────────────────────────┐
│                         │
│      [Nodus Logo]       │
│                         │
└─────────────────────────┘
```
> Logo only — no text. Clean and minimal.

---

## Area 5: Performance for Large Vaults

### Lazy Loading
- Do not load all note bodies on startup
- Load body only when note is selected
- NoteStore holds metadata (filename, dates) for all notes
- Body loaded on demand and cached

```swift
struct Note {
    let url: URL
    var _body: String? = nil  // nil = not loaded yet

    mutating func loadBody() throws {
        _body = try String(contentsOf: url, encoding: .utf8)
    }
}
```

### Search Performance
- Full-text search requires all bodies loaded
- On first search: load all bodies, cache them
- Show loading indicator if vault is large (>500 notes)

---

## Area 6: Accessibility

- All buttons have `.accessibilityLabel`
- Note list rows have meaningful labels: `"\(note.title), updated \(note.updatedAt)"`
- Keyboard toolbar buttons have labels: `"Insert heading"`, `"Insert bold"` etc.
- Support Dynamic Type (avoid fixed font sizes)

---

## Area 7: iPad-Specific Polish

### Keyboard Shortcuts (iPad with hardware keyboard)
```swift
.keyboardShortcut("n", modifiers: .command)  // New note
.keyboardShortcut("f", modifiers: .command)  // Focus search
.keyboardShortcut("e", modifiers: .command)  // Toggle edit/preview
```

### Drag and Drop
- Notes can be dragged from list and dropped into other apps as `.md` files
- Low priority: implement only if time allows

---

## Phase 5 Checklist
- [ ] Auto-save works reliably on navigate-away and background
- [ ] Unsaved changes indicator shown in title bar
- [ ] Note title editable inline, file renamed on commit
- [ ] Edge cases handled: empty title, special characters in title
- [ ] Swipe-to-delete with confirmation alert
- [ ] Empty state views for: no notes, no search results, no selection (iPad)
- [ ] Note bodies loaded lazily (not all at startup)
- [ ] Accessibility labels on all interactive elements
- [ ] Dynamic Type supported throughout
- [ ] iPad keyboard shortcuts for new note, search, toggle
- [ ] Tested on both iPhone and iPad simulators
- [ ] Tested on real device with actual iCloud notes

---

## Common Pitfalls
| Pitfall | Solution |
|---------|----------|
| Auto-save fires too often | Use debounce, not `onChange` direct save |
| File rename race condition | Disable title field during rename operation |
| Memory spike loading all bodies | Load lazily, cache with size limit |
| Search feels slow | Run search on background thread, publish results on main |
