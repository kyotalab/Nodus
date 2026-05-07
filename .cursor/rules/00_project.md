# Nodus - Project Specification
> This file is always active. Read this before every task.

## App Identity
- **Name**: Nodus
- **Subtitle**: Plain text, connected thinking
- **Concept**: A Zettelkasten note-taking app for iOS inspired by The Archive (macOS)
- **Target Users**: Users of Zettlr, The Archive, or Obsidian who want something simpler

## Philosophy
Notes follow a cycle: Write → Link → Think → Output → Write again.
This loop is the core experience. Every design decision should support it.

## Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Minimum Deployment Target**: iOS 17+
- **Persistence**: Plain text files via iCloud Drive (ubiquity container)
- **External Dependencies**: None at compile time (avoid SPM/Pods unless necessary). Preview mode loads **marked.js** from cdnjs at runtime inside `WKWebView`.

## File Specification
| Item | Detail |
|------|--------|
| Format | Markdown plain text |
| Extension | `.md` (primary) / `.txt` (read support only — for The Archive compatibility) |
| New Note Extension | Always `.md` |
| Naming | `YYYYMMDDHHmm タイトル.md` |
| Note ID | 12-digit timestamp (e.g. `202604271321`) |
| Storage | iCloud Drive (user-visible folder) |

### Naming Examples
```
202604271321.md                          ← ID only (just created)
202604271321 Structured contexts.md      ← ID + title (renamed later)
```

## Wiki Link Specification
| Item | Detail |
|------|--------|
| Syntax | `[[ID]]` e.g. `[[202604271321]]` |
| Resolution | Partial match against filename |
| Edit Mode | Plain text only — no tap interaction |
| Preview Mode (resolved) | System blue, tappable → navigate to note |
| Preview Mode (broken) | System gray, not tappable |
| Back Navigation | NavigationStack — `< Back` supports multiple jump levels |

### Link Resolution Logic
```swift
// Pseudocode
func resolveLink(_ id: String, in notes: [Note]) -> Note? {
    notes.first { $0.filename.contains(id) }
}
```

## Search Specification
| Item | Detail |
|------|--------|
| Scope | Filename + full body text |
| Method | Space-separated AND search |
| Case Sensitivity | Case insensitive |
| Real-time | Results update as user types |
| Result Order | Current sort order applied as-is |
| Clear Behavior | ✕ clears query, dismisses focus, returns to full list |
| Sort During Search | Sort button remains active |
| Tag Search | No special handling — `#draft` matches as plain text |
| Example | `swift note` → files containing both "swift" AND "note" |

## UI Structure
- **Layout**: `NavigationSplitView` (auto-adapts: sidebar on iPad, push navigation on iPhone)
- **Note List**: Filename without extension (e.g. `202403220915 SwiftUI basics`) — same display as The Archive
- **Sort Options**: Updated date / Created date / Title (A-Z) / Most linked / Random

## Visual Design
- **Color Theme**: System-adaptive (automatic Dark / Light mode)
- **Editor Font**: Monospaced (SF Mono or system monospaced)
- **Editor Font Size**: iOS Dynamic Type (follows user system setting)
- **Preview Style**: Minimal — headings slightly larger/bolder, otherwise plain
- **Wiki Link Color**: System blue (resolved) / System gray (broken)

## Empty States
| State | Display |
|-------|---------|
| No notes (first launch) | "Your knowledge network starts here" + "Tap + to create your first note" |
| Search no results | `Nothing found for "[query]"` + tappable "+ Create new note" row |
| iPad no selection | Wordmark "Nodus" + tagline (typography only, no bitmap logo) |

## Delete Confirmation
| Element | Text |
|---------|------|
| Title | `Delete '[Note Title]'?` |
| Message | `This cannot be undone.` |
| Buttons | `Cancel` / `Delete` (destructive) |

## Settings Screen
```
Settings
├── Storage
│   └── Zettelkasten Folder     ← change selected folder
├── Editor
│   └── Default Mode            ← Edit / Preview (default: Edit)
└── About
    ├── Version
    └── Support
```

## Markdown Rendering (Preview Mode)
**Implementation**: `WKWebView` + **marked.js** (GFM) loaded from [cdnjs.cloudflare.com](https://cdnjs.cloudflare.com) — not `AttributedString(markdown:)`.

| Element | Rendered |
|---------|---------|
| Headings, Bold, Italic, Blockquote | ✅ |
| Inline code, Code block | ✅ |
| Lists (ordered/unordered), Horizontal rule | ✅ |
| Strikethrough, Table, GFM line breaks | ✅ (via marked GFM) |
| Footnotes (`[^ref]`) | ❌ (not enabled) |
| `[[wiki links]]` | ✅ System blue (`#007AFF`) / gray (`#8E8E93`) — resolved as `nodus://` links in HTML |
| Images (`![alt](url)`) | ❌ Alt text only |

## Note Creation UX (Hybrid)
1. **`+` button**: Creates a new note immediately with timestamp-only filename, navigates to editor
2. **Search → Create**: When search returns no results, show "Create new note" row at top of list

## Editor Specification
| Item | Detail |
|------|--------|
| Modes | Edit mode / Preview mode (toggle button) |
| Default Mode | Configurable in Settings (Edit or Preview, default: Edit) |
| Immersion | Simple (navigation bar always visible) |
| Keyboard Toolbar | `#`  `**`  `*`  `>`  `[[`  `Tab` |
| Title Editing | Tap title area to begin editing — commits on Return or focus lost |
| Title Placement | Inline TextField at top of NoteDetailView (shown in both Edit and Preview) |
| New Note Focus | If title is empty on open, auto-focus title field |
| Preview Metadata | Show `Created` / `Updated` under body in preview mode only |

### Keyboard Toolbar Behavior
| Button | Inserts | Cursor Position |
|--------|---------|-----------------|
| `#` | `# ` | After space |
| `**` | `****` | Between asterisks |
| `*` | `**` | Between asterisks |
| `>` | `> ` | After space |
| `[[` | `[[]]` | Between brackets |
| `Tab` | `\t` | After tab |

### iPad hardware keyboard (external keyboard)
| Shortcut | Action |
|----------|--------|
| ⌘N | New note (same as +) |
| ⌘E | Toggle Edit / Preview (in note detail) |

> Focus search (⌘F) is deferred — may be reintroduced later without affecting `List(selection:)`.

## Sync
- iCloud Drive ubiquity container
- On first launch, user selects their Zettelkasten folder via system folder picker
- Selected folder persisted via security-scoped bookmark
- Files.app access is a natural benefit of this approach
- Compatible with any Markdown editor (The Archive, Zettlr, iA Writer, etc.)

### External Change Behavior
| State | Behavior |
|-------|---------|
| Preview mode | Auto-update to latest content immediately |
| Edit mode (keyboard visible) | Hold external changes — apply when user leaves edit mode |

## iCloud Container ID (placeholder)
```
iCloud.com.YOURNAME.Nodus
```
> Replace YOURNAME with your Apple Developer Team ID before first build.

## Testing Policy
Full TDD is not adopted. Use **pinpoint testing** only.

### What to test
| Target | Reason |
|--------|--------|
| `SearchEngine` | AND search logic has edge cases that break silently |
| `LinkResolver` | Partial match logic must be reliable across all notes |
| `NoteFilenameParser` | Timestamp/title extraction affects every feature |

### What NOT to test
| Target | Reason |
|--------|--------|
| SwiftUI Views | Poor cost/benefit ratio |
| iCloud file I/O | Environment-dependent, hard to mock reliably |
| ViewModels | Cover indirectly via Core Logic tests |

### When to write tests
- Write tests for the 3 Core Logic targets above during PHASE 4
- Add more tests only if a bug recurs (regression test)
- Do not write tests before PHASE 4

### Test style
- Use XCTest (built into Xcode, no external libraries)
- Test pure functions only: given input → expected output
- One test per behavior (not one test per function)

```swift
// Good: one behavior per test
func testANDSearchRequiresAllTerms() { ... }
func testANDSearchIsCaseInsensitive() { ... }
func testEmptyQueryReturnsAllNotes() { ... }

// Bad: multiple behaviors in one test
func testSearch() { ... }
```

## Development Workflow
| Task | Tool |
|------|------|
| Write and edit code | Cursor |
| AI-assisted implementation | Cursor |
| Build and check errors | Xcode (⌘B) |
| Run on simulator | Xcode (⌘R) |
| Test on real device | Xcode |
| App Store submission | Xcode |

### Key Rule
**Edit code in Cursor only.** Xcode is for build, run, and debug.
Never edit the same file in both tools simultaneously.

## Folder Structure
```
Nodus/
├── App/
│   └── NodusApp.swift
├── Models/
│   └── Note.swift
├── Views/
│   ├── ContentView.swift
│   ├── NoteListView.swift
│   ├── NoteDetailView.swift
│   ├── MarkdownWebView.swift
│   └── EmptySelectionView.swift
├── ViewModels/
│   └── NoteStore.swift
├── Core/                          ← Pure logic (tested)
│   ├── SearchEngine.swift
│   ├── LinkResolver.swift
│   └── NoteFilenameParser.swift
└── Utilities/
    └── DateFormatter+Note.swift
```

## UI Language
- All UI text must be in English (button labels, navigation titles, alerts, empty states)
- Note content written by the user may be in any language

## Accessibility (VoiceOver)
- Primary controls use `.accessibilityLabel` in English (toolbar, list rows, keyboard insert buttons, share, empty selection).
- Note list row label: title if present, otherwise timestamp ID, plus formatted `updated` time (`DateFormatter.noteDisplayTimestamp`).
- iPad empty detail: `EmptySelectionView` combines title + tagline for a single spoken label.

## Coding Conventions
- Follow SwiftUI best practices
- Use only iOS 17+ APIs
- Prefer simple, readable code over clever code
- Keep views small and composable
- No force unwrapping (`!`) without explicit comment explaining why it's safe
- Core/ files must be pure functions with no SwiftUI or UIKit imports

### NavigationSplitView の構造ルール
- サイドバー列（`NoteListView` splitSidebar）: `NavigationStack` を入れない
- 詳細列（`ContentView` detailPane）: `NoteDetailView(embedInNavigationStack: true)` を渡す
- iPhone compact 列（`NoteListView` compactStack）: `NavigationStack` を 1 つだけ持ち、`NoteDetailView` はデフォルト（`embedInNavigationStack: false`）で呼ぶ
- wiki リンクの遷移は `NoteDetailView` 内の `NavigationLink` が担う
- `NoteDetailView(note:).id(id)` でノート切替時に `@State` をリセットする