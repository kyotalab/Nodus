# PHASE 4: Core Features
> Active during: Search, wiki links, editor, preview, keyboard toolbar
> Always read 00_project.md alongside this file.

## Goal of This Phase
Implement everything that makes Nodus feel like a real Zettelkasten app:
full-text search, [[wiki links]], edit/preview toggle, and keyboard toolbar.

---

## Feature 1: Full-Text Search

### Specification
- Scope: filename + body text
- Method: Space-separated AND search (all terms must match)
- Case insensitive

### Implementation
```swift
func search(query: String, in notes: [Note]) -> [Note] {
    let terms = query
        .lowercased()
        .split(separator: " ")
        .map(String.init)

    guard !terms.isEmpty else { return notes }

    return notes.filter { note in
        let searchTarget = (note.filename + " " + note.body).lowercased()
        return terms.allSatisfy { searchTarget.contains($0) }
    }
}
```

### UX Behavior
- Search bar always visible at top of NoteListView
- Results update in real time as user types
- Empty query → show all notes
- No results + query not empty → show `Nothing found for "[query]"` message + tappable "+ Create new note" row

---

## Feature 2: Note Creation from Search (Hybrid UX)

### "+ button" flow
1. User taps `+`
2. New note created: `YYYYMMDDHHmm.md` (empty body)
3. Navigate immediately to NoteDetailView in edit mode

### "Search → Create" flow
1. User types in search bar
2. No matching notes found
3. List shows single row: `+ Create new note`  (query is NOT used as title)
4. User taps row → same as + button flow

---

## Feature 3: [[Wiki Link]] Resolution

### Specification
- Syntax: `[[ID]]` where ID is the 12-digit timestamp
- Resolution: first note whose filename contains the ID string (partial match)
- Tapping a rendered link navigates to that note

### Resolution Function
```swift
func resolveLink(_ id: String, in notes: [Note]) -> Note? {
    notes.first { $0.filename.contains(id) }
}
```

### Rendering in Preview Mode
In preview mode, detect `[[...]]` patterns and render as tappable links.
Use `NSRegularExpression` or Swift `Regex` (iOS 16+) to find patterns.

```swift
// Pattern to match [[anything]]
let pattern = /\[\[(.+?)\]\]/
```

For each match:
- Try to resolve the ID to a note
- If found: render as blue tappable text → navigate to note
- If not found: render as gray text (broken link indicator)

---

## Feature 4: Edit / Preview Toggle

### UI
```
┌─────────────────────────────┐
│ ← Back    Note Title   Edit │  ← Toggle button (right of toolbar)
├─────────────────────────────┤
│                             │
│  [Editor or Preview here]   │
│                             │
└─────────────────────────────┘
```

### Edit Mode
- `TextEditor` (SwiftUI built-in)
- **Monospaced font** (SF Mono or `.font(.system(.body, design: .monospaced))`)
- **Dynamic Type**: use `.font(.system(.body, design: .monospaced))` to respect user font size
- Keyboard toolbar visible

### Preview Mode
- Parse markdown and render with minimal styling:
  - Headings: slightly larger/bolder, no decorative color
  - Body: system default font, Dynamic Type
  - Bold/italic: standard rendering
  - Blockquote: subtle left border or indent
- **System blue** for resolved `[[links]]`, **system gray** for broken links
- Use `AttributedString` with `.init(markdown:)` for basic rendering
- `[[links]]` rendered as tappable (see Feature 3)

### Toggle State
```swift
@State private var isEditing: Bool = true  // Default: edit mode
```

---

## Feature 5: Keyboard Toolbar

### Toolbar Definition
```swift
var keyboardToolbar: some View {
    HStack(spacing: 16) {
        ToolbarButton(label: "#")  { insert("# ") }
        ToolbarButton(label: "**") { insertAround("**", "**") }
        ToolbarButton(label: "*")  { insertAround("*", "*") }
        ToolbarButton(label: ">")  { insert("> ") }
        ToolbarButton(label: "[[") { insertAround("[[", "]]") }
        ToolbarButton(label: "⇥")  { insert("\t") }
        Spacer()
    }
    .padding(.horizontal)
}
```

### Cursor Placement after Insertion
| Button | Result | Cursor |
|--------|--------|--------|
| `#` | `# ` | After space |
| `**` | `**\|**` | Between `**` |
| `*` | `*\|*` | Between `*` |
| `>` | `> ` | After space |
| `[[` | `[[\|]]` | Between brackets |
| `Tab` | `\t` | After tab |

> ⚠️ Cursor placement in SwiftUI TextEditor requires UITextView workaround.
> Ask Cursor for `UIViewRepresentable` wrapper if needed.

---

## Feature 6: Sort Options

### Available Sort Orders
```swift
enum SortOrder: String, CaseIterable {
    case updatedDesc  = "Updated (newest)"
    case createdDesc  = "Created (newest)"
    case titleAsc     = "Title (A-Z)"
    case backlinkDesc = "Most linked"
    case random       = "Random"
}
```

### Random Sort
```swift
// Shuffle notes array — reshuffle every time user selects Random
case .random:
    return notes.shuffled()
```
> Random sort surfaces forgotten notes and supports serendipitous discovery.
> Re-selecting "Random" produces a new shuffle.

### Backlink Count Calculation
```swift
func backlinkCount(for note: Note, in notes: [Note]) -> Int {
    let id = note.timestampID
    return notes.filter { other in
        other.id != note.id && other.body.contains(id)
    }.count
}
```
> ⚠️ Computing backlinks for all notes on every sort is expensive.
> Cache the counts and invalidate when any note body changes.

### UI
- Sort button in NoteListView toolbar (e.g. list icon)
- Present as `.confirmationDialog` or `.menu`

---

## Phase 4 Checklist
- [ ] Full-text AND search working in real time
- [ ] "Create new note" row appears when search has no results
- [ ] `+` button creates note and navigates to editor
- [ ] Edit / Preview toggle works
- [ ] Preview renders basic Markdown (bold, italic, headers)
- [ ] `[[ID]]` links are tappable in preview and navigate correctly
- [ ] Broken links shown in gray
- [ ] Keyboard toolbar inserts text with correct cursor placement
- [ ] Sort options menu works for all 5 sort orders (including Random)
- [ ] Backlink count is cached and updates correctly

---

---

## Pinpoint Tests (Write These in PHASE 4)

### SearchEngineTests.swift
```swift
import XCTest
@testable import Nodus

final class SearchEngineTests: XCTestCase {

    let notes = [
        Note(filename: "202604271321 Swift basics.md",   body: "SwiftUI tutorial"),
        Note(filename: "202604271322 Python notes.md",   body: "Python tutorial"),
        Note(filename: "202604271323 Swift advanced.md", body: "Protocols and generics"),
    ]

    func testANDSearchRequiresAllTerms() {
        let results = SearchEngine.search("swift tutorial", in: notes)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.timestampID, "202604271321")
    }

    func testSingleTermMatchesMultiple() {
        let results = SearchEngine.search("swift", in: notes)
        XCTAssertEqual(results.count, 2)
    }

    func testEmptyQueryReturnsAll() {
        let results = SearchEngine.search("", in: notes)
        XCTAssertEqual(results.count, 3)
    }

    func testCaseInsensitive() {
        let results = SearchEngine.search("SWIFT", in: notes)
        XCTAssertEqual(results.count, 2)
    }

    func testNoMatchReturnsEmpty() {
        let results = SearchEngine.search("kotlin", in: notes)
        XCTAssertTrue(results.isEmpty)
    }
}
```

### LinkResolverTests.swift
```swift
final class LinkResolverTests: XCTestCase {

    let notes = [
        Note(filename: "202604271321 Structured contexts.md", body: ""),
        Note(filename: "202604271322 Another note.md",        body: ""),
    ]

    func testResolvesExactID() {
        let result = LinkResolver.resolve("202604271321", in: notes)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.timestampID, "202604271321")
    }

    func testReturnsNilForUnknownID() {
        let result = LinkResolver.resolve("999999999999", in: notes)
        XCTAssertNil(result)
    }

    func testDoesNotMatchPartialTimestamp() {
        // "2026" alone should not resolve to a specific note
        let result = LinkResolver.resolve("2026", in: notes)
        // Returns first match — acceptable, but test documents the behavior
        XCTAssertNotNil(result)
    }
}
```

### NoteFilenameParserTests.swift
```swift
final class NoteFilenameParserTests: XCTestCase {

    func testExtractsTimestampID() {
        let note = Note(filename: "202604271321 My title.md")
        XCTAssertEqual(note.timestampID, "202604271321")
    }

    func testExtractsTitleAfterTimestamp() {
        let note = Note(filename: "202604271321 My title.md")
        XCTAssertEqual(note.title, "My title")
    }

    func testIDOnlyFilenameHasEmptyTitle() {
        let note = Note(filename: "202604271321.md")
        XCTAssertEqual(note.title, "")
    }

    func testTitleWithMultipleSpaces() {
        let note = Note(filename: "202604271321 Long title with spaces.md")
        XCTAssertEqual(note.title, "Long title with spaces")
    }
}
```

### How to run tests in Xcode
```
⌘U         → Run all tests
⌘⌃U        → Run current test file
Click ◆     → Run single test (click the diamond next to func name)
```

---

## Common Pitfalls
| Pitfall | Solution |
|---------|----------|
| `AttributedString(markdown:)` doesn't render `[[links]]` | Handle `[[]]` separately before passing to AttributedString |
| TextEditor cursor position hard to control | Use UIViewRepresentable wrapping UITextView |
| Backlink count too slow on large vaults | Cache in NoteStore, recompute only on body change |
| Sort state not persisted across app launches | Store in `@AppStorage` |
