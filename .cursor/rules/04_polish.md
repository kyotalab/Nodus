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

### External Change Behavior
```swift
// When NSMetadataQuery detects external file change:
if isEditing {
    // Hold — apply after user leaves edit mode
    pendingExternalUpdate = newContent
} else {
    // Preview mode or not open — apply immediately
    note.body = newContent
}
```

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

### Title Editing（実装パターン）
```swift
// タイトル編集フィールド
@State private var editingTitle = ""
@FocusState private var isTitleFocused: Bool

TextField("Untitled", text: $editingTitle)
    .font(.headline)
    .focused($isTitleFocused)
    .onSubmit { commitTitle() }

// フォーカスを失ったらコミット
.onChange(of: isTitleFocused) { _, focused in
    if !focused { commitTitle() }
}

// 新規作成時は自動フォーカス
.task(id: note.url) {
    if note.title.isEmpty {
        isTitleFocused = true
    }
}
```

### Date Display in Preview Mode
- Display: プレビューモードのみ・本文下部
- Format: "yyyy-MM-dd HH:mm"
- Style: .caption / .secondary
- Fields: createdAt / updatedAt（ファイルシステムメタデータから取得）
- Rationale: The Archiveユーザーのフロントマター手動管理を不要にする

### renameNote()のDEBUG分岐パターン
```swift
#if DEBUG
#if targetEnvironment(simulator)
// メモリ上でnotes配列のfilenameを更新する（ファイル操作なし）
if let index = notes.firstIndex(where: { $0.url == note.url }) {
    let newFilename = newTitle.isEmpty
        ? "\(note.timestampID).md"
        : "\(note.timestampID) \(newTitle).md"
    let newURL = URL(fileURLWithPath: "/tmp/\(newFilename)")
    notes[index] = Note(
        url: newURL,
        body: notes[index].body,
        createdAt: notes[index].createdAt,
        updatedAt: Date()
    )
    return notes[index]
}
return nil
#endif
#endif
```

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

### No Notes at All (first launch — also shown after folder selection if folder is empty)
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
│         Nodus           │  ← .largeTitle, .thin, .secondary
│ Plain text, connected   │  ← .caption, .secondary
│       thinking          │
│                         │
└─────────────────────────┘
```
> Typography-only branding (no bitmap logo). Clean and minimal.

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

- Toolbar / list controls use English `.accessibilityLabel` strings (see `NoteListView`, `NoteDetailView`, `EmptySelectionView`).
- Note list rows: `"\(title or timestampID), updated yyyy-MM-dd HH:mm)"` via `DateFormatter.noteDisplayTimestamp`.
- Keyboard toolbar (edit mode): `Insert heading`, `Insert bold`, `Insert italic`, `Insert blockquote`, `Insert wiki link`, `Insert tab`.
- Edit/Preview toggle: `Switch to preview mode` / `Switch to edit mode` depending on current mode.
- iPad empty selection: combined element label `Nodus. Plain text, connected thinking.`
- Support Dynamic Type (avoid fixed font sizes in app UI)

---

## Area 6.5: Settings Screen

Implement a minimal Settings screen accessible from the note list toolbar:

```swift
// Settings items:
// 1. Storage → Zettelkasten Folder (UIDocumentPickerViewController)
// 2. Editor → Default Mode (Edit / Preview) — stored in @AppStorage
// 3. About → Version + Support URL
```

```swift
// Default mode persistence
@AppStorage("defaultEditorMode") var defaultEditorMode: String = "edit"
```

## Area 7: iPad-Specific Polish

### Keyboard Shortcuts (iPad with hardware keyboard)
Implemented in-app via `.keyboardShortcut` (see `NoteListView`, `NoteDetailView`):

| Shortcut | Action |
|----------|--------|
| ⌘N | New note |
| ⌘E | Toggle edit/preview |

> ⌘F (focus search) removed for now; to be reimplemented separately.

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
- [x] Accessibility labels on all interactive elements
- [ ] Dynamic Type supported throughout
- [x] iPad keyboard shortcuts for new note, search, toggle
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

---

## Future Improvements

### List Auto-continuation
- 編集モードで Return キーを押したとき、前の行のリスト記号を自動継続する。
- 対応パターン:
  - `- テキスト` → 次の行に `- ` を挿入
  - `* テキスト` → 次の行に `* ` を挿入
  - `1. テキスト` → 次の行に `2. ` を挿入
  - `- [ ] テキスト` → 次の行に `- [ ] ` を挿入
  - 空のリスト行で Return を押したらリスト終了（記号を挿入しない）
- 実装方針: `TextEditor` を `UITextView` ベースの `UIViewRepresentable` に置き換える必要がある。
- 優先度: 低（なくても使えるアプリとして成立している）

### Syntax Highlighting in Edit Mode
- 編集モードで Markdown 記法に応じた色分け表示。
- 実装方針: `UITextView` + `NSAttributedString` のカスタム実装またはサードパーティライブラリ。
- 優先度: 低

### Code Block Syntax Highlighting in Preview Mode
- プレビューモードのコードブロックにシンタックスハイライトを追加。
- 実装方針: highlight.js を CDN から追加読み込み。
- 優先度: 低

### External Change Conflict Resolution (v1.1)
- 編集モード中に外部変更を検知した場合、変更を保留する
- 編集モードを離脱したタイミングで競合ダイアログを表示
  - "Keep my edits"
  - "Use external changes"
- 実装方針:
  - `@State private var pendingExternalBody: String?`
  - `NSMetadataQuery` 検知時に `isEditing` が true なら保留
  - モード切替・画面離脱時に競合チェック